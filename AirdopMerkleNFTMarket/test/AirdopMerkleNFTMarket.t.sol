// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MyERC20Permit} from "../src/MyERC20Permit.sol";
import {MyERC721} from "../src/MyERC721.sol";
import {AirdopMerkleNFTMarket} from "../src/AirdopMerkleNFTMarket.sol";
import {MerkleProof} from "@openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

contract AirdopMerkleNFTMarketTest is Test {
    MyERC20Permit public token;
    MyERC721 public nft;
    AirdopMerkleNFTMarket public market;

    address public deployer = address(this);
    address public seller = makeAddr("seller");
    address public whitelistedBuyer = makeAddr("whitelistedBuyer");
    address public nonWhitelistedBuyer = makeAddr("nonWhitelistedBuyer");
    uint256 public sellerPk = 0x123;
    uint256 public buyerPk = 0x456;

    uint256 public constant MINT_AMOUNT = 1_000_000 * 10**18;
    uint256 public constant NFT_PRICE = 100 * 10**18;

    // 用于存储 Merkle Tree 的根哈希
    bytes32 public merkleRoot;

    // 用于存储 Merkle Tree 的叶子节点，以便后面生成证明
    bytes32[] public leaves;

    function setUp() public {
        vm.startPrank(deployer);

        // **使用 vm.addr(privateKey) 来确保地址和私钥是匹配的**
        seller = vm.addr(sellerPk);
        whitelistedBuyer = vm.addr(buyerPk);

        // 1. **在测试中手动生成 Merkle Tree 的根哈希和证明**
        leaves = new bytes32[](1);
        leaves[0] = keccak256(abi.encodePacked(whitelistedBuyer));
        
        // 由于 MerkleProof 库不支持在链上生成默克尔树，我们必须手动计算根
        // 对于只有一个叶子节点的树，根就是叶子本身。
        merkleRoot = leaves[0];

        // 2. 部署合约
        token = new MyERC20Permit();
        nft = new MyERC721();
        market = new AirdopMerkleNFTMarket(address(token), address(nft), merkleRoot);

        // 3. 铸造资产
        token.mint(seller, MINT_AMOUNT);
        token.mint(whitelistedBuyer, MINT_AMOUNT);
        nft.mint(seller, "ipfs://some_uri");// tokenId = 0
        vm.stopPrank();
    }

    function test_AirdropClaim() public {
        // 1. 卖家上架 NFT
        vm.startPrank(seller);
        // **确保卖家先批准市场合约来操作其 NFT**
        nft.approve(address(market), 0);
        // 上架操作
        market.list(0, NFT_PRICE);
        vm.stopPrank();

        // 2. 白名单买家准备 multicall
        vm.startPrank(whitelistedBuyer);

        // 因为只有一个叶子节点，证明数组是空的
        bytes32[] memory proof = new bytes32[](0);

        uint256 discountedPrice = NFT_PRICE / 2;
        uint256 deadline = block.timestamp + 1 hours;

        // 3. 买家对 permit 消息进行签名
        bytes32 digest = token.getPermitDigest(
            whitelistedBuyer,
            address(market),
            discountedPrice,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPk, digest);

        // 4. 构造 multicall 数据
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            AirdopMerkleNFTMarket.permitPrePay.selector,
            whitelistedBuyer,
            address(market),
            discountedPrice,
            deadline,
            v, r, s
        );
        calls[1] = abi.encodeWithSelector(
            AirdopMerkleNFTMarket.claimNFT.selector,
            0,
            proof
        );

        // 5. 执行 multicall
        market.multicall(calls);

        // 6. 验证结果
        assertEq(nft.ownerOf(0), whitelistedBuyer, unicode"NFT 应该被买家拥有");
        assertEq(token.balanceOf(seller), MINT_AMOUNT + discountedPrice, unicode"卖家应该收到付款");
        assertEq(token.balanceOf(whitelistedBuyer), MINT_AMOUNT - discountedPrice, unicode"买家余额应该被扣除");
    }
}