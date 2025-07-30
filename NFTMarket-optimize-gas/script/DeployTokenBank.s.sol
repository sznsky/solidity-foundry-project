// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyERC20.sol";
import "../src/TokenBank.sol";

contract DeployTokenBank is Script {
    function run() external {
        // 加载 deployer 的私钥（你需要在 .env 设置）
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 MyERC20（或者你也可以填入已知地址）
        MyERC20 token = new MyERC20();

        // 2. 部署 TokenBank，绑定 MyERC20 地址
        TokenBank bank = new TokenBank(address(token));

        vm.stopBroadcast();

        // 打印部署结果
        console2.log("Token address:", address(token));
        console2.log("TokenBank address:", address(bank));
    }
}
