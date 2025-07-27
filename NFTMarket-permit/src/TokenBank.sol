// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyERC20Permit.sol";

contract TokenBank{
    // 这个tokenBank只能存入BaseERC20
    MyERC20Permit public token;
    // 记录每个地址的token数量
    mapping (address => uint256) public balances;

    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Token address cannot be zero");
        token = MyERC20Permit(_tokenAddress);
    }

    // 存款 废弃
    function deposit(uint _amount) public {
        require(_amount > 0, "Deposit amount must be greater than zero");
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "Token transfer failed (check allowance)");
        balances[msg.sender] += _amount;
    }

    // 存款perimit
    /**
     * @notice [新增] 使用离线签名授权存款
     * @param owner 授权代币的原始拥有者地址
     * @param amount 存款数量
     * @param deadline 签名的有效期时间戳
     * @param v, r, s 签名的三个部分
     */
    function permitDeposit(
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(amount > 0, "Deposit amount must be greater than zero");

        // 1. 调用 token 合约的 permit 函数，使用签名来授权 TokenBank 合约 (address(this))
        // 这会授权本合约从 owner 地址转移 amount 数量的代币
        token.permit(owner, address(this), amount, deadline, v, r, s);

        // 2. 授权成功后，直接从 owner 地址转账到本合约
        bool success = token.transferFrom(owner, address(this), amount);
        require(success, "Token transfer failed");

        // 3. 更新 owner 在银行的存款余额
        balances[owner] += amount;
    }

    /**
     * 从银行取出token
     */
    function withdraw(uint256 _amount) public payable {
        require(_amount > 0, "Withdraw amount must be greater than zero !");
        require(balances[msg.sender] >= _amount, "Insufficient balance in bank");
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