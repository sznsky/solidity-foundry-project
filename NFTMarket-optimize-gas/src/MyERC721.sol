// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import {console} from "forge-std/console.sol"; // 优化3: 移除不必要的forge-std库引入

contract MyERC721 is ERC721URIStorage, Ownable {
    // 优化4：使用 unchecked { ++_nextTokenId; }。
    // 确保 _nextTokenId 不会溢出，uint256 在实际应用中很难溢出，
    // 因此在递增操作中移除溢出检查可以节省Gas。
    uint256 private _nextTokenId;

    constructor() ERC721(unicode"集训营学员卡", "CAMP") Ownable(msg.sender) {
        _nextTokenId = 0; // 优化5: 明确初始化 _nextTokenId 为 0，但此行在Solidity中默认为0，可省略但保留明确性
    }

    // 优化6：将此函数设置为 external。
    function mint(address student, string memory tokenURI) external onlyOwner returns (uint256) { // <--- 优化6: 将 public 改为 external
        // console.log("minted tokenId: ", newItemId); // 优化7: 移除生产环境中不必要的日志输出
        
        // 优化4：使用 unchecked { ++_nextTokenId; }
        // 注意：只有在确定不会溢出的情况下才使用 unchecked，对于 uint256 来说，溢出几乎不可能发生。
        unchecked {
            _nextTokenId++;
        }
        uint256 newItemId = _nextTokenId; // newItemId 已经是递增后的值

        _mint(student, newItemId);
        _setTokenURI(newItemId, tokenURI);
        // 优化8：移除重复的 _nextTokenId++。_nextTokenId 已经在函数开始时递增了一次。
        // _nextTokenId++; // 移除此行
        return newItemId;
    }
}