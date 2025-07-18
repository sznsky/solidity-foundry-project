// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol"; // 导入 Foundry 的测试库
import "../src/Counter.sol"; // 导入你要测试的 Counter 合约（假设它在 src/ 目录下）

contract CounterTest is Test {
    Counter public counter; // 声明 Counter 合约的一个实例

    /// @dev setUp 函数在每个测试函数运行前执行，用于初始化测试环境。
    function setUp() public {
        // 部署 Counter 合约的新实例
        counter = new Counter();
    }

    /// @dev test_SetNumber 测试 setNumber 函数是否能正确设置数字。
    function test_SetNumber() public {
        uint256 expectedNumber = 123;
        counter.setNumber(expectedNumber); // 调用 setNumber 函数

        // 使用 assertEq 断言来检查 number 变量是否被正确设置
        assertEq(counter.number(), expectedNumber, "Number should be set correctly");
    }

    /// @dev test_Increment 测试 increment 函数是否能正确增加数字。
    function test_Increment() public {
        // 首先设置一个初始值
        uint256 initialNumber = 5;
        counter.setNumber(initialNumber);

        counter.increment(); // 调用 increment 函数

        // 断言 number 是否增加了一
        assertEq(counter.number(), initialNumber + 1, "Number should be incremented by 1");
    }

    /// @dev test_InitialNumberIsZero 测试合约部署后 number 的初始值是否为零。
    function test_InitialNumberIsZero() public {
        // 在 setUp 中合约已经部署，直接检查其初始值
        assertEq(counter.number(), 0, "Initial number should be zero");
    }

    /// @dev testFuzz_SetNumberWithRandomInput 这是一个模糊测试示例，用随机输入测试 setNumber。
    /// @param _newNumber 一个随机生成的 uint256 值。
    function testFuzz_SetNumberWithRandomInput(uint256 _newNumber) public {
        // 可以选择性地添加vm.assume来限制随机数的范围，例如：
        // vm.assume(_newNumber <= 1000); // 假设你只想测试0到1000之间的数字

        counter.setNumber(_newNumber);
        assertEq(counter.number(), _newNumber, "Fuzz: Number should be set correctly with random input");
    }
}