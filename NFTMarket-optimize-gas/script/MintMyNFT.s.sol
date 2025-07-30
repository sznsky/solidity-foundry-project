// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20; // 确保与你的合约版本匹配

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol"; // 用于调试输出

// 定义与你已部署合约匹配的接口
// 只需要包含你在脚本中需要调用的函数
interface IMyERC721 {
    function mint(address student, string memory tokenURI) external;
    // 如果需要，也可以添加其他 getter 函数来验证铸造结果，例如 ownerOf, tokenURI
    // function ownerOf(uint256 tokenId) external view returns (address);
    // function tokenURI(uint256 tokenId) external view returns (string memory);
}

contract MintMyNFT is Script {
    // --- TODO: 请替换以下变量为你的实际值 ---

    // 你的 MyERC721 合约在 Sepolia 上已部署的地址
    address private constant MY_ERC721_CONTRACT_ADDRESS = 0x633b4368f731f01abce050B6d7272e4f1E19Fba9;

    // 你想要铸造的 NFT 的接收者地址
    address private constant NFT_RECIPIENT_ADDRESS = 0x6cAD628E331097019D9C572e5D00B50b363107F5;

    // 你想要铸造的 NFT 的元数据 URI
    // 这是一个示例 IPFS URI，请替换为你的实际 URI
    string private constant NFT_TOKEN_URI = "https://tan-managerial-fox-206.mypinata.cloud/ipfs/bafkreidcokfmelwbudhfecokbmq33mnd5gstokpfdkkyoet4oxtqccbiye";

    // --- 结束 TODO 区 ---


    function run() public {
        // 开始广播交易
        // 这将允许脚本执行的外部调用被实际发送到区块链上
        vm.startBroadcast();

        // 获取已部署的 MyERC721 合约实例
        IMyERC721 myNftContract = IMyERC721(MY_ERC721_CONTRACT_ADDRESS);

        // 调用 mint 函数铸造 NFT
        console.log("start minit NFT...");
        myNftContract.mint(NFT_RECIPIENT_ADDRESS, NFT_TOKEN_URI);

        console.log("-----------------------------------------");
        console.log("NFT success");
        console.log("receive addres : ", NFT_RECIPIENT_ADDRESS);
        console.log("Token URI: ", NFT_TOKEN_URI);
        console.log("-----------------------------------------");

        // 停止广播交易
        vm.stopBroadcast();
    }
}