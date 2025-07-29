// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
// import {Ownable} from "@openzeppelin/access/Ownable.sol";

import {ERC20Upgradeable} from "@openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol"; // <--- 修正此处
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol"; // <--- 修正此处

import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";

import "forge-std/console.sol";


contract MemeToken is Initializable, ERC20Upgradeable, OwnableUpgradeable{

    uint256 public TOTAL_SUPPLY; // 总发行量
    uint256 public PER_MINT_AMOUNT;// 每次铸造的数量
    uint256 public MINT_PRICE; // 每次铸造的价格

    address public memeIssuer; // 发行者地址，谁调用factory 部署这个meme
    
    // 添加初始化函数:`initializer` 修饰符防止重复调用
    function initialize(string memory name,string memory symbol, uint256 _totalSupply, uint256 _perMintAmount, uint256 _mintPrice, address _memeIssuer)
        initializer // <--- 初始化修饰符
        public
    {
        // 调用父合约的初始化函数

        __ERC20_init(name, symbol); // <--- 现在这对于 ERC20Upgradeable 是正确的
        __Ownable_init();

        TOTAL_SUPPLY = _totalSupply;
        PER_MINT_AMOUNT = _perMintAmount;
        MINT_PRICE = _mintPrice;
        memeIssuer = _memeIssuer;
    }

    // 已经铸造的总量
    uint256 private _currentSupply;

    // 事件
    event MemeMinted(address indexed to, uint256 amount, uint256 feePaid);
    event FundsDistributed(address indexed memeIssuer, address indexed projectOwner, uint256 memeIssuerShare, uint256 projectShare);

    event DebugMintValue(uint256 msgValue, uint256 mintPrice);
    // 铸造方法:外部方法，需要进行资金转移
    function mint(address projectOwner,address recipient) external payable{
        emit DebugMintValue(msg.value, MINT_PRICE);
        console.log("msg.value", msg.value);
        console.log("MINT_PRICE", MINT_PRICE);
        // 确保有足够的Eth
        require(msg.value >= MINT_PRICE, "Insufficient ETH for minting");
        // 确保还有代币可以铸造
        require(_currentSupply + PER_MINT_AMOUNT <= TOTAL_SUPPLY, "Minting exceeds total supply");

        // 计算费用分配
        uint256 projectShare = (msg.value * 1) / 100; // 1% 给项目方
        uint256 issuerShare = msg.value - projectShare; // 剩下给 Meme 发行者

        // 分发ETH
        payable(projectOwner).transfer(projectShare);
        payable(memeIssuer).transfer(issuerShare);

        // 铸造代币给调用者
        _mint(recipient, PER_MINT_AMOUNT);
        _currentSupply += PER_MINT_AMOUNT;

        emit MemeMinted(recipient, PER_MINT_AMOUNT, msg.value);
        emit FundsDistributed(memeIssuer, projectOwner, issuerShare, projectShare);
    }

}