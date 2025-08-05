// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.22;

import "forge-std/Test.sol";

import {MyERC721} from "../src/MyERC721.sol";
import {NFTMarketplaceV1} from "../src/NFTMarketplaceV1.sol";
import {NFTMarketplaceV2} from "../src/NFTMarketplaceV2.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

interface IUUPS {
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}

contract NFTMarketplaceV2Test is Test {
    MyERC721 public nft;
    NFTMarketplaceV1 public marketplaceV1;
    NFTMarketplaceV2 public marketplaceV2;
    ERC1967Proxy public proxy;

    uint256 privateKeyDeployer = 1;
    address deployer;
    address alice;

    // 使用 uint256(2) 作为 alice 的私钥
    uint256 privateKeyAlice = 2;
    //address alice = address(privateKeyAlice);
    address bob = address(3);

    function setUp() public {
        deployer = vm.addr(privateKeyDeployer);

        alice = vm.addr(privateKeyAlice);

        // ⬇ 使用 deployer 签名部署合约
        vm.startPrank(deployer);
        nft = new MyERC721();
        nft.initialize();
        nft.safeMint(alice);
        marketplaceV1 = new NFTMarketplaceV1();
        bytes memory data = abi.encodeWithSignature("initialize(address)", deployer);
        proxy = new ERC1967Proxy(address(marketplaceV1), data);
        marketplaceV1 = NFTMarketplaceV1(address(proxy));
        vm.stopPrank();

        // alice 授权
        vm.startPrank(alice);
        nft.setApprovalForAll(address(proxy), true);
        vm.stopPrank();
    }

    function testV1_ListAndBuy() public {
            // 单独 mint 0 给 alice
        vm.startPrank(deployer);
        nft.safeMint(alice); // tokenId = 0
        vm.stopPrank();


        vm.startPrank(alice);
        marketplaceV1.listNFT(address(nft), 0, 1 ether);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), address(proxy));

        vm.deal(bob, 10 ether);
        vm.startPrank(bob);
        marketplaceV1.buyNFT{value: 1 ether}(address(nft), 0);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), bob);
    }

    function testUpgradeToV2_AndListWithSig() public {
        vm.startPrank(deployer);
        marketplaceV2 = new NFTMarketplaceV2();

        bytes memory callData = abi.encodePacked(NFTMarketplaceV2(address(proxy)).initializeV2.selector);


        IUUPS(address(proxy)).upgradeToAndCall(address(marketplaceV2), callData);


        // 调用 V2 初始化函数
        //NFTMarketplaceV2(address(proxy)).initializeV2();
        vm.stopPrank();

        // alice mint 新 NFT 并授权
        vm.startPrank(deployer);
        nft.safeMint(alice);
        vm.stopPrank();

        vm.startPrank(alice);
        nft.setApprovalForAll(address(proxy), true);

        marketplaceV2 = NFTMarketplaceV2(address(proxy));

        bytes32 structHash = keccak256(abi.encode(
            marketplaceV2.LIST_TYPEHASH(),
            address(nft),
            1,
            2 ether
        ));
        bytes32 digest = marketplaceV2.hashTypedDataV4Public(structHash);

        // 3. 修正 vm.sign 的私钥参数为 alice 的私钥
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyAlice, digest);
        //(uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(uint160(alice)), digest);
        bytes memory signature = abi.encodePacked(r, s, v);


        vm.startPrank(bob);
        marketplaceV2.listWithSig(address(nft), 1, 2 ether, signature);
        vm.stopPrank();

        assertEq(nft.ownerOf(1), address(proxy));

        (address seller, uint256 price) = marketplaceV2.listings(address(nft), 1);
        assertEq(seller, alice);
        assertEq(price, 2 ether);
    }

    // function testV2_StillSupportsV1Functions() public {
    //     vm.startPrank(deployer);
    //     marketplaceV2 = new NFTMarketplaceV2();
    //     IUUPS(address(proxy)).upgradeTo(address(marketplaceV2));
    //     NFTMarketplaceV2(address(proxy)).initializeV2();
    //     vm.stopPrank();

    //     marketplaceV2 = NFTMarketplaceV2(address(proxy));

    //     vm.startPrank(alice);
    //     marketplaceV2.listNFT(address(nft), 0, 1 ether);
    //     vm.stopPrank();

    //     assertEq(nft.ownerOf(0), address(proxy));

    //     vm.deal(bob, 10 ether);
    //     vm.startPrank(bob);
    //     marketplaceV2.buyNFT{value: 1 ether}(address(nft), 0);
    //     vm.stopPrank();

    //     assertEq(nft.ownerOf(0), bob);
    // }
}
