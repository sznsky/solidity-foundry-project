// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// 确保所有导入的父合约都在这里，且顺序必须与V2的完全一致
contract NFTMarketplaceV1 is Initializable, OwnableUpgradeable, EIP712Upgradeable, UUPSUpgradeable {
    struct Listing {
        address seller;
        uint256 price;
    }

    // --- 自定义状态变量 ---
    // 它们将紧跟在所有父合约的变量之后
    mapping(address => mapping(uint256 => Listing)) public listings;
    // --- 自定义状态变量结束 ---

    // 为未来的升级预留足够的存储空间。
    // 这也是 OpenZeppelin UUPS 模式的标准做法。
    // 我们将这个数组放在所有自定义变量之后。
    uint256[50] private __gap;

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __EIP712_init("NFTMarketplace", "1");
    }

    function listNFT(address nft, uint256 tokenId, uint256 price) external {
        IERC721(nft).transferFrom(msg.sender, address(this), tokenId);
        listings[nft][tokenId] = Listing(msg.sender, price);
    }

    function buyNFT(address nft, uint256 tokenId) external payable {
        Listing memory l = listings[nft][tokenId];
        require(msg.value == l.price, "Wrong price");
        delete listings[nft][tokenId];
        payable(l.seller).transfer(msg.value);
        IERC721(nft).transferFrom(address(this), msg.sender, tokenId);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}