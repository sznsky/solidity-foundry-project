// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/NFTMarket.sol";
import "../src/MyERC20.sol";

contract DeployNFTMarket is Script {
    function run() external {
        // 从私钥导出部署者
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // 开始广播交易（部署会真正发生）
        vm.startBroadcast(deployerPrivateKey);

        // MyERC20 地址（你已经部署的合约地址）
        address myERC20Address = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;

        // 部署 NFTMarket
        NFTMarket market = new NFTMarket(myERC20Address);

        console.log("NFTMarket deployed at:", address(market));

        vm.stopBroadcast();
    }
}
