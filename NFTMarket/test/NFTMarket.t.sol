// SPDX-License-Identifier: MIT
// SPDX许可证标识符：MIT

pragma solidity ^0.8.20; // 指定Solidity编译器版本为0.8.20或更高

import "forge-std/Test.sol"; // 导入Forge测试库，提供测试框架功能
import "forge-std/StdError.sol"; // 导入标准错误库，用于更精确的回滚断言
import "../src/NFTMarket.sol"; // 导入NFTMarket合约
import "../src/MyERC20.sol"; // 导入MyERC20代币合约
import "../src/MyERC721.sol"; // 导入MyERC721 NFT合约

// 定义NFTMarketTest合约，继承自Test，表示这是一个测试合约
contract NFTMarketTest is Test {
    MyERC20 public myERC20; // 声明MyERC20合约实例
    MyERC721 public myERC721; // 声明MyERC721合约实例
    NFTMarket public nftMarket; // 声明NFTMarket合约实例

    address public deployer; // 部署者地址
    address public alice;    // Alice 地址
    address public bob;      // Bob 地址
    address public charlie;  // Charlie 地址

    uint256 public constant INITIAL_ERC20_SUPPLY = 100000000 * 10 ** 18; // 1亿 MYC 代币的初始供应量
    uint256 public constant ALICE_INITIAL_BALANCE = 1000 * 10 ** 18; // Alice 的初始 MYC 代币余额（1000 MYC）
    uint256 public constant BOB_INITIAL_BALANCE = 500 * 10 ** 18; // Bob 的初始 MYC 代币余额（500 MYC）


        // 事件定义
    event NFTListed( // NFT上架事件
        address indexed nftContract, // NFT合约地址
        uint256 indexed tokenId,     // NFT的ID
        address seller,              // 卖家地址
        uint256 price                // 上架价格
    );

    event NFTSold( // NFT售出事件
        address indexed nftContract, // NFT合约地址
        uint256 indexed tokenId,     // NFT的ID
        address seller,              // 卖家地址
        address indexed buyer,       // 买家地址
        uint256 price                // 销售价格
    );
     event NFTUnlisted( // NFT下架事件
        address indexed nftContract, // NFT合约地址
        uint256 indexed tokenId,     // NFT的ID
        address indexed seller       // 卖家地址
    );

    // setUp 函数在每个测试函数运行前执行，用于初始化合约和状态
    function setUp() public {
        deployer = makeAddr("deployer"); // 创建一个名为“deployer”的地址
        alice = makeAddr("alice");       // 创建一个名为“alice”的地址
        bob = makeAddr("bob");           // 创建一个名为“bob”的地址
        charlie = makeAddr("charlie");   // 创建一个名为“charlie”的地址

        vm.startPrank(deployer); // 开始模拟 deployer 账户的操作
        myERC20 = new MyERC20(); // 部署 MyERC20 合约
        myERC721 = new MyERC721(); // 部署 MyERC721 合约
        nftMarket = new NFTMarket(address(myERC20)); // 部署 NFTMarket 合约，并传入 MyERC20 地址作为参数

        // 为测试分发 ERC20 代币
        myERC20.mint(alice, ALICE_INITIAL_BALANCE); // 给 Alice 铸造初始代币余额
        myERC20.mint(bob, BOB_INITIAL_BALANCE);      // 给 Bob 铸造初始代币余额
        vm.stopPrank(); // 停止模拟 deployer 账户的操作
    }

    // 成功上架NFT的测试
    function testList_Success() public {
        uint256 tokenId;
        vm.startPrank(deployer); // 模拟部署者来铸造NFT
        tokenId = myERC721.mint(alice, "uri_alice_1"); // 部署者铸造NFT给Alice
        vm.stopPrank(); // 停止模拟部署者


        vm.startPrank(alice); // 模拟 Alice 的操作
        uint256 price = 100 * 10 ** myERC20.decimals(); // 定义上架价格

        // Alice 授权 NFTMarket 合约转移她的 NFT
        myERC721.approve(address(nftMarket), tokenId);

        // 预期会触发 NFTListed 事件，并且所有参数都匹配
        vm.expectEmit(true, true, true, true);
        emit NFTListed(address(myERC721), tokenId, alice, price);

        nftMarket.list(address(myERC721), tokenId, price); // Alice 上架 NFT

        // 验证上架详情 - **修复：从公共映射的getter中检索单个组件**
        (address seller, uint256 listingPrice) = nftMarket.listings(address(myERC721), tokenId);
        assertEq(seller, alice, "Seller should be Alice"); // 断言卖家是 Alice
        assertEq(listingPrice, price, "Price should be 100 MYC"); // 断言价格正确
        vm.stopPrank(); // 停止模拟 Alice 的操作
    }

    // 测试非所有者尝试上架NFT的情况
    function testList_Fail_NotOwner() public {
	    uint256 tokenId;
        vm.startPrank(deployer); // 模拟部署者来铸造NFT
        tokenId = myERC721.mint(alice, "uri_alice_1"); // 部署者铸造NFT给Alice
        vm.stopPrank(); // 停止模拟部署者

        vm.startPrank(bob); // 模拟 Bob 的操作 (Bob 不是 NFT 的所有者)
        uint256 price = 100 * 10 ** myERC20.decimals();
        vm.expectRevert("NFTMarket: You are not the owner of this NFT."); // 预期回滚并断言错误信息
        nftMarket.list(address(myERC721), tokenId, price); // Bob 尝试上架
        vm.stopPrank(); // 停止模拟 Bob 的操作
    }

    // 测试以零价格上架NFT的情况
    function testList_Fail_PriceZero() public {
        uint256 tokenId;
        vm.startPrank(deployer); // 模拟部署者来铸造NFT
        tokenId = myERC721.mint(alice, "uri_alice_1"); // 部署者铸造NFT给Alice
        vm.stopPrank(); // 停止模拟部署者

        vm.startPrank(alice); // 模拟 Alice 的操作
        myERC721.approve(address(nftMarket), tokenId); // Alice 授权市场
        vm.expectRevert("NFTMarket: Price must be greater than zero."); // 预期回滚并断言错误信息
        nftMarket.list(address(myERC721), tokenId, 0); // Alice 尝试以零价格上架
        vm.stopPrank(); // 停止模拟 Alice 的操作
    }

    // 测试在未首先授权市场的情况下上架NFT
    function testList_Fail_NotApproved() public {
        uint256 tokenId;
        vm.startPrank(deployer); // 模拟部署者来铸造NFT
        tokenId = myERC721.mint(alice, "uri_alice_1"); // 部署者铸造NFT给Alice
        vm.stopPrank(); // 停止模拟部署者


        vm.startPrank(alice); // 模拟 Alice 的操作
        uint256 price = 100 * 10 ** myERC20.decimals();
        // Alice 没有授权 NFTMarket 合约，因此缺少 myERC721.approve() 调用
        vm.expectRevert("NFTMarket: The market must be approved to transfer the NFT."); // 预期回滚并断言错误信息
        nftMarket.list(address(myERC721), tokenId, price); // Alice 尝试上架
        vm.stopPrank(); // 停止模拟 Alice 的操作
    }
    
    // 成功下架NFT的测试
    function testUnlist_Success() public {
        uint256 tokenId;
        vm.startPrank(deployer); // 模拟部署者来铸造NFT
        tokenId = myERC721.mint(alice, "uri_alice_1"); // 部署者铸造NFT给Alice
        vm.stopPrank(); // 停止模拟部署者

        vm.startPrank(alice); // 模拟 Alice 的操作
        uint256 price = 100 * 10 ** myERC20.decimals();
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, price);
        vm.stopPrank(); // 停止模拟 Alice 的操作

        vm.startPrank(alice); // 再次模拟 Alice 的操作
        vm.expectEmit(true, true, true, false); // 预期会触发 NFTUnlisted 事件
        emit NFTUnlisted(address(myERC721), tokenId, alice);
        nftMarket.unlist(address(myERC721), tokenId); // Alice 下架 NFT
        vm.stopPrank(); // 停止模拟 Alice 的操作

        // 验证上架详情已被删除 - **修复：从公共映射的getter中检索单个组件**
        (address seller, uint256 listingPrice) = nftMarket.listings(address(myERC721), tokenId);
        assertEq(seller, address(0), "Listing should be deleted"); // 断言卖家地址为零地址
        assertEq(listingPrice, 0, "Price should be 0"); // 断言价格为0
    }

    // 测试非卖家尝试下架NFT的情况
    function testUnlist_Fail_NotSeller() public {
        uint256 tokenId;
        vm.startPrank(deployer); // 模拟部署者来铸造NFT
        tokenId = myERC721.mint(alice, "uri_alice_1"); // 部署者铸造NFT给Alice
        vm.stopPrank(); // 停止模拟部署者


        vm.startPrank(alice); // 模拟 Alice 的操作
        uint256 price = 100 * 10 ** myERC20.decimals();
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, price);
        vm.stopPrank(); // 停止模拟 Alice 的操作

        vm.startPrank(bob); // 模拟 Bob 的操作 (Bob 不是卖家)
        vm.expectRevert("NFTMarket: You are not the seller of this NFT."); // 预期回滚并断言错误信息
        nftMarket.unlist(address(myERC721), tokenId); // Bob 尝试下架 Alice 的 NFT
        vm.stopPrank(); // 停止模拟 Bob 的操作
    }

    
    // 成功购买NFT的测试
    function testBuyNFT_Success() public {

        uint256 tokenId;
        vm.startPrank(deployer); // 模拟部署者来铸造NFT
        tokenId = myERC721.mint(alice, "uri_alice_1"); // 部署者铸造NFT给Alice
        vm.stopPrank(); // 停止模拟部署者


        vm.startPrank(alice); // 模拟 Alice 的操作
        uint256 price = 50 * 10 ** myERC20.decimals(); // 定义价格
        myERC721.approve(address(nftMarket), tokenId); // Alice 授权市场
        nftMarket.list(address(myERC721), tokenId, price); // Alice 上架 NFT
        vm.stopPrank(); // 停止模拟 Alice 的操作

        // Bob 购买 NFT
        vm.startPrank(bob); // 模拟 Bob 的操作
        myERC20.approve(address(nftMarket), price); // Bob 授权市场花费他的代币

        uint256 aliceBalanceBefore = myERC20.balanceOf(alice); // 记录购买前 Alice 的余额
        uint256 bobBalanceBefore = myERC20.balanceOf(bob);     // 记录购买前 Bob 的余额
        address nftOwnerBefore = myERC721.ownerOf(tokenId);    // 记录购买前 NFT 的所有者

        vm.expectEmit(true, true, true, true); // 预期会触发 NFTSold 事件
        emit NFTSold(address(myERC721), tokenId, alice, bob, price);
        nftMarket.buyNFT(address(myERC721), tokenId); // Bob 购买 NFT

        // 验证余额变化
        assertEq(myERC20.balanceOf(alice), aliceBalanceBefore + price, "Alice's balance should increase"); // Alice 的余额应该增加
        assertEq(myERC20.balanceOf(bob), bobBalanceBefore - price, "Bob's balance should decrease");     // Bob 的余额应该减少

        // 验证 NFT 所有权转移
        assertEq(myERC721.ownerOf(tokenId), bob, "Bob should now own the NFT"); // Bob 现在应该拥有 NFT

        // 验证上架信息已被删除 - **修复：从公共映射的getter中检索单个组件**
        (address seller, uint256 listingPrice) = nftMarket.listings(address(myERC721), tokenId);
        assertEq(seller, address(0), "Listing should be deleted after sale"); // 断言卖家地址为零地址
        assertEq(listingPrice, 0, "Price should be 0 after sale"); // 断言价格为0

        vm.stopPrank(); // 停止模拟 Bob 的操作
    }

    // 测试购买未上架的NFT
    function testBuyNFT_Fail_NotListed() public {
        uint256 tokenId;
        vm.startPrank(deployer); // 模拟部署者来铸造NFT
        tokenId = myERC721.mint(alice, "uri_alice_1"); // 部署者铸造NFT给Alice
        vm.stopPrank(); // 停止模拟部署者

        vm.startPrank(bob); // 模拟 Bob 的操作
        vm.expectRevert("NFTMarket: This NFT is not listed for sale."); // 预期回滚并断言错误信息
        nftMarket.buyNFT(address(myERC721), tokenId); // Bob 尝试购买未上架的 NFT
        vm.stopPrank(); // 停止模拟 Bob 的操作
    }

    // 测试当卖家不再拥有NFT时购买
    function testBuyNFT_Fail_SellerNoLongerOwnsNFT() public {
        uint256 tokenId;
        vm.startPrank(deployer); // 模拟部署者来铸造NFT
        tokenId = myERC721.mint(alice, "uri_alice_1"); // 部署者铸造NFT给Alice
        vm.stopPrank(); // 停止模拟部署者


        vm.startPrank(alice); // 模拟 Alice 的操作
        uint256 price = 50 * 10 ** myERC20.decimals();
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, price);
        vm.stopPrank(); // 停止模拟 Alice 的操作

        // Alice 在 NFT 被购买前将其转移走
        vm.startPrank(alice);
        myERC721.transferFrom(alice, charlie, tokenId); // Alice 将 NFT 转移给 Charlie
        vm.stopPrank();

        vm.startPrank(bob); // 模拟 Bob 的操作
        myERC20.approve(address(nftMarket), price);
        vm.expectRevert("NFTMarket: Seller no longer owns this NFT."); // 预期回滚并断言错误信息
        nftMarket.buyNFT(address(myERC721), tokenId); // Bob 尝试购买
        vm.stopPrank(); // 停止模拟 Bob 的操作
    }

    // 测试自购NFT
    function testBuyNFT_Fail_SelfPurchase() public {

        uint256 tokenId;
        vm.startPrank(deployer); // 模拟部署者来铸造NFT
        tokenId = myERC721.mint(alice, "uri_alice_1"); // 部署者铸造NFT给Alice
        vm.stopPrank(); // 停止模拟部署者


        vm.startPrank(alice); // 模拟 Alice 的操作
        uint256 price = 50 * 10 ** myERC20.decimals();
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, price);

        myERC20.approve(address(nftMarket), price); // Alice 授权她自己的代币
        // 预期 ERC721 内部的 transferFrom 函数会回滚，因为它检测到从当前所有者到新所有者的转移，而调用者既不是代币所有者也未被授权。
        vm.expectRevert("NFTMarket: You cannot buy your own NFT.");
        nftMarket.buyNFT(address(myERC721), tokenId); // Alice 尝试购买她自己的 NFT
        vm.stopPrank(); // 停止模拟 Alice 的操作
    }

    // 测试代币授权不足
    function testBuyNFT_Fail_InsufficientTokenAllowance() public {
        uint256 price = 100 * 10 ** myERC20.decimals(); // NFT 价格 100 MYC

        vm.startPrank(deployer); // 模拟部署者来铸造NFT
        uint256 tokenId = myERC721.mint(alice, "uri_alice_1"); // 部署者铸造NFT给Alice
        vm.stopPrank();

        vm.startPrank(alice); // 模拟 Alice 的操作
        myERC721.approve(address(nftMarket), tokenId); // Alice 授权市场转移她的 NFT
        nftMarket.list(address(myERC721), tokenId, price); // Alice 上架 NFT
        vm.stopPrank(); // 停止模拟 Alice

        vm.startPrank(bob); // 模拟 Bob 的操作 (买家)
        uint256 insufficientAllowance = 50 * 10 ** myERC20.decimals(); // 批准不足的金额：50 MYC
        myERC20.approve(address(nftMarket), insufficientAllowance); // Bob 批准市场只能花费 50 MYC

        // 修复：ERC20InsufficientAllowance 的第一个参数应该是 spender (NFTMarket) 的地址
        // 第二个参数是被授权的金额，第三个参数是需要的金额

        bytes4 expectedSelector = bytes4(keccak256("ERC20InsufficientAllowance(address,uint256,uint256)"));

        vm.expectRevert(
            abi.encodeWithSelector(
                expectedSelector, // 使用手动计算的选择器
                address(nftMarket), // 期望是 NFTMarket 合约的地址，因为它是 spender
                insufficientAllowance, // Bob 批准的金额
                price // 购买 NFT 实际需要的金额
            )
        );
        nftMarket.buyNFT(address(myERC721), tokenId); // Bob 尝试购买 (应该因授权不足而失败)
        vm.stopPrank(); // 停止模拟 Bob
    }
    // 测试代币余额不足
    function testBuyNFT_Fail_InsufficientTokenBalance() public {
        uint256 tokenId;
        vm.startPrank(deployer); // 模拟部署者来铸造NFT
        tokenId = myERC721.mint(alice, "uri_alice_1"); // 部署者铸造NFT给Alice
        vm.stopPrank(); // 停止模拟部署者


        vm.startPrank(alice); // 模拟 Alice 的操作
        uint256 price = BOB_INITIAL_BALANCE + 1; // 价格高于 Bob 的余额
        myERC721.approve(address(nftMarket), tokenId);
        nftMarket.list(address(myERC721), tokenId, price);
        vm.stopPrank(); // 停止模拟 Alice 的操作

        vm.startPrank(bob); // 模拟 Bob 的操作
        myERC20.approve(address(nftMarket), price); // Bob 授权了全额价格
        // 修复：移除 vm.expectReRevert()，直接断言最终的回滚错误
        vm.expectRevert("NFTMarket: Insufficient token balance to buy this NFT.");
        nftMarket.buyNFT(address(myERC721), tokenId); // Bob 尝试购买
        vm.stopPrank(); // 停止模拟 Bob 的操作
    }

    // 测试NFT的重复购买
    function testBuyNFT_Fail_AlreadyBought() public {
        uint256 tokenId;

        vm.startPrank(deployer); // 模拟部署者来铸造NFT
        tokenId = myERC721.mint(alice, "uri_alice_1"); // 部署者铸造NFT给Alice
        vm.stopPrank(); // 停止模拟部署者


        vm.startPrank(alice); // 模拟 Alice 的操作
        uint256 price = 50 * 10 ** myERC20.decimals();
        myERC721.approve(address(nftMarket), tokenId);// 授权NFTMarket合约转移NFT
        nftMarket.list(address(myERC721), tokenId, price); // Alice 上架 NFT
        vm.stopPrank(); // 停止模拟 Alice 的操作

        vm.startPrank(bob); // 模拟 Bob 的操作
        myERC20.approve(address(nftMarket), price);
        nftMarket.buyNFT(address(myERC721), tokenId); // Bob 成功购买 NFT
        vm.stopPrank(); // 停止模拟 Bob 的操作

        vm.startPrank(charlie); // 模拟 Charlie 的操作
        myERC20.approve(address(nftMarket), price);
        vm.expectRevert("NFTMarket: This NFT is not listed for sale."); // 预期回滚并断言错误信息
        nftMarket.buyNFT(address(myERC721), tokenId); // Charlie 尝试购买一个已经被购买的 NFT
        vm.stopPrank(); // 停止模拟 Charlie 的操作
    }


    // 模糊测试：随机上架和购买NFT
    function testFuzz_ListAndBuyNFT(uint256 priceFuzz, address sellerFuzz, address buyerFuzz) public {
        // --- 输入假设 ---
        vm.assume(priceFuzz > 0.01 ether && priceFuzz <= 10000 ether);
        vm.assume(sellerFuzz != address(0) && sellerFuzz != address(this));
        vm.assume(buyerFuzz != address(0) && buyerFuzz != address(this));
        vm.assume(sellerFuzz != buyerFuzz);

        // --- 准备工作 ---
        vm.deal(sellerFuzz, 1 ether);
        vm.deal(buyerFuzz, 1 ether);

        // 以 MyERC20 和 MyERC721 合约的部署者身份进行操作
        vm.startPrank(deployer);
        // 铸造 ERC20 代币给卖家和买家
        myERC20.mint(sellerFuzz, priceFuzz * 2);
        myERC20.mint(buyerFuzz, priceFuzz * 2);

        // 🌟 修复点：部署者铸造 NFT 给卖家 🌟
        // 部署者 (NFT 所有者) 铸造一个 NFT
        uint256 tokenId = myERC721.mint(sellerFuzz, "uri_fuzz_nft");
        vm.stopPrank(); // 停止模拟 deployer

        // --- 卖家上架 NFT ---
        vm.startPrank(sellerFuzz); // 模拟随机卖家 (此时sellerFuzz已拥有tokenId)
        // 卖家授权 NFTMarket 合约转移其 NFT
        myERC721.approve(address(nftMarket), tokenId);
        // 卖家上架 NFT
        nftMarket.list(address(myERC721), tokenId, priceFuzz);
        vm.stopPrank(); // 停止模拟卖家

        // --- 买家尝试购买 NFT ---
        vm.startPrank(buyerFuzz); // 模拟随机买家
        myERC20.approve(address(nftMarket), priceFuzz);

        // 记录购买尝试前的余额和 NFT 所有权状态
        uint256 sellerBalanceBefore = myERC20.balanceOf(sellerFuzz);
        uint256 buyerBalanceBefore = myERC20.balanceOf(buyerFuzz);
        address nftOwnerBefore = myERC721.ownerOf(tokenId);

        try nftMarket.buyNFT(address(myERC721), tokenId) {
            // --- Successful purchase assertions ---
            assertEq(myERC20.balanceOf(sellerFuzz), sellerBalanceBefore + priceFuzz, "Fuzz test: Seller balance incorrect");
            assertEq(myERC20.balanceOf(buyerFuzz), buyerBalanceBefore - priceFuzz, "Fuzz test: Buyer balance incorrect");
            assertEq(myERC721.ownerOf(tokenId), buyerFuzz, "Fuzz test: NFT ownership should be transferred to buyer");

            (address sellerFromListing, uint256 listingPriceFromListing) = nftMarket.listings(address(myERC721), tokenId);
            assertEq(sellerFromListing, address(0), "Fuzz test: Listing should be deleted after sale");
            assertEq(listingPriceFromListing, 0, "Fuzz test: Price should be 0 after sale");
        } catch Error(string memory reason) {
            // --- Revert path assertions ---
            assertEq(myERC20.balanceOf(sellerFuzz), sellerBalanceBefore, "Fuzz test: Seller balance should not change on revert");
            assertEq(myERC20.balanceOf(buyerFuzz), buyerBalanceBefore, "Fuzz test: Buyer balance should not change on revert");
            assertEq(myERC721.ownerOf(tokenId), nftOwnerBefore, "Fuzz test: NFT ownership should not change on revert");
        } catch {
            assertEq(myERC20.balanceOf(sellerFuzz), sellerBalanceBefore, "Fuzz test: Seller balance should not change on revert (other)");
            assertEq(myERC20.balanceOf(buyerFuzz), buyerBalanceBefore, "Fuzz test: Buyer balance should not change on revert (other)");
            assertEq(myERC721.ownerOf(tokenId), nftOwnerBefore, "Fuzz test: NFT ownership should not change on revert (other)");
        }
        vm.stopPrank(); // 停止模拟买家
    }
    
    // 不变性测试：NFTMarket合约不应持有任何ERC20代币
    function invariant_NFTMarketHasNoERC20() public view {
        assertEq(myERC20.balanceOf(address(nftMarket)), 0, "NFTMarket should never hold ERC20 tokens");
    }

    // 不变性测试：NFTMarket合约不应持有任何ERC721 NFT
    function invariant_NFTMarketHasNoERC721() public {
        // Foundry 的不变性测试会通过随机调用合约函数来尝试打破此断言。
        // NFTMarket 合约充当交易中介，不应永久持有任何 NFT；它仅在上架期间获得授权。
        // transferFrom 逻辑确保所有权直接在卖家和买家之间转移。
        assertEq(myERC721.balanceOf(address(nftMarket)), 0, "NFTMarket should never own any ERC721 NFTs");
    }
}