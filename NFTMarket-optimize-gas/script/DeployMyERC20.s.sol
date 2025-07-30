// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyERC20.sol"; // 引入你的合约

contract DeployMyERC20 is Script {
    function run() public returns (MyERC20) {
        // 加载私钥 (推荐使用环境变量)
        // 例如：vm.envUint("PRIVATE_KEY")
        // 或者直接使用 Foundry 命令行参数 --private-key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 开始广播交易 (Foundry 会模拟链上交易)
        vm.startBroadcast(deployerPrivateKey);

        // 部署 MyERC20 合约
        MyERC20 myToken = new MyERC20();

        // 停止广播
        vm.stopBroadcast();

        console.log("MyERC20 deployed at:", address(myToken));
        return myToken;
    }
}