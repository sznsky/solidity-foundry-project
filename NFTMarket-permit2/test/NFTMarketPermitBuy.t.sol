// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {MyERC20} from "../src/MyERC20.sol";
import {MyERC721} from "../src/MyERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract NFTMarketPermitBuyTest is Test {
    NFTMarket public nftMarket;
    MyERC20 public myERC20;
    MyERC721 public myERC721;

    // 定义用于测试的地址
    address public deployer;
    address public alice;   // 购买者 (白名单用户)
    address public bob;     // 销售者
    address public signer; // 项目方签名者

    // 需要签名的测试账户的私钥
    uint256 privateKeyDeployer;
    uint256 privateKeyAlice;
    uint256 privateKeyBob;
    uint256 privateKeySigner; // 'signer' 地址将用于 vm.sign 的私钥

    // NFT 和价格
    uint256 public mintedNFTId; // 用于存储 MyERC721 铸造后返回的 tokenId
    uint256 public constant LISTING_PRICE = 100 * 10**18; // 100 MyERC20 代币 (假设18位小数)

    // 在测试合约中声明事件，以便 expectEmit 能够识别它
    event NFTSold(
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address indexed buyer,
        uint256 price
    );

    function setUp() public {
        // 生成私钥并关联地址
        privateKeyDeployer = 0x123; // 示例私钥，为每个地址使用唯一的私钥
        deployer = vm.addr(privateKeyDeployer);
        vm.label(deployer, "deployer");

        privateKeyAlice = 0x456;
        alice = vm.addr(privateKeyAlice);
        vm.label(alice, "alice");

        privateKeyBob = 0x789;
        bob = vm.addr(privateKeyBob);
        vm.label(bob, "bob");

        privateKeySigner = 0xabc; // 这是 'signer' 地址将用于 vm.sign 的私钥
        signer = vm.addr(privateKeySigner);
        vm.label(signer, "signer");

        // 给账户分配一些以太币 (良好实践，尤其是在真实场景中用于 Gas)
        vm.deal(deployer, 10 ether);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(signer, 10 ether); // 签名者也需要一些以太币

        // 部署 MyERC20 合约
        vm.startPrank(deployer);
        myERC20 = new MyERC20();
        // 给 Alice 足够的 MyERC20 代币来购买 NFT
        myERC20.mint(alice, LISTING_PRICE * 2); // 给双倍，以防万一
        // 确保 Bob 也有足够的代币，以防他在其他测试中成为买家（比如 testPermitBuy_RevertWhenBuyerIsSeller）
        myERC20.mint(bob, LISTING_PRICE * 2);
        vm.stopPrank();

        // 部署 MyERC721 合约
        vm.startPrank(deployer);
        myERC721 = new MyERC721(); // MyERC721 构造函数不接收参数
        // Bob 铸造一个 NFT，并捕获返回的 tokenId
        mintedNFTId = myERC721.mint(bob, "ipfs://testuri/1"); // MyERC721.mint 接收 student 和 tokenURI
        vm.stopPrank();

        // 部署 NFTMarket 合约
        vm.startPrank(deployer);
        nftMarket = new NFTMarket(address(myERC20), signer); // 传入 MyERC20 地址和签名者地址
        vm.stopPrank();

        // Bob 授权 NFTMarket 合约转移他的 NFT
        vm.startPrank(bob);
        myERC721.approve(address(nftMarket), mintedNFTId); // 使用实际铸造的 NFT ID
        vm.stopPrank();

        // Bob 将 NFT 上架
        vm.startPrank(bob);
        nftMarket.list(address(myERC721), mintedNFTId, LISTING_PRICE); // 使用实际铸造的 NFT ID
        vm.stopPrank();

        // 验证 NFT 已上架
        NFTMarket.Listing memory currentListing = nftMarket.getListing(address(myERC721), mintedNFTId); // 使用实际铸造的 NFT ID
        assertEq(currentListing.seller, bob, "NFT should be listed by Bob");
        assertEq(currentListing.price, LISTING_PRICE, "NFT listing price incorrect");
    }

    /// @dev 测试 permitBuy 成功购买的情况
    function testPermitBuy_Success() public {
        // Alice 必须授权 NFTMarket 合约来花费她的 MyERC20 代币
        vm.startPrank(alice);
        myERC20.approve(address(nftMarket), LISTING_PRICE); // 授权足够的价格
        vm.stopPrank();

        // 1. 准备要签名的消息哈希 (即 buyer 的地址)
        bytes32 messageHash = keccak256(abi.encodePacked(alice));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // 2. 项目方 (signer) 离线签名这个消息哈希
        // 使用与 'signer' 地址关联的私钥进行签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeySigner, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 记录购买前的余额和所有权
        uint256 bobInitialTokenBalance = myERC20.balanceOf(bob);
        uint256 aliceInitialTokenBalance = myERC20.balanceOf(alice);
        address initialNFTOwner = myERC721.ownerOf(mintedNFTId); // 使用实际铸造的 NFT ID

        // 验证初始状态
        assertEq(initialNFTOwner, bob, "NFT initial owner should be Bob");
        assertGt(aliceInitialTokenBalance, LISTING_PRICE, "Alice should have enough tokens");

        // 3. Alice 调用 permitBuy 函数
        // 期望 NFTMarket 合约在成功购买时触发 NFTSold 事件
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit NFTSold(address(myERC721), mintedNFTId, bob, alice, LISTING_PRICE); // 确保事件匹配
        nftMarket.permitBuy(address(myERC721), mintedNFTId, signature); // 使用实际铸造的 NFT ID
        vm.stopPrank();

        // *** 在这里添加日志打印 ***
        console2.log("PermitBuy function:NFT with ID %s transferred from %s(bob) to %s(alice).", mintedNFTId, bob, alice);


        // 4. 验证购买结果
        // 检查 NFT 所有权是否已转移到 Alice
        assertEq(myERC721.ownerOf(mintedNFTId), alice, "NFT should be transferred to Alice"); // 使用实际铸造的 NFT ID
        // 检查 Bob 是否收到了代币
        assertEq(myERC20.balanceOf(bob), bobInitialTokenBalance + LISTING_PRICE, "Bob should receive tokens");
        // 检查 Alice 的代币是否被扣除
        assertEq(myERC20.balanceOf(alice), aliceInitialTokenBalance - LISTING_PRICE, "Alice's tokens should be deducted");
        // 检查 NFT 是否已从列表中移除
        NFTMarket.Listing memory listingAfterSale = nftMarket.getListing(address(myERC721), mintedNFTId); // 使用实际铸造的 NFT ID
        assertEq(listingAfterSale.seller, address(0), "NFT should be unlisted after sale");
    }

    /// @dev 测试重复使用签名
    function testPermitBuy_RevertWhenSignatureUsed() public {
        // Alice 必须授权 NFTMarket 合约来花费她的 MyERC20 代币
        vm.startPrank(alice);
        myERC20.approve(address(nftMarket), LISTING_PRICE * 2); // 授权足够两次购买的金额，虽然第二次会回滚
        vm.stopPrank();

        // 1. 生成签名 (与成功测试相同)
        bytes32 messageHash = keccak256(abi.encodePacked(alice));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeySigner, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 2. 第一次调用 permitBuy (应该成功)
        vm.startPrank(alice);
        nftMarket.permitBuy(address(myERC721), mintedNFTId, signature); // 使用实际铸造的 NFT ID
        vm.stopPrank();

        // 3. 再次调用 permitBuy，预期失败
        vm.expectRevert("NFTMarket: Signature already used.");
        vm.startPrank(alice);
        nftMarket.permitBuy(address(myERC721), mintedNFTId, signature); // 使用实际铸造的 NFT ID
        vm.stopPrank();
    }

    /// @dev 测试签名无效（例如，签名者不是授权项目方）
    function testPermitBuy_RevertWhenInvalidSigner() public {
        uint256 privateKeyMaliciousSigner = 0xdef;
        address maliciousSigner = vm.addr(privateKeyMaliciousSigner);
        vm.label(maliciousSigner, "maliciousSigner");
        vm.deal(maliciousSigner, 10 ether); // 也给恶意签名者一些以太币

        // 1. 生成由恶意签名者签名的消息哈希
        bytes32 messageHash = keccak256(abi.encodePacked(alice));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyMaliciousSigner, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 2. Alice 尝试用恶意签名购买，预期失败
        vm.expectRevert("NFTMarket: Invalid signature or not whitelisted.");
        vm.startPrank(alice);
        nftMarket.permitBuy(address(myERC721), mintedNFTId, signature); // 使用实际铸造的 NFT ID
        vm.stopPrank();
    }

    /// @dev 测试买家余额不足
    function testPermitBuy_RevertWhenInsufficientBalance() public {
        // 1. 生成签名
        bytes32 messageHash = keccak256(abi.encodePacked(alice));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeySigner, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 2. 将 Alice 的代币余额设置为不足以购买 NFT
        // 修复方法：将代币转移给一个临时地址，而不是零地址
        address tempBurnAddress = vm.addr(0xaaaa); // 使用一个新的临时地址
        vm.label(tempBurnAddress, "tempBurnAddress");
        vm.startPrank(alice);
        myERC20.transfer(tempBurnAddress, myERC20.balanceOf(alice)); // 将所有代币发送到临时地址
        vm.stopPrank();

        assertEq(myERC20.balanceOf(alice), 0, "Alice should have no tokens");

        // 3. Alice 尝试购买，预期失败
        vm.expectRevert("NFTMarket: Insufficient token balance to buy this NFT.");
        vm.startPrank(alice);
        nftMarket.permitBuy(address(myERC721), mintedNFTId, signature); // 使用实际铸造的 NFT ID
        vm.stopPrank();
    }

    /// @dev 测试 NFT 未上架
    function testPermitBuy_RevertWhenNFTNotListed() public {
        // 假设有一个新的 NFT ID 未上架（我们将铸造一个新的，但不会上架）
        uint256 unlistedNFTId;
        vm.startPrank(deployer); // 确保是合约 owner (deployer) 在执行 mint
        unlistedNFTId = myERC721.mint(bob, "ipfs://testuri/99"); // 铸造给 bob
        vm.stopPrank();

        // 1. 生成签名
        bytes32 messageHash = keccak256(abi.encodePacked(alice));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeySigner, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 2. Alice 尝试购买未上架的 NFT，预期失败
        vm.expectRevert("NFTMarket: This NFT is not listed for sale.");
        vm.startPrank(alice);
        nftMarket.permitBuy(address(myERC721), unlistedNFTId, signature); // 使用未上架的 NFT ID
        vm.stopPrank();
    }

    /// @dev 测试卖家不再拥有 NFT
    function testPermitBuy_RevertWhenSellerNoLongerOwnsNFT() public {
        // 1. Bob 将 NFT 上架 (已经在 setUp 中完成)

        // 2. Bob 意外地将 NFT 转移给其他人（例如自己）
        vm.startPrank(bob);
        myERC721.transferFrom(bob, deployer, mintedNFTId); // 转移给 deployer，使用实际铸造的 NFT ID
        vm.stopPrank();

        // 验证 NFT 所有权已更改
        assertEq(myERC721.ownerOf(mintedNFTId), deployer, "NFT should be transferred away from Bob"); // 使用实际铸造的 NFT ID

        // 3. 生成签名
        bytes32 messageHash = keccak256(abi.encodePacked(alice));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeySigner, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 4. Alice 尝试购买，预期失败
        vm.expectRevert("NFTMarket: Seller no longer owns this NFT.");
        vm.startPrank(alice);
        nftMarket.permitBuy(address(myERC721), mintedNFTId, signature); // 使用实际铸造的 NFT ID
        vm.stopPrank();
    }

    /// @dev 测试买家就是卖家
    function testPermitBuy_RevertWhenBuyerIsSeller() public {
        // 这个测试用例需要一个特殊的设置，因为 'signer' 在 setUp 中是全局定义的。
        // 为了避免副作用，我们在这里使用一个新的私钥和地址来模拟 'bob' 作为签名者的情况。

        uint256 tempPrivateKeyBobAsSigner = 0xddeeff; // 新的私钥
        address bobAsSigner = vm.addr(tempPrivateKeyBobAsSigner);
        vm.label(bobAsSigner, "bobAsSigner");
        vm.deal(bobAsSigner, 10 ether); // 给这个新地址一些以太币

        // 1. 部署一个新的 NFT 市场合约，将 'bobAsSigner' 设置为签名者
        vm.startPrank(deployer);
        NFTMarket tempNftMarket = new NFTMarket(address(myERC20), bobAsSigner);
        vm.stopPrank();

        // 2. 铸造一个新的 NFT 给 Bob
        vm.startPrank(deployer);
        uint256 bobNewNFTId = myERC721.mint(bob, "ipfs://newuri/1");
        vm.stopPrank();

        // 3. Bob 授权新的 NFT 给新的市场合约并上架
        vm.startPrank(bob);
        myERC721.approve(address(tempNftMarket), bobNewNFTId);
        tempNftMarket.list(address(myERC721), bobNewNFTId, LISTING_PRICE);
        vm.stopPrank();

        // 4. 生成由 Bob (signer) 签名的消息哈希 (Bob 尝试购买自己的 NFT)
        bytes32 messageHash = keccak256(abi.encodePacked(bob)); // 这里仍然是 bob 的地址，因为他尝试购买自己的 NFT
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        // 使用 BobAsSigner 的私钥来模拟他作为签名者
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(tempPrivateKeyBobAsSigner, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 5. Bob 尝试购买自己的 NFT，预期失败
        vm.expectRevert("NFTMarket: You cannot buy your own NFT.");
        vm.startPrank(bob); // 此时 msg.sender 是 Bob
        tempNftMarket.permitBuy(address(myERC721), bobNewNFTId, signature); // 使用 Bob 新上架的 NFT ID
        vm.stopPrank();
    }
}