// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Bank.sol";

contract DepositToBank is Script {
    function run() external {
        // 使用钱包3私钥存款
        uint256 depositPrivateKey = vm.envUint("PRIVATE_KEY3");
        //address depositAddress = vm.addr(depositPrivateKey);
        // 存钱到Bank合约的地址
        address bankAddress = vm.envAddress("BANK_ADDRESS");

        vm.startBroadcast(depositPrivateKey);

        // 调用 deposit 并附带 0.02 ETH
        Bank(bankAddress).deposit{value: 0.02 ether}();

        vm.stopBroadcast();
    }
}
