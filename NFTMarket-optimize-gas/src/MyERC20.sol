// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyERC20 is ERC20, Ownable {
    constructor() ERC20("MyERC20", "MYC") Ownable(msg.sender) {
        // 优化1：移除不必要的初始铸造。在实际应用中，通常通过其他方式（例如，ICO、空投或后续的mint函数）来分发代币，
        // 在构造函数中铸造大量代币会增加部署时的Gas成本。
        // 如果确实需要初始铸造，可以考虑铸造一个较小的初始量。
        // _mint(msg.sender, 100000000 * 10 ** decimals()); // 移除或调整此行以节省部署Gas
    }

    // 优化2：将此函数设置为 external，外部函数通常比 public 函数消耗更少的 Gas。
    // 因为它们的数据不是复制到内存中，而是直接从 calldata 读取。
    function mint(address to, uint256 amount) external onlyOwner { // <--- 优化2: 将 public 改为 external
        _mint(to, amount);
    }
}