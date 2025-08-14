// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EthCallOptionSeries} from "../src/EthCallOptionSeries.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// 模拟的 USDT 合约，用于测试
contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {}

    // 提供一个 mint 函数方便测试
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract EthCallOptionSeriesTest is Test {
    // ---- 状态变量 ----
    EthCallOptionSeries public optionSeries;
    MockUSDT public mockUSDT;

    address public OWNER;
    address public MINTER;
    address public USER;
    address public TREASURY;

    uint256 public constant STRIKE = 1800e18; // 1800 USDT/ETH
    uint256 public constant UNDERLYING_PER_OPTION = 1e16; // 0.01 ETH / option
    uint256 public constant EXERCISE_WINDOW = 86400; // 1 天
    uint256 public expiry;

    // ---- Setup ----
    function setUp() public {
        OWNER = address(0xBEEF);
        MINTER = address(0xCAFE);
        USER = address(0xDEAD);
        TREASURY = address(0xBEEFBEEF);

        // 设置到期时间为未来
        vm.warp(1000); // 模拟一个开始时间
        expiry = block.timestamp + 1000;

        mockUSDT = new MockUSDT();

        // 部署主合约
        vm.prank(OWNER);
        optionSeries = new EthCallOptionSeries(
            "ETH Call Option",
            "ETHO",
            address(mockUSDT),
            TREASURY,
            STRIKE,
            UNDERLYING_PER_OPTION,
            expiry,
            EXERCISE_WINDOW
        );
    }

    // --- 构造函数测试 ---
    function testConstructor() public view {
        assertEq(optionSeries.name(), "ETH Call Option", "Name should be correct");
        assertEq(optionSeries.symbol(), "ETHO", "Symbol should be correct");
        assertEq(address(optionSeries.quoteToken()), address(mockUSDT), "Quote token should be correct");
        assertEq(optionSeries.treasury(), TREASURY, "Treasury should be correct");
        assertEq(optionSeries.strike(), STRIKE, "Strike should be correct");
        assertEq(optionSeries.underlyingPerOption(), UNDERLYING_PER_OPTION, "Underlying per option should be correct");
        assertEq(optionSeries.expiry(), expiry, "Expiry should be correct");
        assertEq(optionSeries.exerciseWindow(), EXERCISE_WINDOW, "Exercise window should be correct");
        assertEq(optionSeries.owner(), OWNER, "Owner should be correct");
        assertFalse(optionSeries.expired(), "Expired should be false initially");
    }

    // --- depositAndMint 测试 ---
    function testDepositAndMint_Success() public {
        uint256 ethAmount = 1 ether;
        uint256 expectedOptions = ethAmount / UNDERLYING_PER_OPTION;

        vm.prank(OWNER);
        vm.deal(OWNER, ethAmount);

        // 检查事件
        vm.expectEmit(true, true, false, false);
        emit EthCallOptionSeries.Minted(OWNER, MINTER, ethAmount, expectedOptions);
        
        optionSeries.depositAndMint{value: ethAmount}(MINTER); // 👈 修复

        assertEq(optionSeries.balanceOf(MINTER), expectedOptions, "Minter should receive correct options");
        assertEq(address(optionSeries).balance, ethAmount, "Contract should hold the deposited ETH");
    }

    error OwnableUnauthorizedAccount(address owner);

    // 手动声明 ERC20 接口的事件，以便在 emit 中使用
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function testDepositAndMint_RevertsIfNotOwner() public {
        vm.prank(USER);
        vm.deal(USER, 1 ether); 
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, USER));
        optionSeries.depositAndMint{value: 1 ether}(MINTER);
    }

    // --- exercise 测试 ---
    function testExercise_Success() public {
        // 1. 铸造期权
        uint256 ethAmount = 1 ether;
        uint256 optionsAmount = ethAmount / UNDERLYING_PER_OPTION;
        vm.prank(OWNER);
        vm.deal(OWNER, ethAmount);
        optionSeries.depositAndMint{value: ethAmount}(USER);

        // 2. 模拟时间到达行权窗口
        vm.warp(expiry);

        // 3. 计算应付的 USDT
        uint256 usdtToPay = (optionsAmount * UNDERLYING_PER_OPTION * STRIKE) / 1e18;

        // 4. 给用户 mint 足够的 USDT 并 approve
        vm.prank(address(0)); // 切换到任意地址
        mockUSDT.mint(USER, usdtToPay);
        vm.prank(USER);
        mockUSDT.approve(address(optionSeries), usdtToPay);

        // 5. 记录用户和合约的 ETH 余额
        uint256 userEthBalanceBefore = USER.balance;
        uint256 contractEthBalanceBefore = address(optionSeries).balance;

        // 6. 检查事件并执行
        vm.prank(USER);
        vm.expectEmit(true, true, true, false); // ERC20.Transfer event
        emit Transfer(USER, TREASURY, usdtToPay);

        vm.expectEmit(true, true, true, false); // ERC20.Transfer event for burn
        emit Transfer(USER, address(0), optionsAmount);

        vm.expectEmit(true, false, false, false); // Exercised event
        emit EthCallOptionSeries.Exercised(USER, optionsAmount, usdtToPay, ethAmount);

        optionSeries.exercise(optionsAmount);

        // 7. 检查结果
        assertEq(optionSeries.balanceOf(USER), 0, "User's options should be burned");
        assertEq(mockUSDT.balanceOf(TREASURY), usdtToPay, "Treasury should receive USDT");
        assertEq(mockUSDT.balanceOf(USER), 0, "User's USDT should be transferred out");
        assertEq(USER.balance, userEthBalanceBefore + ethAmount, "User should receive ETH");
        assertEq(address(optionSeries).balance, contractEthBalanceBefore - ethAmount, "Contract ETH should be transferred out");
    }

    function testExercise_RevertsIfBeforeExpiry() public {
        // 时间未到，仍在 expiry 之前
        vm.prank(USER);
        vm.expectRevert("Not reached expiry");
        optionSeries.exercise(1);
    }

    function testExercise_RevertsIfAfterWindow() public {
        // 1. 铸造期权
        vm.prank(OWNER);
        vm.deal(OWNER, 1 ether);
        optionSeries.depositAndMint{value: 1 ether}(USER);

        // 2. 模拟时间超过行权窗口
        vm.warp(expiry + EXERCISE_WINDOW + 1);

        // 3. 行权应该失败
        vm.prank(USER);
        vm.expectRevert("Exercise window over");
        optionSeries.exercise(1);
    }

    // --- expireAndSweep 测试 ---
    function testExpireAndSweep_Success() public {
        uint256 ethAmount = 1 ether;
        vm.deal(OWNER, ethAmount);
        vm.prank(OWNER);
        optionSeries.depositAndMint{value: ethAmount}(USER);

        vm.warp(expiry + EXERCISE_WINDOW + 1);
        
        uint256 ownerEthBalanceBefore = OWNER.balance;
        uint256 contractEthBalanceBefore = address(optionSeries).balance;

        vm.expectEmit(true, false, false, false); // Paused
        emit Pausable.Paused(OWNER);

        vm.expectEmit(true, false, false, false); // ExpiredAndSwept
        emit EthCallOptionSeries.ExpiredAndSwept(optionSeries.owner(), contractEthBalanceBefore, block.timestamp);

        vm.prank(OWNER);
        optionSeries.expireAndSweep();

        assertTrue(optionSeries.expired());
        assertTrue(optionSeries.paused());
        assertEq(OWNER.balance, ownerEthBalanceBefore + ethAmount);
        assertEq(address(optionSeries).balance, 0);
    }

    function testExpireAndSweep_RevertsIfBeforeWindow() public {
        // 时间未到，仍在行权窗口内
        vm.warp(expiry + 1);

        vm.prank(OWNER);
        vm.expectRevert("Too early");
        optionSeries.expireAndSweep();
    }

    // --- 安全功能测试 ---
    function test_unpause_revertsIfExpired() public {
        // 1. 先过期
        vm.prank(OWNER);
        vm.deal(OWNER, 1 ether);
        optionSeries.depositAndMint{value: 1 ether}(USER);
        vm.warp(expiry + EXERCISE_WINDOW + 1);
        vm.prank(OWNER);
        optionSeries.expireAndSweep();
        
        // 2. 尝试 unpause，应该失败
        vm.prank(OWNER);
        vm.expectRevert("cannot unpause after expired");
        optionSeries.unpause();
    }
    
    function test_transfer_revertsIfPaused() public {
        // 1. 铸造一些期权
        uint256 ethAmount = 1 ether;
        vm.prank(OWNER);
        vm.deal(OWNER, ethAmount);
        optionSeries.depositAndMint{value: ethAmount}(USER);

        // 2. 暂停合约
        vm.prank(OWNER);
        optionSeries.pause();

        // 3. 尝试转账，应该失败
        vm.prank(USER);
        vm.expectRevert("paused"); // 👈 修复：OpenZeppelin `_update` 回退的自定义错误
        optionSeries.transfer(address(this), 1);
    }
}