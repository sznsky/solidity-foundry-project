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
        address myERC20Address = 0x1Fc4f8ff6a2Ad8AD1D196B9833302cF7E8d9C3B3;

        // 部署 NFTMarket
        NFTMarket market = new NFTMarket(myERC20Address);

        console.log("NFTMarket deployed at:", address(market));

        vm.stopBroadcast();
    }
}
