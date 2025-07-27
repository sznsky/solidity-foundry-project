// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// 导入新的 MessageHashUtils 库
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./MyERC20.sol";
import "./MyERC721.sol";

/**
 * @title NFTMarket
 * 代币市场
 */
contract NFTMarket {
    // 移除 using ECDSA for bytes32; 因为 ECDSA 库现在只用于 recover，不需要 bytes32 的扩展
    // 如果你在其他地方需要使用 bytes32 的 recover 方法，可以保留 using ECDSA for bytes32;
    // 但对于 MessageHashUtils，如果你想用作 bytes32 的扩展，你需要： using MessageHashUtils for bytes32;
    // 但在 permitBuy 函数中，我们直接调用静态方法，所以不需要 using。

    // 只能使用MyERC20交易
    MyERC20 public immutable myERC20;

    // 项目方地址，用于签名白名单
    address public immutable signerAddress;

    // 上架List
    struct Listing {
        address seller;
        uint256 price;
    }


    // 这里面存入的：Nft合约地址=> tokenId => {卖家地址，价格}
    mapping(address => mapping(uint256 => Listing)) public listings;

    // 存储已经使用过的签名，防止重放攻击
    mapping(address => mapping(bytes32 => bool)) public usedSignatures;

    // Events
    event NFTListed(
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 price
    );

    event NFTSold(
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address indexed buyer,
        uint256 price
    );
    event NFTUnlisted(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller
    );

    /**
     * @dev 构造函数，传入能够购买nft的token的合约地址和签名者地址
     */
    constructor(address _tokenAddress, address _signerAddress) {
        myERC20 = MyERC20(_tokenAddress);
        signerAddress = _signerAddress;
    }

    /**
     * @notice 上架合约，这个上架只能是nft持有人才能上架，而且要先授权给NFTMarket合约
     */
    function list(address nftContract, uint256 tokenId, uint256 price) external {
        MyERC721 nft = MyERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "NFTMarket: You are not the owner of this NFT.");
        require(price > 0, "NFTMarket: Price must be greater than zero.");
        // 检查要上架的nft是否授权给NFTMarket
        require(nft.getApproved(tokenId) == address(this), "NFTMarket: The market must be approved to transfer the NFT.");

        listings[nftContract][tokenId] = Listing(msg.sender, price);
        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }
    /**
     * @notice 下架NFT
     */
    function unlist(address nftContract, uint256 tokenId) external {
        Listing storage listing = listings[nftContract][tokenId];
        require(listing.seller == msg.sender, "NFTMarket: You are not the seller of this NFT.");
        
        delete listings[nftContract][tokenId];
        emit NFTUnlisted(nftContract, tokenId, msg.sender);
    }

    /**
     * @notice 购买NFT
     */
    function buyNFT(address nftContract, uint256 tokenId) external {
        Listing memory listing = listings[nftContract][tokenId];
        MyERC721 nft = MyERC721(nftContract);

        require(listing.price > 0, "NFTMarket: This NFT is not listed for sale.");
        require(nft.ownerOf(tokenId) == listing.seller, "NFTMarket: Seller no longer owns this NFT.");
        // 检查买家是否有足够的token余额
        require(myERC20.balanceOf(msg.sender) >= listing.price, "NFTMarket: Insufficient token balance to buy this NFT.");

        // 防止买家是卖家
        require(msg.sender != listing.seller, "NFTMarket: You cannot buy your own NFT.");

        // 1. token:买家（发起人）的token转移到卖家
        myERC20.transferFrom(msg.sender, listing.seller, listing.price);

        // 2. nft:从卖家转移到买家
        nft.transferFrom(listing.seller, msg.sender, tokenId);

        // 3.货架删除已经交易的nft
        delete listings[nftContract][tokenId];
        emit NFTSold(nftContract, tokenId, listing.seller, msg.sender, listing.price);
    }
    
    /**
     * @notice 允许白名单用户通过离线签名购买NFT。
     * @param nftContract NFT合约地址。
     * @param tokenId NFT的ID。
     * @param signature 项目方对 msg.sender 地址的签名。
     */
    function permitBuy(
        address nftContract,
        uint256 tokenId,
        bytes memory signature
    ) external {
        // 构造要验证的哈希消息：包含 msg.sender 地址
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender));
        
        // 使用 MessageHashUtils 库来生成以太坊签名的消息哈希
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // 恢复签名者地址，这里继续使用 ECDSA 库的 recover 方法
        address recoveredSigner = ECDSA.recover(ethSignedMessageHash, signature);

        // 验证签名是否来自授权的项目方地址
        require(recoveredSigner == signerAddress, "NFTMarket: Invalid signature or not whitelisted.");
        
        // 防止重放攻击：检查签名是否已经被使用过
        require(!usedSignatures[msg.sender][ethSignedMessageHash], "NFTMarket: Signature already used.");
        usedSignatures[msg.sender][ethSignedMessageHash] = true; // 标记签名已使用

        // 执行购买逻辑，与 buyNFT 相同
        Listing memory listing = listings[nftContract][tokenId];
        MyERC721 nft = MyERC721(nftContract);

        require(listing.price > 0, "NFTMarket: This NFT is not listed for sale.");
        require(nft.ownerOf(tokenId) == listing.seller, "NFTMarket: Seller no longer owns this NFT.");
        require(myERC20.balanceOf(msg.sender) >= listing.price, "NFTMarket: Insufficient token balance to buy this NFT.");
        require(msg.sender != listing.seller, "NFTMarket: You cannot buy your own NFT.");

        myERC20.transferFrom(msg.sender, listing.seller, listing.price);
        nft.transferFrom(listing.seller, msg.sender, tokenId);
        
        delete listings[nftContract][tokenId];
        emit NFTSold(nftContract, tokenId, listing.seller, msg.sender, listing.price);
    }
    
    /**
     * @notice 通过合约地址和tokenId查询nft的List信息
     */
    function getListing(address nftContract, uint256 tokenId) external view returns (Listing memory) {
        return listings[nftContract][tokenId];
    }
}