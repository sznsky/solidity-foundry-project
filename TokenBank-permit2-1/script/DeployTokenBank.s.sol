// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console2} from "forge-std/Script.sol";
import {TokenBank} from "../src/TokenBank.sol"; // 确保路径正确，指向你的 TokenBank.sol

contract DeployTokenBank is Script {
    // Sepolia 测试网上的 Permit2 官方地址
    // 如果你是在 Anvil 的非 fork 模式下测试，请替换为你的本地 Permit2 地址
    address public immutable PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // 你要部署到的链 ID
    // 11155111 是 Sepolia 测试网的 Chain ID
    // 31337 是 Anvil 默认的 Chain ID (如果你没有 fork)
    uint256 public immutable TARGET_CHAIN_ID = 11155111; // 根据你的目标链修改

    function run() public returns (TokenBank tokenBank) {
        // 从环境变量中获取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 使用私钥获取部署者地址
        address deployerAddress = vm.addr(deployerPrivateKey);

        console2.log("deployee address at:", deployerAddress);
        console2.log("deployee TokenBank chian ID:", TARGET_CHAIN_ID);
        console2.log("use Permit2 address:", PERMIT2_ADDRESS);

        // 开始广播交易，所有后续的创建和交易都将使用此私钥
        vm.startBroadcast(deployerPrivateKey);

        // 部署 TokenBank 合约，将 PERMIT2_ADDRESS 作为构造函数参数传入
        tokenBank = new TokenBank(PERMIT2_ADDRESS);

        console2.log("TokenBank deployee success,address:", address(tokenBank));

        // 停止广播
        vm.stopBroadcast();
    }
}