// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Bank} from "../src/Bank.sol";

contract DeployBank is Script {
    function run() external {
        // 使用 Foundry 的私钥机制
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployer);

        // 设置你的 Vault 地址（接收资金的地址）
        address payable vault = payable(vm.envAddress("VAULT"));
        
        // 部署合约
        Bank bank = new Bank(vault);

        console.log("Bank contract deployed at:", address(bank));

        vm.stopBroadcast();
    }
}
