// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MultiVesting.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";

// 简单的 ERC20 模拟代币
contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract MultiVestingTest is Test {
    MultiVesting public vesting;
    MockERC20 public token;
    address public owner;
    address public user1;

    uint256 public constant TOTAL_VEST = 240_000 ether;
    uint256 public constant CLIFF = 356 days;
    uint256 public constant VESTING = 730 days;

    uint256 public startTime;

    function setUp() public {
        owner = address(this);
        user1 = vm.addr(1); // 生成一个地址
        token = new MockERC20();
        vesting = new MultiVesting(address(token), owner);

        // owner 批准 vesting 合约转账
        token.approve(address(vesting), 1_000_000 ether);
        vesting.deposit(1_000_000 ether);

        // 设置当前时间为部署时间
        startTime = block.timestamp;

        // 添加 user1 的锁仓计划
        vesting.addVesting(user1, TOTAL_VEST, startTime);
    }

    function testNoReleaseBeforeCliff() public {
        // warp 到 cliff 前
        vm.warp(startTime + 200 days);

        // 尝试领取
        vm.prank(user1);
        vm.expectRevert("No tokens to release");
        vesting.relase();
    }

    function testLinearReleaseAfterCliff() public {
        // warp 到第 13 个月（刚好 cliff + 1个月）
        vm.warp(startTime + CLIFF + 30 days);

        uint256 expected = TOTAL_VEST / 24;

        uint256 before = token.balanceOf(user1);

        vm.prank(user1);
        vesting.relase();

        uint256 afterBal = token.balanceOf(user1);
        assertEq(afterBal - before, expected, "First month release incorrect");
    }

    function testPartialAndFullRelease() public {
        // warp 到 cliff + 6个月
        vm.warp(startTime + CLIFF + 30 days * 6);

        uint256 expected = TOTAL_VEST * 6 / 24;

        vm.prank(user1);
        vesting.relase();

        assertEq(token.balanceOf(user1), expected);

        // warp 到 cliff + 24个月
        vm.warp(startTime + CLIFF + VESTING);

        // 剩下的全释放
        vm.prank(user1);
        vesting.relase();

        assertEq(token.balanceOf(user1), TOTAL_VEST);
    }

    function testMultipleReleases() public {
        // month 1
        vm.warp(startTime + CLIFF + 30 days);
        vm.prank(user1);
        vesting.relase();

        uint256 month1 = TOTAL_VEST / 24;
        assertEq(token.balanceOf(user1), month1);

        // month 2
        vm.warp(startTime + CLIFF + 60 days);
        vm.prank(user1);
        vesting.relase();

        uint256 month2 = TOTAL_VEST * 2 / 24;
        assertEq(token.balanceOf(user1), month2);
    }
}
