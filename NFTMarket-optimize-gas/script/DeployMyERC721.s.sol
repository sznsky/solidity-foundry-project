// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MyERC721} from "../src/MyERC721.sol"; // 根据你的合约路径调整

contract DeployMyERC721 is Script {
    function run() public returns (MyERC721 myERC721) {
        vm.startBroadcast(); // 开始广播交易

        myERC721 = new MyERC721(); // 部署你的 MyERC721 合约

        vm.stopBroadcast(); // 停止广播交易
    }
}