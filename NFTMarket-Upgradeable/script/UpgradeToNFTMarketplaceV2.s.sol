// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import {NFTMarketplaceV2} from "../src/NFTMarketplaceV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

//address private constant V1_PROXY_ADDRESS = address(0);

address constant V1_PROXY_ADDRESS = 0xf81125E7E76Fc8eCF35D668f5887571b4DEDdEF0;


// 用于升级的 UUPS 接口
interface IUUPS {
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}

// 升级合约
contract UpgradeToNFTMarketplaceV2 is Script {
    // 代理合约地址（已部署的NFTMarketplaceV1代理）
    //address proxyAddress = 0xf81125E7E76Fc8eCF35D668f5887571b4DEDdEF0;

    function run() external {
        // 获取部署者私钥和地址
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // 1. 部署 NFTMarketplaceV2 实现合约
        vm.startBroadcast(deployerPrivateKey);
        NFTMarketplaceV2 marketplaceV2Implementation = new NFTMarketplaceV2();
        console.log("V2 Implementation deployed to:", address(marketplaceV2Implementation));
        vm.stopBroadcast();
        
        // 2. 编码初始化函数调用数据
        // 这将调用 V2 合约的 initializeV2()，使用 abi.encodePacked
        bytes memory callData = abi.encodePacked(NFTMarketplaceV2(V1_PROXY_ADDRESS).initializeV2.selector);

        // 3. 通过代理合约执行升级
        // 这将用 V2 实现合约地址更新代理合约，并立即调用 initializeV2()
        vm.startBroadcast(deployerPrivateKey);
        IUUPS(V1_PROXY_ADDRESS).upgradeToAndCall(address(marketplaceV2Implementation), callData);
        vm.stopBroadcast();

        console.log("Upgrade to V2 successful. Proxy address remains:", V1_PROXY_ADDRESS);
    }
}
