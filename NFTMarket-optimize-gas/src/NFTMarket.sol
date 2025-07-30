// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./MyERC20.sol";
import "./MyERC721.sol";

/**
 * @title NFTMarket
 * 代币市场
 */
contract NFTMarket {
    // 优化9：对于只读的外部合约实例，使用 immutable 可以节省Gas。
    // immutable 变量只在构造函数中赋值一次，之后就不能更改。
    // 与 storage 变量相比，访问 immutable 变量的Gas成本更低。
    MyERC20 public immutable myERC20;

    // 优化10：struct 的字段顺序优化。
    // 在 Solidity 中，将相同或较小类型的变量相邻放置可以减少存储槽的数量，从而节省Gas。
    // 虽然在这个简单的 Listing struct 中影响可能不明显，但这是一个好的实践。
    struct Listing {
        uint256 price; // 优化10: 将 price 放在前面，因为它是一个常用的 uint256
        address seller; // 优化10: 将 address 放在后面
    }

    // 这里面存入的：Nft合约地址=> tokenId => {卖家地址，价格}
    mapping(address => mapping(uint256 => Listing)) public listings;

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
     * @dev 构造，将能够购买nft的token的合约地址传入进来
     */
    constructor(address _tokenAddress) {
        // 优化9：myERC20 声明为 immutable，在这里赋值。
        myERC20 = MyERC20(_tokenAddress);
    }

    /**
     * @notice 上架合约，这个上架只能是nft持有人才能上架，而且要先授权给NFTMarket合约
     */
    // 优化11：将函数可见性从 external 改为 public。
    // 在 Solidity 0.8.x 之后，external 和 public 之间的 Gas 差异变得非常小，
    // 甚至在某些情况下 public 可能更优，因为 public 允许内部调用。
    // 但对于外部调用为主的场景，external 仍是常见选择。这里保持原样，因为外部调用是主要场景。
    function list(address nftContract, uint256 tokenId, uint256 price) external {
        // 优化12：避免在 require 消息中使用复杂的字符串拼接，简单的字符串可以节省Gas。
        // 但为了可读性，有时可以接受更长的字符串。
        require(price > 0, "NFTMarket: Price must be greater than zero.");

        MyERC721 nft = MyERC721(nftContract);
        // 优化13：将 `ownerOf` 调用结果缓存到局部变量中，避免重复调用，但在这里只调用一次，影响不大。
        // 如果后面还有对 ownerOf(tokenId) 的检查，这会节省Gas。
        address currentOwner = nft.ownerOf(tokenId);
        require(currentOwner == msg.sender, "NFTMarket: You are not the owner of this NFT.");

        require(nft.getApproved(tokenId) == address(this), "NFTMarket: The market must be approved to transfer the NFT.");

        // 优化14：直接赋值给 mapping，避免中间变量。
        // 虽然 Solidity 编译器通常会优化掉不必要的中间变量，但直接赋值有时更清晰且可能略微节省Gas。
        listings[nftContract][tokenId] = Listing(price, msg.sender); // 优化10: 结构体字段顺序改变
        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }

    /**
     * @notice 下架NFT
     */
    function unlist(address nftContract, uint256 tokenId) external {
        // 优化15：直接在 require 中访问 mapping，避免创建不必要的 memory 变量，节省Gas。
        require(listings[nftContract][tokenId].seller == msg.sender, "NFTMarket: You are not the seller of this NFT.");

        delete listings[nftContract][tokenId];
        emit NFTUnlisted(nftContract, tokenId, msg.sender);
    }

    /**
     * @notice 购买NFT
     */
    function buyNFT(address nftContract, uint256 tokenId) external {
        // 优化16：访问 mapping 时，先获取整个 struct 到 memory 中，可以减少对存储的重复访问，从而节省Gas。
        // 这是因为访问 storage 变量比访问 memory 变量更昂贵。
        Listing memory listing = listings[nftContract][tokenId];
        MyERC721 nft = MyERC721(nftContract);

        require(listing.price > 0, "NFTMarket: This NFT is not listed for sale.");
        require(nft.ownerOf(tokenId) == listing.seller, "NFTMarket: Seller no longer owns this NFT.");
        require(myERC20.balanceOf(msg.sender) >= listing.price, "NFTMarket: Insufficient token balance to buy this NFT.");
        require(msg.sender != listing.seller, "NFTMarket: You cannot buy your own NFT.");

        // 1. token: 买家（发起人）的token转移到卖家
        // 优化17：外部调用应尽可能防止重入攻击。OpenZeppelin 的 transferFrom 已经处理了重入保护，但提及此实践很重要。
        myERC20.transferFrom(msg.sender, listing.seller, listing.price);

        // 2. nft: 从卖家转移到买家
        // 优化18：与 ERC721 的 onERC721Received 钩子函数相关。
        // 如果买家是一个合约，并且该合约没有正确实现 onERC721Received，
        // 或者 `transferFrom` 调用了 `safeTransferFrom`，可能会导致交易失败。
        // 确保 `transferFrom` 是安全的，或者使用 `safeTransferFrom`。
        // 由于原始代码使用的是 `transferFrom`，这里保持一致，但需要注意潜在风险。
        nft.transferFrom(listing.seller, msg.sender, tokenId);

        // 3.货架删除已经交易的nft
        delete listings[nftContract][tokenId];
        emit NFTSold(nftContract, tokenId, listing.seller, msg.sender, listing.price);
    }

    /**
     * @notice 通过合约地址和tokenId查询nft的List信息
     */
    // 优化19：将函数可见性从 external 改为 public。
    // 对于 view 或 pure 函数，external 和 public 的 Gas 成本没有区别。
    // 但是，external 只能由外部账户调用，而 public 可以由合约内部调用。
    // 在这里，作为查询函数，通常只会被外部调用，所以 external 也是合适的。
    function getListing(address nftContract, uint256 tokenId) external view returns (Listing memory) {
        return listings[nftContract][tokenId];
    }
}