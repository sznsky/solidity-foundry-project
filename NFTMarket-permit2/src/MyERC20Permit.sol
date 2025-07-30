// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MyERC20Permit is  ERC20Permit {

    // 铸造1亿个token
    constructor() ERC20("SUN", "SUN") ERC20Permit("SUN") {
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }
}