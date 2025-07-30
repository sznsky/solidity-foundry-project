// src/TokenBank.sol
// SPDX-License-Identifier: MIT


pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";

contract TokenBank {
    address public immutable PERMIT2;
    
    mapping(address => mapping(address => uint256)) public balances;

    event Deposit(address indexed user, address indexed token, uint256 amount);

    constructor(address _permit2) {
        require(_permit2 != address(0), "Invalid Permit2 address");
        PERMIT2 = _permit2;
    }

    function depositWithPermit2(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        address owner, // <-- 新增的参数，表示 Permit 的签名者/所有者
        bytes calldata signature
    ) external {
        // 确保转账目标是本合约
        require(transferDetails.to == address(this), "Invalid recipient");

        //address owner = msg.sender;
        
        // 执行 Permit2 转账，owner 使用 permit.owner (签名者)
        ISignatureTransfer(PERMIT2).permitTransferFrom(
            permit,
            transferDetails,
            owner, // 使用 permit.owner 作为代币所有者
            signature
        );

        // 更新余额，同样使用 permit.owner
        balances[permit.permitted.token][owner] += transferDetails.requestedAmount;
        emit Deposit(owner, permit.permitted.token, transferDetails.requestedAmount);
    }
    
    function getBalance(address _token, address _user) public view returns (uint256) {
        return balances[_token][_user];
    }
}