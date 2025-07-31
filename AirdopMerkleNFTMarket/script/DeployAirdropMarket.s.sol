// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {MyERC20Permit} from "../src/MyERC20Permit.sol";
import {MyERC721} from "../src/MyERC721.sol";
import {AirdopMerkleNFTMarket} from "../src/AirdopMerkleNFTMarket.sol";

contract DeployAirdropMarket is Script {
    function run(bytes32 merkleRoot)
        external
        returns (
            MyERC20Permit,
            MyERC721,
            AirdopMerkleNFTMarket
        )
    {
        vm.startBroadcast();

        // 部署ERC20
        MyERC20Permit token = new MyERC20Permit();
        // 部署NFT
        MyERC721 nft = new MyERC721();
        // 部署市场合约
        AirdopMerkleNFTMarket market = new AirdopMerkleNFTMarket(
            address(token),
            address(nft),
            merkleRoot
        );

        vm.stopBroadcast();
        return (token, nft, market);
    }
}