// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyERC721 is ERC721URIStorage,Ownable  {
    uint256 private _nextTokenId;

    constructor() ERC721(unicode"集训营学员卡", "CAMP") Ownable(msg.sender){
        _nextTokenId = 0;
    }

    function mint(address student, string memory tokenURI) public onlyOwner returns (uint256)  {
        _nextTokenId++;
        uint256 newItemId = _nextTokenId;
        _mint(student, newItemId);
        _setTokenURI(newItemId, tokenURI);
        _nextTokenId++; // 为下一次铸造操作递增
        return newItemId;
    }
}