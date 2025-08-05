// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import {MyERC721} from "../src/MyERC721.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployMyERC721 is Script {
    function run() external {
        // 设置部署私钥（从 .env 中读取或直接传入）
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        // 部署逻辑合约
        MyERC721 implementation = new MyERC721();

        // 构造初始化数据（call `initialize()`）
        bytes memory initData = abi.encodeWithSignature("initialize()");

        // 部署代理合约，并指向逻辑合约
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        // 打印部署结果
        console2.log("MyERC721 Logic Contract:", address(implementation));
        console2.log("MyERC721 Proxy (User-facing):", address(proxy));

        vm.stopBroadcast();
    }
}
