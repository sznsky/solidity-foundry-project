// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// 同时继承 ERC20 和 ERC20Permit
contract MyERC20Permit is ERC20, ERC20Permit {

    // 分别调用两个基类的构造函数，并传入正确的参数
    constructor() ERC20("MyERC20Permit", "MYP") ERC20Permit("MyERC20Permit") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
    
    // 用于测试目的的公共函数，以获取 permit 签名摘要
    function getPermitDigest(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) public view returns (bytes32) {
        bytes32 PERMIT_TYPEHASH = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        return _hashTypedDataV4(
            keccak256(abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonces(owner),
                deadline
            ))
        );
    }
}
