// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AirdopMerkleNFTMarket is Multicall, ReentrancyGuard {

    error NotNFTOwner();
    error PriceMustBeGreaterThanZero();
    error NotListed();
    error InvalidMerkleProof();
    error NotTheSeller();

    IERC20Permit public immutable token;
    IERC721 public immutable nft;
    bytes32 public immutable merkleRoot;

    struct Listing {
        uint256 price;
        address seller;
    }

    mapping(uint256 => Listing) public listings;

    event Listed(uint256 indexed tokenId, uint256 price, address indexed seller);
    event Sold(uint256 indexed tokenId, uint256 price, address indexed seller, address indexed buyer);
    event Delisted(uint256 indexed tokenId);

    constructor(address tokenAddress, address nftAddress, bytes32 _merkleRoot) {
        token = IERC20Permit(tokenAddress);
        nft = IERC721(nftAddress);
        merkleRoot = _merkleRoot;
    }

    // 上架
    function list(uint256 tokenId, uint256 price) external {
        if (nft.ownerOf(tokenId) != msg.sender) revert NotNFTOwner();
        if (price == 0) revert PriceMustBeGreaterThanZero();

        nft.approve(address(this), tokenId);
        listings[tokenId] = Listing(price, msg.sender);
        emit Listed(tokenId, price, msg.sender);
    }

    // 授权：permit授权给NFTMarket
    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        token.permit(owner, spender, value, deadline, v, r, s);
    }

    // 1.默克尔树验证白名单 2.转出NFT,转入token
    function claimNFT(uint256 tokenId, bytes32[] calldata merkleProof) external nonReentrant {
        Listing memory listing = listings[tokenId];
        if (listing.price == 0) revert NotListed();

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
            revert InvalidMerkleProof();
        }

        // 半价购买
        uint256 discountedPrice = listing.price / 2;
         // 删除已经交易的NFT
        delete listings[tokenId];

        // TOKEN从买家转入卖家
        token.transferFrom(msg.sender, listing.seller, discountedPrice);
        // NFT从市场合约转入买家
        nft.transferFrom(address(this), msg.sender, tokenId);

        emit Sold(tokenId, discountedPrice, listing.seller, msg.sender);
    }

    








}