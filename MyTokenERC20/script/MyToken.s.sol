// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol"; // 导入 Foundry 的脚本库
import "../src/MyToken.sol";  // 导入你的 MyToken 合约

contract DeployMyToken is Script {
    // 这是一个公共函数，Foundry 会自动执行它来部署合约
    function run() public returns (MyToken myToken) {
        // 1. 获取部署者的私钥
        // vm.envUint("PRIVATE_KEY") 会从环境变量中读取名为 PRIVATE_KEY 的值
        // 这就是为什么你需要通过 .env 文件或直接在命令行中设置 PRIVATE_KEY 的原因
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 2. 开始广播交易
        // 这一步告诉 Foundry 使用 deployerPrivateKey 对应的账户来发送后续的交易
        vm.startBroadcast(deployerPrivateKey);

        // 3. 部署 MyToken 合约
        // new MyToken("MyTokenName", "MTK") 调用了 MyToken 的构造函数
        // "MyTokenName" 和 "MTK" 是示例名称和符号，你可以根据你的需求修改
        myToken = new MyToken("MyAwesomeToken", "MAT");

        // 4. 停止广播交易
        // 这是一个好习惯，在所有需要广播的交易完成后停止广播
        vm.stopBroadcast();

        // 5. 打印部署的合约地址 (可选但推荐)
        // console.log 函数可以方便地在控制台输出信息
        console.log("MyToken deployed to:", address(myToken));
    }
}