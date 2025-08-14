
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

//

contract EthCallOptionSeries is ERC20, Ownable, ReentrancyGuard, Pausable{

    using SafeERC20 for IERC20;

    // ---- 常量 & 参数 ----
    IERC20 public immutable quoteToken;   // USDT
    address public immutable treasury;    // 行权收取的 USDT 存入的金库地址
    uint256 public immutable strike;      // 行权价（USDT/ETH，1e18 精度，例如 1800e18 表示 1800 USDT/ETH）
    uint256 public immutable underlyingPerOption; // 每份期权对应的 ETH 数量（wei），如 1e16=0.01 ETH
    uint256 public immutable expiry;      // 到期时间戳（秒）
    uint256 public immutable exerciseWindow; // 行权时间窗（秒），如 86400 = 1 天

    bool public expired; // 是否已过期并清算完成

    // ---- 事件 ----
    event Minted(address indexed minter, address indexed to, uint256 ethIn, uint256 optionsOut);
    event Exercised(address indexed user, uint256 optionsBurned, uint256 usdtPaid, uint256 ethOut);
    event ExpiredAndSwept(address indexed owner, uint256 ethSwept, uint256 ts);

    // ---- 修饰符 ----
    modifier onlyDuringExerciseWindow() {
        require(block.timestamp >= expiry, "Not reached expiry");
        require(block.timestamp < expiry + exerciseWindow, "Exercise window over");
        require(!expired, "Series expired");
        _;
    }

    modifier onlyAfterWindow() {
        require(block.timestamp >= expiry + exerciseWindow, "Too early");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address quoteToken_,
        address treasury_,
        uint256 strike_,                // 1e18 精度（USDT/ETH）
        uint256 underlyingPerOption_,   // wei/option（如 1e16）
        uint256 expiry_,                // unix
        uint256 exerciseWindow_         // 秒
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        require(quoteToken_ != address(0), "quoteToken=0");
        require(treasury_   != address(0), "treasury=0");
        require(strike_     > 0, "strike=0");
        require(underlyingPerOption_ > 0, "underlyingPerOption=0");
        require(exerciseWindow_ > 0, "window=0");
        require(expiry_ > block.timestamp, "expiry in past");

        quoteToken = IERC20(quoteToken_);
        treasury   = treasury_;
        strike     = strike_;
        underlyingPerOption = underlyingPerOption_;
        expiry     = expiry_;
        exerciseWindow = exerciseWindow_;
    }

    // ---- ERC20 配置 ----
    function decimals() public pure override returns (uint8) {
        // 与 ETH 的最小单位匹配（但含义不同：1 token != 1 wei）
        return 18;
    }

    // ---- 发行：项目方用 ETH 抵押铸造期权 ----
    /**
     * @notice 发送 ETH 作为抵押，按比例铸造期权给 recipient
     * @dev options = msg.value / underlyingPerOption
     */
    function depositAndMint(address recipient) external payable nonReentrant whenNotPaused onlyOwner {
        require(!expired, "Series expired");
        require(recipient != address(0), "recipient=0");
        require(msg.value > 0, "no ETH");

        uint256 optionsOut = msg.value / underlyingPerOption;
        require(optionsOut > 0, "too little ETH");

        // 将可能的残余 wei 保留在合约中作为尘埃（Dust），保持完全抵押安全
        _mint(recipient, optionsOut);
        emit Minted(msg.sender, recipient, msg.value, optionsOut);
    }

    // ---- 行权：用户在到期窗口内，用 USDT 按固定行权价兑换 ETH ----
    /**
     * @notice 行权 `amount` 期权
     * @dev 用户需先对合约 `approve` 足够 USDT
     *      USDT 支付给 treasury；ETH 发给用户；期权被销毁
     */
    function exercise(uint256 amount) external nonReentrant onlyDuringExerciseWindow whenNotPaused {
        require(amount > 0, "amount=0");
        require(balanceOf(msg.sender) >= amount, "insufficient option");

        // 应付的 USDT（按 1e18 精度的 strike）：
        // pay = amount * underlyingPerOption * strike / 1e18
        // 其中 underlyingPerOption 是 wei/option，所以先乘再除，注意溢出由 0.8 保护
        uint256 usdtToPay = (amount * underlyingPerOption * strike) / 1e18;

        // 转入 USDT 到金库
        quoteToken.safeTransferFrom(msg.sender, treasury, usdtToPay);

        // 发送 ETH 给用户
        uint256 ethOut = amount * underlyingPerOption;
        // 销毁期权
        _burn(msg.sender, amount);

        // 使用 call 安全发送 ETH
        (bool ok, ) = payable(msg.sender).call{value: ethOut}("");
        require(ok, "ETH transfer failed");

        emit Exercised(msg.sender, amount, usdtToPay, ethOut);
    }

    // ---- 过期清算：项目方赎回剩余 ETH，冻结系列 ----
    /**
     * @notice 窗口结束后，项目方赎回所有剩余 ETH，并让代币永久失效（暂停）。
     * @dev 由于无法遍历所有持有人逐个烧毁，采用：设置 `expired=true` + pause，代币不可再转/行权。
     */
    function expireAndSweep() external nonReentrant onlyOwner onlyAfterWindow {
        // 判断期权是否过期
        require(!expired, "already expired");
        // 修改过期状态
        expired = true;
        // 暂停
        _pause();

        // 获取当前合约ETH余额
        uint256 amt = address(this).balance;
        if (amt > 0) {
            // 全部转到项目方的外部账户地址
            (bool ok, ) = payable(owner()).call{value: amt}("");
            require(ok, "sweep ETH failed");
        }
        emit ExpiredAndSwept(owner(), amt, block.timestamp);
    }

    // ---- 安全开关 ----
    function pause() external onlyOwner { _pause(); }

    // 更新暂停
    function unpause() external onlyOwner {
        require(!expired, "cannot unpause after expired");
        _unpause();
    }

    // ---- 转账钩子：过期或暂停时阻止交易 ----
    function _update(address from, address to, uint256 value) internal override {
        require(!expired, "series expired");
        require(!paused(), "paused");
        super._update(from, to, value);
    }

    // 收 ETH（如有人误转），增加抵押安全；不自动铸造
    receive() external payable {}
    
}