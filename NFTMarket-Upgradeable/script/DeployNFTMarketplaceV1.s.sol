// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import {NFTMarketplaceV1} from "../src/NFTMarketplaceV1.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployNFTMarketplaceV1 is Script {
    function run() external {
        // 获取部署者地址
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // 1. 部署 NFTMarketplaceV1 实现合约
        vm.startBroadcast(deployerPrivateKey);
        NFTMarketplaceV1 marketplaceV1Implementation = new NFTMarketplaceV1();
        console.log("V1 Implementation deployed to:", address(marketplaceV1Implementation));
        vm.stopBroadcast();

        // 2. 编码初始化函数调用
        // 这将调用 V1 合约的 initialize 函数，并设置部署者为合约的 owner
        bytes memory data = abi.encodeWithSignature("initialize(address)", deployer);

        // 3. 部署代理合约，并传入实现合约地址和初始化数据
        // 代理合约部署完成后，它就已经初始化并准备好使用了
        vm.startBroadcast(deployerPrivateKey);
        ERC1967Proxy proxy = new ERC1967Proxy(address(marketplaceV1Implementation), data);
        console.log("V1 Proxy deployed to:", address(proxy));
        vm.stopBroadcast();
        
        // 打印代理合约的最终地址
        console.log("NFT Marketplace (V1) is live at proxy address:", address(proxy));
    }
}
