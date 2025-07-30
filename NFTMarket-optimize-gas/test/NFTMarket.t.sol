// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdError.sol";
import "../src/NFTMarket.sol";
import "../src/MyERC20.sol";
import "../src/MyERC721.sol";

contract NFTMarketTest is Test {
    MyERC20 public myERC20;
    MyERC721 public myERC721;
    NFTMarket public nftMarket;

    address public deployer;
    address public alice;
    address public bob;
    address public charlie;

    // 优化1：由于 MyERC20 构造函数中移除了初始铸造，这些常量现在更清晰地表示我们“打算”给 Alice 和 Bob 分发的金额。
    // INITIAL_ERC20_SUPPLY 变量在优化后的 MyERC20 合约中不再直接使用，但作为文档保留。
    uint256 public constant INITIAL_ERC20_SUPPLY = 100000000 * 10 ** 18; // 1亿 MYC 代币的初始供应量
    uint256 public constant ALICE_INITIAL_BALANCE = 1000 * 10 ** 18; // Alice 的初始 MYC 代币余额（1000 MYC）
    uint256 public constant BOB_INITIAL_BALANCE = 500 * 10 ** 18; // Bob 的初始 MYC 代币余额（500 MYC）

    event NFTListed(
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 price
    );

    event NFTSold(
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address indexed buyer,
        uint256 price
    );
    event NFTUnlisted(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller
    );

    function setUp() public {
        deployer = makeAddr("deployer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        vm.startPrank(deployer);
        myERC20 = new MyERC20();
        myERC721 = new MyERC721();
        nftMarket = new NFTMarket(address(myERC20));

        // 优化2：由于 MyERC20 构造函数不再铸造初始供应量给 deployer，
        // 在测试中需要显式地铸造代币给 Alice 和 Bob。
        // 这与优化后的 MyERC20 合约的 mint 函数设计相符。
        myERC20.mint(alice, ALICE_INITIAL_BALANCE);
        myERC20.mint(bob, BOB_INITIAL_BALANCE);
        vm.stopPrank();
    }

    function testList_Success() public {
        uint256 tokenId;
        vm.startPrank(deployer);
        // 优化3：myERC721.mint 现在直接递增 _nextTokenId，
        // 并且返回的是递增后的 tokenId，确保连续性。
        tokenId = myERC721.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 price = 100 * 10 ** myERC20.decimals();

        myERC721.approve(address(nftMarket), tokenId);

        vm.expectEmit(true, true, true, true);
        emit NFTListed(address(myERC721), tokenId, alice, price);

        nftMarket.list(address(myERC721), tokenId, price);

        // 优化4：根据 NFTMarket 中 Listing 结构体的字段顺序调整。
        // 现在是 price 在前，seller 在后。
        (uint256 listingPrice, address seller) = nftMarket.listings(address(myERC721), tokenId);
        assertEq(seller, alice, "Seller should be Alice");
        assertEq(listingPrice, price, "Price should be 100 MYC");
        vm.stopPrank();
    }

    function testList_Fail_NotOwner() public {
        uint256 tokenId;
        vm.startPrank(deployer);
        tokenId = myERC721.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 price = 100 * 10 ** myERC20.decimals();
        vm.expectRevert("NFTMarket: You are not the owner of this NFT.");
        nftMarket.list(address(myERC721), tokenId, price);
        vm.stopPrank();
    }

    function testList_Fail_PriceZero() public {
        uint256 tokenId;
        vm.startPrank(deployer);
        tokenId = myERC721.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(alice);
        myERC721.approve(address(nftMarket), tokenId);
        vm.expectRevert("NFTMarket: Price must be greater than zero.");
        nftMarket.list(address(myERC721), tokenId, 0);
        vm.stopPrank();
    }

    function testList_Fail_NotApproved() public {
        uint256 tokenId;
        vm.startPrank(deployer);
        tokenId = myERC721.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 price = 100 * 10 ** myERC20.decimals();
        vm.expectRevert("NFTMarket: The market must be approved to transfer the NFT.");
        nftMarket.list(address(myERC721), tokenId, price);
        vm.stopPrank();
    }

    function testUnlist_Success() public {
        uint256 tokenId;
        vm.startPrank(deployer);
        tokenId = myERC721.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 price = 100 * 10 ** myERC20.decimals();
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, price);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectEmit(true, true, true, false);
        emit NFTUnlisted(address(myERC721), tokenId, alice);
        nftMarket.unlist(address(myERC721), tokenId);
        vm.stopPrank();

        // 优化4：根据 NFTMarket 中 Listing 结构体的字段顺序调整。
        (uint256 listingPrice, address seller) = nftMarket.listings(address(myERC721), tokenId);
        assertEq(seller, address(0), "Listing should be deleted");
        assertEq(listingPrice, 0, "Price should be 0");
    }

    function testUnlist_Fail_NotSeller() public {
        uint256 tokenId;
        vm.startPrank(deployer);
        tokenId = myERC721.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 price = 100 * 10 ** myERC20.decimals();
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, price);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("NFTMarket: You are not the seller of this NFT.");
        nftMarket.unlist(address(myERC721), tokenId);
        vm.stopPrank();
    }

    function testBuyNFT_Success() public {
        uint256 tokenId;
        vm.startPrank(deployer);
        tokenId = myERC721.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 price = 50 * 10 ** myERC20.decimals();
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, price);
        vm.stopPrank();

        vm.startPrank(bob);
        myERC20.approve(address(nftMarket), price);

        uint256 aliceBalanceBefore = myERC20.balanceOf(alice);
        uint256 bobBalanceBefore = myERC20.balanceOf(bob);
        address nftOwnerBefore = myERC721.ownerOf(tokenId);

        vm.expectEmit(true, true, true, true);
        emit NFTSold(address(myERC721), tokenId, alice, bob, price);
        nftMarket.buyNFT(address(myERC721), tokenId);

        assertEq(myERC20.balanceOf(alice), aliceBalanceBefore + price, "Alice's balance should increase");
        assertEq(myERC20.balanceOf(bob), bobBalanceBefore - price, "Bob's balance should decrease");

        assertEq(myERC721.ownerOf(tokenId), bob, "Bob should now own the NFT");

        // 优化4：根据 NFTMarket 中 Listing 结构体的字段顺序调整。
        (uint256 listingPrice, address seller) = nftMarket.listings(address(myERC721), tokenId);
        assertEq(seller, address(0), "Listing should be deleted after sale");
        assertEq(listingPrice, 0, "Price should be 0 after sale");

        vm.stopPrank();
    }

    function testBuyNFT_Fail_NotListed() public {
        uint256 tokenId;
        vm.startPrank(deployer);
        tokenId = myERC721.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("NFTMarket: This NFT is not listed for sale.");
        nftMarket.buyNFT(address(myERC721), tokenId);
        vm.stopPrank();
    }

    function testBuyNFT_Fail_SellerNoLongerOwnsNFT() public {
        uint256 tokenId;
        vm.startPrank(deployer);
        tokenId = myERC721.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 price = 50 * 10 ** myERC20.decimals();
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, price);
        vm.stopPrank();

        vm.startPrank(alice);
        myERC721.transferFrom(alice, charlie, tokenId);
        vm.stopPrank();

        vm.startPrank(bob);
        myERC20.approve(address(nftMarket), price);
        vm.expectRevert("NFTMarket: Seller no longer owns this NFT.");
        nftMarket.buyNFT(address(myERC721), tokenId);
        vm.stopPrank();
    }

    function testBuyNFT_Fail_SelfPurchase() public {
        uint256 tokenId;
        vm.startPrank(deployer);
        tokenId = myERC721.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 price = 50 * 10 ** myERC20.decimals();
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, price);

        myERC20.approve(address(nftMarket), price);
        vm.expectRevert("NFTMarket: You cannot buy your own NFT.");
        nftMarket.buyNFT(address(myERC721), tokenId);
        vm.stopPrank();
    }

    // 测试代币授权不足
    function testBuyNFT_Fail_InsufficientTokenAllowance() public {
        uint256 price = 100 * 10 ** myERC20.decimals();

        vm.startPrank(deployer);
        uint256 tokenId = myERC721.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(alice);
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, price);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 insufficientAllowance = 50 * 10 ** myERC20.decimals();
        myERC20.approve(address(nftMarket), insufficientAllowance);

        // 修复：手动构造 ERC20InsufficientAllowance 错误的选择器和参数。
        // 这与 OpenZeppelin 的 ERC20 合约中的自定义错误签名完全匹配。
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("ERC20InsufficientAllowance(address,uint256,uint256)")),
                address(nftMarket),
                insufficientAllowance,
                price
            )
        );
        nftMarket.buyNFT(address(myERC721), tokenId);
        vm.stopPrank();
    }

    function testBuyNFT_Fail_InsufficientTokenBalance() public {
        uint256 tokenId;
        vm.startPrank(deployer);
        tokenId = myERC721.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(alice);
        // 价格高于 Bob 的初始余额
        uint256 price = BOB_INITIAL_BALANCE + 1;
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, price);
        vm.stopPrank();

        vm.startPrank(bob);
        // Bob 授权了全额价格，但余额不足
        myERC20.approve(address(nftMarket), price);
        vm.expectRevert("NFTMarket: Insufficient token balance to buy this NFT.");
        nftMarket.buyNFT(address(myERC721), tokenId);
        vm.stopPrank();
    }

    function testBuyNFT_Fail_AlreadyBought() public {
        uint256 tokenId;

        vm.startPrank(deployer);
        tokenId = myERC721.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 price = 50 * 10 ** myERC20.decimals();
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, price);
        vm.stopPrank();

        vm.startPrank(bob);
        myERC20.approve(address(nftMarket), price);
        nftMarket.buyNFT(address(myERC721), tokenId);
        vm.stopPrank();

        vm.startPrank(charlie);
        myERC20.approve(address(nftMarket), price);
        vm.expectRevert("NFTMarket: This NFT is not listed for sale.");
        nftMarket.buyNFT(address(myERC721), tokenId);
        vm.stopPrank();
    }

    function testFuzz_ListAndBuyNFT(uint256 priceFuzz, address sellerFuzz, address buyerFuzz) public {
        // --- 输入假设 ---
        // 优化6: 调整价格假设范围以匹配更实际的代币小数位和避免极端值
        vm.assume(priceFuzz > 0 && priceFuzz <= 1000 * 10 ** myERC20.decimals()); // 确保价格大于0且在一个合理范围内
        vm.assume(sellerFuzz != address(0) && sellerFuzz != address(this) && sellerFuzz != deployer); // 确保卖家不是零地址、市场或部署者
        vm.assume(buyerFuzz != address(0) && buyerFuzz != address(this) && buyerFuzz != deployer); // 确保买家不是零地址、市场或部署者
        vm.assume(sellerFuzz != buyerFuzz); // 确保卖家和买家不是同一个人

        // --- 准备工作 ---
        // 铸造 ERC20 代币给卖家和买家。确保有足够的代币进行交易。
        // 这里使用 `vm.deal` 仅适用于 ETH，对于 ERC20 需要 `myERC20.mint`。
        // 优化7: 确保铸造足够的 ERC20 代币来覆盖潜在的交易，通常是价格的两倍。
        vm.startPrank(deployer);
        myERC20.mint(sellerFuzz, priceFuzz * 2);
        myERC20.mint(buyerFuzz, priceFuzz * 2);
        uint256 tokenId = myERC721.mint(sellerFuzz, "uri_fuzz_nft");
        vm.stopPrank();

        // --- 卖家上架 NFT ---
        vm.startPrank(sellerFuzz);
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, priceFuzz);
        vm.stopPrank();

        // --- 买家尝试购买 NFT ---
        vm.startPrank(buyerFuzz);
        myERC20.approve(address(nftMarket), priceFuzz);

        uint256 sellerBalanceBefore = myERC20.balanceOf(sellerFuzz);
        uint256 buyerBalanceBefore = myERC20.balanceOf(buyerFuzz);
        address nftOwnerBefore = myERC721.ownerOf(tokenId);

        try nftMarket.buyNFT(address(myERC721), tokenId) {
            // --- Successful purchase assertions ---
            assertEq(myERC20.balanceOf(sellerFuzz), sellerBalanceBefore + priceFuzz, "Fuzz test: Seller balance incorrect");
            assertEq(myERC20.balanceOf(buyerFuzz), buyerBalanceBefore - priceFuzz, "Fuzz test: Buyer balance incorrect");
            assertEq(myERC721.ownerOf(tokenId), buyerFuzz, "Fuzz test: NFT ownership should be transferred to buyer");

            // 优化4：根据 NFTMarket 中 Listing 结构体的字段顺序调整。
            (uint256 listingPriceFromListing, address sellerFromListing) = nftMarket.listings(address(myERC721), tokenId);
            assertEq(sellerFromListing, address(0), "Fuzz test: Listing should be deleted after sale");
            assertEq(listingPriceFromListing, 0, "Fuzz test: Price should be 0 after sale");
        } catch Error(string memory reason) {
            // --- Revert path assertions ---
            assertEq(myERC20.balanceOf(sellerFuzz), sellerBalanceBefore, "Fuzz test: Seller balance should not change on revert");
            assertEq(myERC20.balanceOf(buyerFuzz), buyerBalanceBefore, "Fuzz test: Buyer balance should not change on revert");
            assertEq(myERC721.ownerOf(tokenId), nftOwnerBefore, "Fuzz test: NFT ownership should not change on revert");
            // 优化8: 可以根据具体的revert reason进行更精细的断言，例如：
            // console.log("Revert reason:", reason);
            // assertTrue(
            //     keccak256(abi.encodePacked(reason)) == keccak256(abi.encodePacked("NFTMarket: This NFT is not listed for sale.")) ||
            //     keccak256(abi.encodePacked(reason)) == keccak256(abi.encodePacked("NFTMarket: Seller no longer owns this NFT.")) ||
            //     keccak256(abi.encodePacked(reason)) == keccak256(abi.encodePacked("NFTMarket: Insufficient token balance to buy this NFT.")) ||
            //     keccak256(abi.encodePacked(reason)) == keccak256(abi.encodePacked("NFTMarket: You cannot buy your own NFT.")),
            //     "Unexpected revert reason"
            // );
        } catch {
            // This catch block handles reverts that are not simple strings, e.g., custom errors or panics.
            assertEq(myERC20.balanceOf(sellerFuzz), sellerBalanceBefore, "Fuzz test: Seller balance should not change on revert (other)");
            assertEq(myERC20.balanceOf(buyerFuzz), buyerBalanceBefore, "Fuzz test: Buyer balance should not change on revert (other)");
            assertEq(myERC721.ownerOf(tokenId), nftOwnerBefore, "Fuzz test: NFT ownership should not change on revert (other)");
        }
        vm.stopPrank();
    }

    function invariant_NFTMarketHasNoERC20() public view {
        assertEq(myERC20.balanceOf(address(nftMarket)), 0, "NFTMarket should never hold ERC20 tokens");
    }

    function invariant_NFTMarketHasNoERC721() public {
        assertEq(myERC721.balanceOf(address(nftMarket)), 0, "NFTMarket should never own any ERC721 NFTs");
    }
}