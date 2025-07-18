// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        // Mint 10 billion tokens to the deployer
        // 1e10 * 1e18 x= 10,000,000,000 * 10^18
        _mint(msg.sender, 10000000000 * (10**18));
    }
}