// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MemeToken} from "../src/MemeToken.sol";
import {MemeLauncherFactory} from "../src/MemeLauncherFactory.sol";

contract MemeLauncherTest is Test {
    MemeLauncherFactory public factory;
    MemeToken public memeTokenImplementation; // 实际的 ERC20 逻辑合约
    address public immutable PROJECT_OWNER = makeAddr("projectOwner"); // 项目方地址

    // 测试账户
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public memeIssuer1 = makeAddr("memeIssuer1");
    address public memeIssuer2 = makeAddr("memeIssuer2");

    function setUp() public {
        // 部署 MemeToken 实现合约
        // 注意：这里的参数只是为了让构造函数通过，实际代理不会调用此构造函数
        // 而是直接使用创建的代理合约的初始化函数来设置状态
        // 为了方便，这里直接部署一个临时的 MemeToken 实例作为实现合约
        // 在实际生产环境中，这个实现合约通常是预先部署好的
        vm.startPrank(address(this));
        memeTokenImplementation = new MemeToken();
        vm.stopPrank();

        // 部署工厂合约
        factory = new MemeLauncherFactory(PROJECT_OWNER, address(memeTokenImplementation));

        // 给测试账户充值 ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(memeIssuer1, 10 ether);
        vm.deal(memeIssuer2, 10 ether);
    }

    // 测试部署合约和发行：包含费用分配和供应总量控制
    function testDeployMemeAndMint() public {
        // Meme 发行者 1 部署一个新的 Meme
        vm.startPrank(memeIssuer1);
        string memory symbol1 = "MEME1";
        uint256 totalSupply1 = 100000;
        uint256 perMint1 = 1000;
        uint256 price1 = 0.1 ether; // 每次铸造 0.1 ETH

        //address meme1Addr = factory.deployMeme(symbol1, totalSupply1, perMint1, price1);

        string memory name1 = "My Awesome Meme Coin"; // 新增 name
        address meme1Addr = factory.deployMeme(name1, symbol1, totalSupply1, perMint1, price1);

        vm.stopPrank();

        console2.log("Meme 1 deployed at:", meme1Addr);

        // 检查 MemeToken 实例的属性 (通过代理访问)
        MemeToken meme1 = MemeToken(meme1Addr);
        assertEq(meme1.symbol(), symbol1);
        assertEq(meme1.name(), name1); // 固定名称
        assertEq(meme1.TOTAL_SUPPLY(), totalSupply1);
        assertEq(meme1.PER_MINT_AMOUNT(), perMint1);
        assertEq(meme1.MINT_PRICE(), price1);
        assertEq(meme1.memeIssuer(), memeIssuer1); // 确认发行者地址正确

        // --- 测试铸造逻辑 ---
        uint256 initialProjectOwnerBalance = PROJECT_OWNER.balance;
        uint256 initialMemeIssuer1Balance = memeIssuer1.balance;

        // User1 第一次铸造 Meme1
        vm.startPrank(user1);
        factory.mintMeme{value: price1}(meme1Addr);
        vm.stopPrank();

        // 检查代币余额
        assertEq(meme1.balanceOf(user1), perMint1);
        assertEq(meme1.totalSupply(), perMint1); // 此时总供应量应为 perMint1

        // 检查 ETH 分配 (第一次铸造)
        uint256 expectedProjectShare = (price1 * 1) / 100;
        uint256 expectedIssuerShare = price1 - expectedProjectShare;
        
        // 检查项目方和发行者的余额变化
        assertEq(PROJECT_OWNER.balance, initialProjectOwnerBalance + expectedProjectShare);
        assertEq(memeIssuer1.balance, initialMemeIssuer1Balance + expectedIssuerShare);

        // User2 第二次铸造 Meme1
        vm.startPrank(user2);
        factory.mintMeme{value: price1}(meme1Addr);
        vm.stopPrank();

        // 检查代币余额
        assertEq(meme1.balanceOf(user2), perMint1);
        assertEq(meme1.totalSupply(), perMint1 * 2);

        // 检查 ETH 分配 (第二次铸造，余额继续增加)
        assertEq(PROJECT_OWNER.balance, initialProjectOwnerBalance + (expectedProjectShare * 2));
        assertEq(memeIssuer1.balance, initialMemeIssuer1Balance + (expectedIssuerShare * 2));

        // --- 测试超出总供应量 ---
        uint256 mintsPossible = totalSupply1 / perMint1; // 可以铸造的次数
        uint256 currentMints = 2; // 已经铸造了两次

        // 循环铸造直到接近上限
        vm.startPrank(user1);
        for (uint256 i = currentMints; i < mintsPossible; i++) {
            factory.mintMeme{value: price1}(meme1Addr);
        }
        vm.stopPrank();
        
        assertEq(meme1.totalSupply(), totalSupply1); // 确认已达到总供应量

        // 尝试再次铸造，应失败
        vm.startPrank(user1);
        vm.expectRevert("Minting exceeds total supply");
        factory.mintMeme{value: price1}(meme1Addr);
        vm.stopPrank();

        // --- 测试费用不足 ---
        vm.startPrank(user1);
        vm.expectRevert("Insufficient ETH for minting");
        factory.mintMeme{value: price1 - 1}(meme1Addr); // 支付不足
        vm.stopPrank();

        // --- 测试另一个 Meme 的部署和铸造 ---
        vm.startPrank(memeIssuer2);
        string memory symbol2 = "MOON2";
        uint256 totalSupply2 = 50000;
        uint256 perMint2 = 500;
        uint256 price2 = 0.05 ether;

        //address meme2Addr = factory.deployMeme(symbol2, totalSupply2, perMint2, price2);

        string memory name2 = "Another Awesome Moon Coin"; // 新增 name
        address meme2Addr = factory.deployMeme(name2, symbol2, totalSupply2, perMint2, price2);

        vm.stopPrank();

        console2.log("Meme 2 deployed at:", meme2Addr);
        MemeToken meme2 = MemeToken(meme2Addr);
        assertEq(meme2.symbol(), symbol2);
        assertEq(meme2.name(), name2);
        assertEq(meme2.TOTAL_SUPPLY(), totalSupply2);
        assertEq(meme2.PER_MINT_AMOUNT(), perMint2);
        assertEq(meme2.MINT_PRICE(), price2);
        assertEq(meme2.memeIssuer(), memeIssuer2);

        // User1 铸造 Meme2
        vm.startPrank(user1);
        factory.mintMeme{value: price2}(meme2Addr);
        vm.stopPrank();

        assertEq(meme2.balanceOf(user1), perMint2);
        assertEq(meme2.totalSupply(), perMint2);
    }
}