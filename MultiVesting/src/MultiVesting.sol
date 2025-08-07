// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/access/Ownable.sol";

// 多人版锁仓合约
contract MultiVesting is Ownable {

    // 锁仓结构体
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 released;
        uint256 startTimestamp;
        bool exists;
    }

    IERC20 public immutable token;
    uint256 public constant cliffDuration = 356 days;
    uint256 public constant vestingDuration = 730 days;
    // 锁仓信息
    mapping(address=>VestingSchedule) public vestings;

    // 从OpenZeppelin v5.0开始，Ownable不再将默认部署者为owner,这个参数自己传入
    constructor(address _token, address _owner) Ownable(_owner) {
        require(_token != address(0), "Invalid token address");
        token = IERC20(_token);
    }

    // 添加一个受益人
    function addVesting(address beneficiary,uint256 amount,uint256 startTimestamp) external onlyOwner{
        // 受益人已经存在
        require(!vestings[beneficiary].exists, "Already exists");
        // 判断地址是否合法
        require(address(0) != beneficiary,"Invalid address");

        // 结构体
        vestings[beneficiary] = VestingSchedule({
            totalAmount: amount,
            released: 0,
            startTimestamp: startTimestamp,
            exists: true
        });
    }

    // 根据时间计算释放金额
    function vestAmount(address beneficiary, uint256 timestamp) public view returns (uint256){
        // 获取锁仓金额
        VestingSchedule memory  vesting = vestings[beneficiary];
        require(vesting.exists, "No vesting");
        if(timestamp < vesting.startTimestamp + cliffDuration){
            return 0;
        } else if(timestamp >= vesting.startTimestamp + cliffDuration + vestingDuration){
            return vesting.totalAmount;
        } else{
            uint256 monthsPassed = (timestamp - vesting.startTimestamp - cliffDuration) / 30 days;
            return (vesting.totalAmount * monthsPassed) / 24;
        }
    }

    // 可以释放查询
    function releasable(address beneficiary) public view returns (uint256) {
        uint256 vested = vestAmount(beneficiary, block.timestamp);
        return vested - vestings[beneficiary].released;
    }

    // 释放方法: 外部账户调用
    function relase() external {
        VestingSchedule storage vesting = vestings[msg.sender];
        require(vesting.exists, "No vesting");

        uint256 amount = releasable(msg.sender);
        require(amount > 0, "No tokens to release");
        // 修改已经释放数量
        vesting.released += amount;
        // 转给外部账户
        bool success = token.transfer(msg.sender, amount);
        require(success, "Transfer failed");
    }

    // 管理员统一转入所有锁仓金额到合约地址
    function deposit(uint256 amount) external onlyOwner {
        require(token.transferFrom(msg.sender, address(this), amount), "Deposit failed");
    }

}
