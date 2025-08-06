// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

contract Bank is AutomationCompatibleInterface {

    // 所有者
    address public owner;
    // 目标地址
    address payable public vault;
    // 金额
    uint256 public threshold = 0.01 ether;
    // 存款记录
    mapping(address => uint256) public balances;


    // 构造方法
    constructor(address payable _vault){
        owner = msg.sender;
        vault = _vault;
    }

    // 存款函数
    function deposit() external payable{
        // 这行代码只是记录，真正的存款ETH是payable
        balances[msg.sender] += msg.value;
    }


    // 判断是否要被执行
    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory performData){
        upkeepNeeded = address(this).balance >= threshold;
        performData = "";// 无需额外数据
    }

    // 被chainlink调用
    function performUpkeep(bytes calldata /* performData */) external override {
        require(address(this).balance >= threshold, "Not enough balance");

        uint256 amount = address(this).balance;
        (bool success, ) = vault.call{value:amount}("");
        require(success, "Transfer failed");
    }
}