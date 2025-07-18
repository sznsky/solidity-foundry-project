// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


// 在合约顶部声明自定义错误
error InsufficientBalance(uint current, uint required);
error Unauthorized(string message);

// Bank合约
contract Bank {

    // 管理员地址
    address payable public administrator;

    // 记录用户账户余额
    mapping(address => uint) public balance_map;

    // 数组: 记录存钱金额前三的用户地址和余额
    address[3] public top3Address;
    uint[3] public top3Balance;

    // 初始化管理员的地址
    constructor() {
        // 构造函数中初始化可支付地址
        administrator = payable(msg.sender);
    }
    
    // 存钱
    receive() external payable  {
        balance_map[msg.sender] += msg.value;
        // 更新前三用户
        updateTop3Account(msg.sender, balance_map[msg.sender]);
    }


    // 提现
    function withdraw(uint amount) public payable {
        // 检查权限
        require(msg.sender == administrator, "Not an administrator");
        // 判断余额是否足够，否则回滚交易
        if (address(this).balance < amount){
            revert InsufficientBalance(address(this).balance, amount);
        }
        // call转账
        (bool sucess, ) = administrator.call{value:amount}("");
        require(sucess, "Transfer failed");
    }

    // 更新前三用户
    function updateTop3Account(address account, uint balance) private {
        // 遍历余额数组
        for(uint i=0;i<top3Balance.length;i++){
            if (balance > top3Balance[i]) {
                // 将当前位置及后面的元素向后移动一位
                for (uint j = top3Balance.length - 1; j > i; j--) {
                    top3Balance[j] = top3Balance[j - 1];
                    top3Address[j] = top3Address[j - 1];
                }
                // 插入新的账户和余额
                top3Balance[i] = balance;
                top3Address[i] = account;
                break; // 插入后即可退出循环
            }
        }
    }

    // 查看前三账号地址
    function getTop3Address() public view returns(address[3] memory){
        return top3Address;
    }

    // 查看前三账号余额
    function getTop3Balance() public view returns(uint[3] memory){
        return top3Balance;
    }
    
}

