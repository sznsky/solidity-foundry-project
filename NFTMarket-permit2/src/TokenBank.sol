// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./MyERC20Permit.sol";

// 导入结构体定义
import {SignatureTransfer} from "permit2/SignatureTransfer.sol";

// 正确导入 permitTransferFrom 接口
import {ISignatureTransfer} from "permit2/interfaces/ISignatureTransfer.sol";

contract TokenBank {
    MyERC20Permit public token;
    mapping(address => uint256) public balances;

    ISignatureTransfer public immutable PERMIT2;

    constructor(address _tokenAddress, address _permit2Address) {
        token = MyERC20Permit(_tokenAddress);
        PERMIT2 = ISignatureTransfer(_permit2Address);
    }

    function depositWithPermit2(
        SignatureTransfer.PermitTransferFrom memory permitTransfer,
        bytes calldata signature
    ) public {
        address owner = PERMIT2.permitTransferFrom(permitTransfer, signature);
        require(permitTransfer.permitted.token == address(token), "Invalid token");
        require(permitTransfer.to == address(this), "Invalid recipient");

        balances[owner] += permitTransfer.amount;
    }

    function deposit(uint256 _amount) public {
        require(_amount > 0, "Amount must be > 0");
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");
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
        token.permit(owner, address(this), amount, deadline, v, r, s);
        bool success = token.transferFrom(owner, address(this), amount);
        require(success, "Transfer failed");
        balances[owner] += amount;
    }

    function withdraw(uint256 _amount) public {
        require(_amount > 0, "Amount must be > 0");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        balances[msg.sender] -= _amount;
        bool success = token.transfer(msg.sender, _amount);
        require(success, "Withdraw failed");
    }

    function getBalance(address _user) public view returns (uint256) {
        return balances[_user];
    }
}
