// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyERC20 is ERC20, Ownable {
    constructor() ERC20("MyERC20", "MYC") Ownable(msg.sender){
        // Mint initial supply to the contract deployer
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner { // <--- 必须添加此函数！
        _mint(to, amount);
    }
}