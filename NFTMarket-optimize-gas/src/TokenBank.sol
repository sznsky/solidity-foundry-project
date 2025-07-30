// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyERC20.sol";

contract TokenBank{
    // 这个tokenBank只能存入BaseERC20
    MyERC20 public token;
    // 记录每个地址的token数量
    mapping (address => uint256) public balances;

    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Token address cannot be zero");
        token = MyERC20(_tokenAddress);
    }

    // 存入token
    function deposit(uint _amount) public {
        require(_amount > 0, "Deposit amount must be greater than zero");
        bool suncess = token.transferFrom(msg.sender, address(this), _amount);
        require(suncess, "Token transfer failed (check allowance)");
        balances[msg.sender] += _amount;
    }

    /**
     * 从银行取出token
     */
    function withdraw(uint256 _amount) public payable {
        require(_amount > 0, "Withdraw amount must be greater than zero !");
        require(balances[msg.sender] > _amount, "Insufficient balance in bank");
        // 更新用户存款余额
        balances[msg.sender] -= _amount;
        // 将token 从本合约转回调用者地址
        bool success = token.transfer(msg.sender, _amount);
        require(success, "Token transfer failed");
    }

    /**
     * 查询银行存款余额（自测使用）
     * @param _user address 用户地址
    */ 
    function getBalance(address _user) public view returns (uint256){
        return balances[_user];
    }
}