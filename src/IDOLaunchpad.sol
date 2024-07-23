// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IDO 合约，实现 Token 预售
 * @author 
 * @notice  
    开启预售: 支持对给定的任意ERC20开启预售，设定预售价格，募集ETH目标，超募上限，预售时长。
    任意用户可支付ETH参与预售；
    预售结束后，如果没有达到募集目标，则用户可领会退款；
    预售成功，用户可领取 Token，且项目方可提现募集的ETH；

    ：预售价格：0.0001 ETH
    ：预售数量：100 万
    ：预售门槛：单笔最低买入 0.01 ETH 最高买入 0.1 ETH
    ：募集目标：0.0001 ETH * 1_000_000 = 100 ETH 最多 200 ETH
 */
contract IDOLaunchpad is Ownable {
    IERC20 public idoToken;

    uint256 public constant SALE_TOKEN = 1_000_000 * 10 ** 18; // 预售数量：100 万
    uint256 public constant SALE_PRICE = 0.0001 ether; // 预售价格：0.0001 ETH
    uint256 public constant MAX_SALE_AMOUNT_TOTAL = 200 ether;
    uint256 public constant SALE_LIMIT_AMOUNT_TOTAL = 100 ether;
    uint256 public constant MIN_BUY_AMOUNT = 0.01 ether;
    uint256 public constant MAX_BUY_AMOUNT = 0.1 ether;

    // 保存每个地址购买的数量
    mapping(address => uint256) public balances;

    // 预售结束时间
    uint256 public saleEndTime;

    event PreSale(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);

    constructor(address _erc20) Ownable(msg.sender) {
        require(_erc20 != address(0), "zero address");
        idoToken = IERC20(_erc20);
        saleEndTime = block.timestamp + 30 days;
    }

    modifier onlyBeforeSaleEnd() {
        require(block.timestamp < saleEndTime, "sale ended");
        _;
    }

    modifier onlyAfterSaleEnd() {
        require(block.timestamp >= saleEndTime, "sale not ended");
        _;
    }

    modifier onlySuccessfulSale() {
        require(
            address(this).balance >= SALE_LIMIT_AMOUNT_TOTAL,
            "sale not successful"
        );
        _;
    }

    modifier onlyActiveSale() {
        require(block.timestamp < saleEndTime, "sale ended");
        require(
            address(this).balance < SALE_LIMIT_AMOUNT_TOTAL,
            "sale successful"
        );
        require(
            address(this).balance + msg.value <= MAX_SALE_AMOUNT_TOTAL,
            "Sale amount too high"
        );
        _;
    }

    function presale() external payable onlyActiveSale {
        require(msg.value >= MIN_BUY_AMOUNT, "Buy amount too low");
        require(msg.value <= MAX_BUY_AMOUNT, "Buy amount too high");

        // 参与预售所支付的 ETH 费用
        balances[msg.sender] += msg.value;

        idoToken.transfer(msg.sender, msg.value / SALE_PRICE);

        emit PreSale(msg.sender, msg.value);
    }

    /**
     * 领取预售的代币或者退款
     * @dev 预售成功后领取代币，预售失败后退款
     * @notice 预售成功后领取代币，预售失败后退款
     *  1. 募集的ETH超过100ETH，则预售成功，将预售的代币发送给购买者
     *      1. 领取代币 = 本次IDO发售的Token总量 * 用户购买的ETH / 本次IDO募集的ETH
     *                 = 用户购买的ETH数量 * 本次IDO发售的Token总量 / 本次IDO募集的ETH
     *                  balances[msg.sender] * SALE_TOKEN / address(this).balance
     *                  balances[msg.sender] * PreShare
     *  2. 募集的ETH低于100ETH，则预售失败，将购买者支付的ETH退回
     *
     */
    function claim() external {
        bool success = isSuccess();
        uint256 amount = balances[msg.sender];
        // IDO 募集的ETH
        uint256 totalETH = address(this).balance;
        require(amount > 0, "No balance to claim");
        balances[msg.sender] = 0;
        if (success) {
            idoToken.transfer(msg.sender, (SALE_TOKEN * amount) / totalETH);
            emit Claim(msg.sender, amount);
        } else {
            (bool ok, ) = msg.sender.call{value: amount}("");
            require(ok, "Failed to refund");
            emit Claim(msg.sender, amount);
        }
    }

    function withdraw() external onlyAfterSaleEnd onlyOwner {
        //  预售成功，项目方可提现募集的ETH；
        require(isSuccess(), "Cannot withdraw immediately sale not successful");

        uint256 saleAmount = address(this).balance;

        (bool success, ) = msg.sender.call{value: saleAmount}("");
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, saleAmount);
    }

    function isSuccess() public view returns (bool) {
        return
            address(this).balance >= SALE_LIMIT_AMOUNT_TOTAL &&
            block.timestamp >= saleEndTime;
    }
}
