// src/SUNToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title SUN Token - 自定义 ERC20 代币
contract SUNToken is ERC20 {
    constructor() ERC20("SUN", "SUN") {
        // 铸造 1亿个代币（含18位小数）
        _mint(msg.sender, 100_000_000 * 1e18);
    }
}
