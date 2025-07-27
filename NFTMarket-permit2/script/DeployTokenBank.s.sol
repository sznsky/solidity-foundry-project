// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TokenBank} from "../src/TokenBank.sol";
import {MyERC20Permit} from "../src/MyERC20Permit.sol"; // 假设你的 MyERC20Permit 在 src 目录下

contract TokenBankDeploy is Script {
    function run() external returns (TokenBank tokenBank, MyERC20Permit myToken) {
        // 设置私钥，用于部署。在生产环境中，请使用环境变量或 KMS。
        // vm.startBroadcast() 和 vm.stopBroadcast() 会使用此私钥发送交易。
        // 这里只是示例，你可以从环境变量中获取，例如 vm.envUint("PRIVATE_KEY")
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address permit2Address = vm.envAddress("PERMIT2_ADDRESS"); // 从环境变量获取 Permit2 地址

        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 MyERC20Permit 代币合约
        // 如果你的代币已经部署，并且你只是想使用现有的代币，
        // 那么你可以直接传入已部署的代币地址，跳过这一步。
        // 例如：address existingTokenAddress = 0x...;
        // MyERC20Permit myToken = MyERC20Permit(existingTokenAddress);
        myToken = new MyERC20Permit("MyERC20PermitToken", "MPT", 18);
        console.log("MyERC20Permit deployed at:", address(myToken));

        // 2. 部署 TokenBank 合约
        // 传入部署的代币地址和 Permit2 合约地址
        // 请确保 PERMIT2_ADDRESS 在你部署的网络上是正确的 Permit2 合约地址
        // 例如，在 Sepolia 测试网上，Permit2 的地址通常是固定的。
        // 你可以通过 Uniswap 官方文档或 Etherscan 查询。
        require(permit2Address != address(0), "Permit2 address not set in environment variables");
        tokenBank = new TokenBank(address(myToken), permit2Address);
        console.log("TokenBank deployed at:", address(tokenBank));

        vm.stopBroadcast();

        return (tokenBank, myToken);
    }
}