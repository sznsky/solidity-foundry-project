// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MyERC20Permit} from "../src/MyERC20Permit.sol";
import {MyERC721} from "../src/MyERC721.sol";
import {AirdopMerkleNFTMarket} from "../src/AirdopMerkleNFTMarket.sol";
import {Merkle} from "murky/Merkle.sol";

contract AirdopMerkleNFTMarketTest is Test {
    MyERC20Permit public token;
    MyERC721 public nft;
    AirdopMerkleNFTMarket public market;
    Merkle public m;

    address public deployer = address(this);
    address public seller = makeAddr("seller");
    address public whitelistedBuyer = makeAddr("whitelistedBuyer");
    address public nonWhitelistedBuyer = makeAddr("nonWhitelistedBuyer");
    uint256 public sellerPk = 0x123;
    uint256 public buyerPk = 0x456;

    uint256 public constant MINT_AMOUNT = 1_000_000 * 10**18;
    uint256 public constant NFT_PRICE = 100 * 10**18;

    function setUp() public {
        vm.startPrank(deployer);
        // 1. Setup Merkle Tree
        m = new Merkle();
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256(abi.encodePacked(whitelistedBuyer));
        bytes32 merkleRoot = m.getRoot(leaves);

        // 2. Deploy contracts
        token = new MyERC20Permit();
        nft = new MyERC721();
        market = new AirdopMerkleNFTMarket(address(token), address(nft), merkleRoot);

        // 3. Mint assets
        token.mint(seller, MINT_AMOUNT);
        token.mint(whitelistedBuyer, MINT_AMOUNT);
        nft.mint(seller, "ipfs://some_uri"); // tokenId = 0
        vm.stopPrank();
    }

    function test_AirdropClaim() public {
        // 1. Seller lists the NFT
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(0, NFT_PRICE);
        vm.stopPrank();

        // 2. Whitelisted buyer prepares for multicall
        vm.startPrank(whitelistedBuyer);
        bytes32[] memory proof = m.getProof(
            new bytes32[](1), // The leaves array from setup
            0,               // index of the leaf we want to prove
            keccak256(abi.encodePacked(whitelistedBuyer))
        );
        uint256 discountedPrice = NFT_PRICE / 2;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 3. Buyer signs the permit message
        bytes32 digest = token.getPermitDigest(
            whitelistedBuyer,
            address(market),
            discountedPrice,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPk, digest);

        // 4. Construct multicall data
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

        // 5. Execute multicall
        market.multicall(calls);

        // 6. Assert results
        assertEq(nft.ownerOf(0), whitelistedBuyer, "NFT should be owned by the buyer");
        assertEq(token.balanceOf(seller), MINT_AMOUNT + discountedPrice, "Seller should receive payment");
        assertEq(token.balanceOf(whitelistedBuyer), MINT_AMOUNT - discountedPrice, "Buyer's balance should be deducted");
    }
}