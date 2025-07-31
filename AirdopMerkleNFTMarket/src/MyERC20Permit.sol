// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";


contract MyERC20Permit is ERC20Permit{
    constructor() ERC20Permit("MyERC20Permit Token"){}

    function mint(address to, uint256 amount) public{
        _mint(to, amount);
    }

}