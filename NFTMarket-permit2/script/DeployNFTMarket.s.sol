// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {NFTMarket} from "../src/NFTMarket.sol"; // 导入 NFTMarket
import {MyERC20} from "../src/MyERC20.sol";     // 导入 MyERC20
import {MyERC721} from "../src/MyERC721.sol";   // 导入 MyERC721

contract DeployNFTMarket is Script {
    function run() public returns (NFTMarket, MyERC20, MyERC721) {
        vm.startBroadcast();

        // 部署 MyERC20
        MyERC20 myERC20 = new MyERC20();
        address myERC20Address = address(myERC20);

        // 部署 MyERC721
        MyERC721 myERC721 = new MyERC721();
        address myERC721Address = address(myERC721);

        // !!在这里添加 signerAddress 参数!!
        // 假设部署者就是 signerAddress，或者你可以定义一个固定的地址
        address signerAddress = msg.sender; // 或者替换为一个你控制的地址，例如 0xYourSignerAddress;

        NFTMarket market = new NFTMarket(myERC20Address, signerAddress); // 传入两个参数

        vm.stopBroadcast();
        return (market, myERC20, myERC721);
    }
}