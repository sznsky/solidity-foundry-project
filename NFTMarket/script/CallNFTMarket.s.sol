// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/NFTMarket.sol";
import "../src/MyERC721.sol";

contract CallNFTMarket is Script {
    function run() external {
        // 1. 部署者私钥（ERC20 owner）
        uint256 ownerKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(ownerKey);

        // 2. 买家私钥
        uint256 buyerKey = vm.envUint("PRIVATE_KEY_BUYER");
        address buyer = vm.addr(buyerKey);

        // 合约地址
        address marketAddr = 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9;
        address nftAddr = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
        address erc20Addr = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;

        NFTMarket market = NFTMarket(marketAddr);
        MyERC721 nft = MyERC721(nftAddr);
        MyERC20 myERC20 = MyERC20(erc20Addr);

        // === 部署者 mint 代币给买家 ===
        vm.startBroadcast(ownerKey);
        uint256 mintAmount = 100 ether;
        myERC20.mint(buyer, mintAmount);
        vm.stopBroadcast();

        // === 卖家 mint NFT 并上架 ===
        vm.startBroadcast(ownerKey);
        uint256 tokenId = nft.mint(owner, "ipfs://example-uri");
        nft.approve(marketAddr, tokenId);
        uint256 price = 10 ether;
        market.list(nftAddr, tokenId, price);
        vm.stopBroadcast();

        // === 买家购买 NFT ===
        vm.startBroadcast(buyerKey);
        // 买家需要先给市场合约 approve ERC20 代币花费权限
        myERC20.approve(marketAddr, price);
        market.buyNFT(nftAddr, tokenId);
        vm.stopBroadcast();
    }
}
