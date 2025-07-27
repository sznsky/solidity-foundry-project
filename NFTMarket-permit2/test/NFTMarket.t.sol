// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/Test.sol";
import {Test, console2} from "forge-std/Test.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {MyERC20} from "../src/MyERC20.sol";
import {MyERC721} from "../src/MyERC721.sol";

contract NFTMarketTest is Test {
    NFTMarket public nftMarket;
    MyERC20 public myERC20;
    MyERC721 public myERC721;

    address public deployer;
    address public alice; // 买家
    address public bob;   // 卖家
    address public signer; // 项目方签名者

    function setUp() public {
        deployer = makeAddr("deployer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        signer = makeAddr("signer"); // 为签名者创建一个地址

        // 模拟部署 MyERC20
        vm.startPrank(deployer);
        myERC20 = new MyERC20();
        vm.stopPrank();

        // 模拟部署 MyERC721
        vm.startPrank(deployer);
        myERC721 = new MyERC721();
        vm.stopPrank();

        // 部署 NFTMarket 合约，并传入 MyERC20 地址和 signer 地址作为参数
        // !!在这里添加 signer 参数!!
        vm.startPrank(deployer);
        nftMarket = new NFTMarket(address(myERC20), signer); // 传入两个参数
        vm.stopPrank();

        // 可以在这里给 Alice 和 Bob 一些 ERC20 代币用于测试
        vm.startPrank(deployer);
        myERC20.mint(alice, 1000 * 10**myERC20.decimals());
        myERC20.mint(bob, 500 * 10**myERC20.decimals());
        vm.stopPrank();
    }

    // ... (其他测试函数)
}