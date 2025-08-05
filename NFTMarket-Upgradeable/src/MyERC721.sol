// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

//可升级的ERC721合约

contract MyERC721 is Initializable, ERC721Upgradeable, OwnableUpgradeable, UUPSUpgradeable{
    uint256 public tokenIdCounter;

    function initialize() public initializer {
        __ERC721_init("MyNFT", "MNFT");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function safeMint(address to) external onlyOwner {
        _safeMint(to, tokenIdCounter);
        tokenIdCounter++;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}