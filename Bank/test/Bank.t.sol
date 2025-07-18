// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol"; // 确保你的 Bank.sol 文件在 src 目录下

// 为 Bank 合约编写测试
contract BankTest is Test {
    Bank public bank;
    address public admin;
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public user4 = address(4);

    // 每次测试前执行的设置函数
    function setUp() public {
        // 部署 Bank 合约，部署者即为管理员
        bank = new Bank();
        admin = bank.administrator();
    }

    // 接收以太币的函数，允许合约接收以太币
    receive() external payable {}

    /*
    ==============================
    存款功能测试 (Requirement 1)
    ==============================
    */

    /**
     * @notice 测试用户存款后，其在合约内的余额是否正确更新
     */
    function test_AssertDepositBalanceUpdated() public {
        // 1. 检查初始余额
        assertEq(bank.balance_map(user1), 0, "User initial balance should be 0");

        // 2. user1 存入 1 ether
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        (bool success, ) = address(bank).call{value: 1 ether}("");
        assertTrue(success, "Deposit transaction should succeed");

        // 3. 断言检查存款后余额
        assertEq(bank.balance_map(user1), 1 ether, "Balance after deposit should be 1 ether");
    }

    /*
    ==============================
    排行榜功能测试 (Requirement 2)
    ==============================
    */

    /**
     * @notice 测试只有一个用户存款时，排行榜是否正确
     */
    function test_Top3_WithOneDepositor() public {
        // user1 存入 10 ether
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        (bool success, ) = address(bank).call{value: 10 ether}("");
        assertTrue(success);

        address[3] memory topAddresses = bank.getTop3Address();
        uint[3] memory topBalances = bank.getTop3Balance();

        assertEq(topAddresses[0], user1, "Top 1 address should be user1");
        assertEq(topBalances[0], 10 ether, "Top 1 balance should be 10 ether");
        assertEq(topAddresses[1], address(0), "Top 2 address should be empty");
        assertEq(topBalances[1], 0, "Top 2 balance should be 0");
    }

    /**
     * @notice 测试有两个用户存款时，排行榜是否正确排序
     */
    function test_Top3_WithTwoDepositors() public {
        vm.deal(user1, 5 ether);
        vm.prank(user1);
        (bool success1, ) = address(bank).call{value: 5 ether}("");
        assertTrue(success1);

        vm.deal(user2, 10 ether);
        vm.prank(user2);
        (bool success2, ) = address(bank).call{value: 10 ether}("");
        assertTrue(success2);

        address[3] memory topAddresses = bank.getTop3Address();
        uint[3] memory topBalances = bank.getTop3Balance();

        assertEq(topAddresses[0], user2, "Rank 1 should be user2");
        assertEq(topBalances[0], 10 ether, "Rank 1 balance should be 10 ether");
        assertEq(topAddresses[1], user1, "Rank 2 should be user1");
        assertEq(topBalances[1], 5 ether, "Rank 2 balance should be 5 ether");
    }

    /**
     * @notice 测试有三个用户存款时，排行榜是否正确排序
     */
    function test_Top3_WithThreeDepositors() public {
        vm.deal(user1, 5 ether);
        vm.prank(user1);
        (bool s1, ) = address(bank).call{value: 5 ether}("");
        assertTrue(s1);

        vm.deal(user2, 10 ether);
        vm.prank(user2);
        (bool s2, ) = address(bank).call{value: 10 ether}("");
        assertTrue(s2);

        vm.deal(user3, 2 ether);
        vm.prank(user3);
        (bool s3, ) = address(bank).call{value: 2 ether}("");
        assertTrue(s3);

        address[3] memory addrs = bank.getTop3Address();
        uint[3] memory bals = bank.getTop3Balance();

        assertEq(addrs[0], user2, "Rank 1 should be user2");
        assertEq(bals[0], 10 ether, "Rank 1 balance should be 10 ether");
        assertEq(addrs[1], user1, "Rank 2 should be user1");
        assertEq(bals[1], 5 ether, "Rank 2 balance should be 5 ether");
        assertEq(addrs[2], user3, "Rank 3 should be user3");
        assertEq(bals[2], 2 ether, "Rank 3 balance should be 2 ether");
    }

    /**
     * @notice 测试有四个用户存款时，排行榜是否只保留前三名
     */
    function test_Top3_WithFourDepositors() public {
        vm.deal(user1, 5 ether);
        vm.prank(user1);
        (bool s1, ) = address(bank).call{value: 5 ether}("");
        assertTrue(s1);

        vm.deal(user2, 10 ether);
        vm.prank(user2);
        (bool s2, ) = address(bank).call{value: 10 ether}("");
        assertTrue(s2);

        vm.deal(user3, 2 ether);
        vm.prank(user3);
        (bool s3, ) = address(bank).call{value: 2 ether}("");
        assertTrue(s3);

        vm.deal(user4, 8 ether);
        vm.prank(user4);
        (bool s4, ) = address(bank).call{value: 8 ether}("");
        assertTrue(s4);

        address[3] memory addrs = bank.getTop3Address();
        uint[3] memory bals = bank.getTop3Balance();

        assertEq(addrs[0], user2, "Rank 1 should be user2");
        assertEq(bals[0], 10 ether, "Rank 1 balance should be 10 ether");
        assertEq(addrs[1], user4, "Rank 2 should be user4");
        assertEq(bals[1], 8 ether, "Rank 2 balance should be 8 ether");
        assertEq(addrs[2], user1, "Rank 3 should be user1");
        assertEq(bals[2], 5 ether, "Rank 3 balance should be 5 ether");
    }

    /**
     * @notice 测试同一个用户多次存款，排行榜是否能正确更新
     */
    function test_Top3_SameUserMultipleDeposits() public {
        vm.deal(user1, 3 ether);
        vm.prank(user1);
        (bool s1, ) = address(bank).call{value: 3 ether}("");
        assertTrue(s1);

        vm.deal(user2, 10 ether);
        vm.prank(user2);
        (bool s2, ) = address(bank).call{value: 10 ether}("");
        assertTrue(s2);

        vm.deal(user1, 8 ether); // 3 + 8 = 11 ether
        vm.prank(user1);
        (bool s3, ) = address(bank).call{value: 8 ether}("");
        assertTrue(s3);

        address[3] memory addrs = bank.getTop3Address();
        uint[3] memory bals = bank.getTop3Balance();

        assertEq(addrs[0], user1, "Rank 1 should be updated to user1");
        assertEq(bals[0], 11 ether, "Rank 1 balance should be updated to 11 ether");
        assertEq(addrs[1], user2, "Rank 2 should be updated to user2");
        assertEq(bals[1], 10 ether, "Rank 2 balance should be 10 ether");
    }

    /*
    ==============================
    提款权限测试 (Requirement 3)
    ==============================
    */

    /**
     * @notice 测试管理员可以成功取款
     */
    function test_Withdrawal_ByAdmin_ShouldSucceed() public {
        vm.deal(user1, 5 ether);
        vm.prank(user1);
        (bool s, ) = address(bank).call{value: 5 ether}("");
        assertTrue(s, "Deposit should succeed");

        uint adminBalanceBefore = admin.balance;
        uint contractBalanceBefore = address(bank).balance;

        vm.prank(admin);
        bank.withdraw(2 ether);

        assertEq(address(bank).balance, contractBalanceBefore - 2 ether, "Contract balance should decrease by 2 ether");
        assertEq(admin.balance, adminBalanceBefore + 2 ether, "Admin balance should increase by 2 ether");
    }

    /**
     * @notice 测试非管理员取款会失败回滚
     */
    function test_Withdrawal_ByNonAdmin_ShouldFail() public {
        vm.deal(admin, 5 ether);
        vm.prank(admin);
        (bool s, ) = address(bank).call{value: 5 ether}("");
        assertTrue(s);

        // This is the correct revert string from your Bank contract
        vm.expectRevert("Not an administrator");

        vm.prank(user1);
        bank.withdraw(1 ether);
    }
}