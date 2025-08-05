// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./NFTMarketplaceV1.sol"; // ✅ 注意这里需要正确引入 V1 合约文件路径
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract NFTMarketplaceV2 is NFTMarketplaceV1 {
    using ECDSA for bytes32;

    // --- V2 新增的状态变量 ---
    bytes32 public constant LIST_TYPEHASH = keccak256("List(address nft,uint256 tokenId,uint256 price)");
    mapping(bytes32 => bool) public usedDigests;
    // --- V2 新增的状态变量结束 ---

    // V1 中已经使用了 1 个 gap（listings）
    // V2 中新增了 1 个变量（usedDigests），我们继续预留 49 个槽位
    uint256[49] private __gap;

    event NFTListed(address indexed nft, uint256 indexed tokenId, address indexed seller, uint256 price);

    /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() {
    //     _disableInitializers();
    // }

    event InitializedV2();
    function initializeV2() public reinitializer(2) {
        // 空函数用于触发 reinitializer(2)
        emit InitializedV2();
    }

    // --- V2 新增的函数 ---
    function listWithSig(
        address nft,
        uint256 tokenId,
        uint256 price,
        bytes calldata signature
    ) external {
        bytes32 structHash = keccak256(abi.encode(
            LIST_TYPEHASH,
            nft,
            tokenId,
            price
        ));
        bytes32 digest = _hashTypedDataV4(structHash);
        require(!usedDigests[digest], "Signature already used");

        address signer = digest.recover(signature);
        require(IERC721(nft).ownerOf(tokenId) == signer, "Not owner");
        require(IERC721(nft).isApprovedForAll(signer, address(this)), "Not approved");
        require(msg.sender != signer, "Sender must not be signer");

        usedDigests[digest] = true;

        IERC721(nft).transferFrom(signer, address(this), tokenId);
        listings[nft][tokenId] = Listing(signer, price);

        emit NFTListed(nft, tokenId, signer, price);
    }

    function hashTypedDataV4Public(bytes32 structHash) external view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }
}
