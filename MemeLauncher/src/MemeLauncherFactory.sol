// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/proxy/Clones.sol";
import {MemeToken} from "./MemeToken.sol";

contract MemeLauncherFactory {
    using Clones for address;

    address public immutable PROJECT_OWNER;
    address public immutable memeTokenImplementation;

    event MemeDeployed(address indexed tokenAddr, address indexed memeIssuer, string symbol);

    constructor(address _projectOwner, address _memeTokenImplementation) {
        require(_projectOwner != address(0), "Invalid project owner address");
        require(_memeTokenImplementation != address(0), "Invalid MemeToken implementation address");
        PROJECT_OWNER = _projectOwner;
        memeTokenImplementation = _memeTokenImplementation;
    }

    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address tokenAddr) {
        bytes32 salt = keccak256(abi.encodePacked(symbol, msg.sender, block.timestamp));
        tokenAddr = memeTokenImplementation.cloneDeterministic(salt); // clone 代理

        MemeToken(tokenAddr).initialize(totalSupply, perMint, price, msg.sender);

        emit MemeDeployed(tokenAddr, msg.sender, symbol);
    }

    function mintMeme(address tokenAddr) external payable {
        //MemeToken(tokenAddr).mint(PROJECT_OWNER);
        //MemeToken(tokenAddr).mint{value:msg.value}(PROJECT_OWNER);
        MemeToken(tokenAddr).mint{value: msg.value}(PROJECT_OWNER, msg.sender);
    }
}
