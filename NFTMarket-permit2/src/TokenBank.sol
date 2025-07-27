// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyERC20Permit.sol";
// 导入 Permit2 相关的接口
import {IPermit2} from "@uniswap/permit2/contracts/interfaces/IPermit2.sol";
import {SignatureTransfer} from "@uniswap/permit2/contracts/libraries/SignatureTransfer.sol";

contract TokenBank {
    MyERC20Permit public token;
    mapping(address => uint256) public balances;

    // Permit2 合约的地址
    IPermit2 public immutable PERMIT2_ADDRESS;

    constructor(address _tokenAddress, address _permit2Address) {
        require(_tokenAddress != address(0), "Token address cannot be zero");
        require(_permit2Address != address(0), "Permit2 address cannot be zero");
        token = MyERC20Permit(_tokenAddress);
        PERMIT2_ADDRESS = IPermit2(_permit2Address);
    }

    function deposit(uint _amount) public {
        require(_amount > 0, "Deposit amount must be greater than zero");
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "Token transfer failed (check allowance)");
        balances[msg.sender] += _amount;
    }

    function permitDeposit(
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(amount > 0, "Deposit amount must be greater than zero");
        token.permit(owner, address(this), amount, deadline, v, r, s);
        bool success = token.transferFrom(owner, address(this), amount);
        require(success, "Token transfer failed");
        balances[owner] += amount;
    }

    /// @notice [新增] 使用 Permit2 进行签名授权存款
    /// @param permit Permit2 签名的数据结构
    /// @param transferDetails 包含转账金额、接收方等细节
    /// @param signature 用户的 Permit2 签名
    function depositWithPermit2(
        SignatureTransfer.PermitSingle memory permit,
        SignatureTransfer.TransferSingleParams memory transferDetails,
        bytes memory signature
    ) public {
        // Permit2 会验证签名并执行 transferFrom
        // owner 地址是 permit.details.token 地址的原始所有者
        address owner = PERMIT2_ADDRESS.permitTransferFrom(
            permit,
            transferDetails,
            signature
        );

        // Permit2 已经将 token 从 owner 转账到了 transferDetails.to (即本合约)
        // 所以我们只需要更新 balances
        // 确保转账的 token 是我们期望的 token
        require(transferDetails.details.token == address(token), "Invalid token for deposit");
        // 确保接收方是本合约
        require(transferDetails.to == address(this), "Invalid recipient for deposit");

        balances[owner] += transferDetails.details.amount;
    }


    function withdraw(uint256 _amount) public payable {
        require(_amount > 0, "Withdraw amount must be greater than zero !");
        require(balances[msg.sender] >= _amount, "Insufficient balance in bank");
        balances[msg.sender] -= _amount;
        bool success = token.transfer(msg.sender, _amount);
        require(success, "Token transfer failed");
    }

    function getBalance(address _user) public view returns (uint256) {
        return balances[_user];
    }
}