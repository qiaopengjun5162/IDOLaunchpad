// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IDOLaunchpad} from "../src/IDOLaunchpad.sol";
import {RNTToken} from "../src/RNTToken.sol";

contract IDOLaunchpadMock is IDOLaunchpad {
    constructor(address _token) IDOLaunchpad(_token) {}

    function setTotalFundsRaisedETH(uint256 amount) public {
        totalFundsRaisedETH = amount;
    }
}

contract IDOLaunchpadTest is Test {
    IDOLaunchpadMock public ido;
    IDOLaunchpad public idoL;
    RNTToken public token;
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        token = new RNTToken(owner);
        // idoL = new IDOLaunchpad(address(token));
        ido = new IDOLaunchpadMock(address(token));

        vm.startPrank(owner);
        token.mint(owner, 1_000_000);
        token.transfer(address(ido), 1_000);

        vm.stopPrank();
    }

    function testPresale() public {
        vm.startPrank(user);
        vm.deal(user, 0.02 ether);
        ido.presale{value: 0.02 ether}();
        assertEq(ido.balances(user), 0.02 ether);

        vm.stopPrank();
    }

    function testPresaleFailed() public {
        vm.startPrank(user);
        vm.deal(user, 0.2 ether);
        vm.expectRevert("Buy amount too high");
        ido.presale{value: 0.2 ether}();

        vm.stopPrank();
    }

    function testPresaleMinBuyAmountFailed() public {
        vm.startPrank(user);
        vm.deal(user, 0.002 ether);
        vm.expectRevert("Buy amount too low");
        ido.presale{value: 0.002 ether}();

        vm.stopPrank();
    }

    function testClaimSuccess() public {
        // (bool ok, ) = address(ido).call{value: 99.9 ether}("");
        // require(ok, "Failed to send ETH to contract");

        ido.setTotalFundsRaisedETH(99.9 ether);

        assertEq(
            ido.totalFundsRaisedETH(),
            99.9 ether,
            "totalFundsRaisedETH should be 100 ether"
        );
        vm.startPrank(user);
        vm.deal(user, 0.1 ether);
        ido.presale{value: 0.1 ether}();

        vm.warp(block.timestamp + 30 days + 1);
        assertEq(
            ido.totalFundsRaisedETH(),
            100 ether,
            "totalFundsRaisedETH should be 100 ether"
        );
        require(ido.isSuccess(), "IDO failed");

        ido.claim();
        assertEq(ido.balances(user), 0);
        assertEq(token.balanceOf(user), 1000);
        vm.stopPrank();
    }

    function testClaimFailed() public {
        vm.deal(address(ido), 99 ether);
        vm.startPrank(user);
        vm.deal(user, 0.1 ether);

        ido.presale{value: 0.1 ether}();

        vm.warp(block.timestamp + 30 days + 1);
        require(!ido.isSuccess(), "IDO success");

        ido.claim();
        assertEq(ido.balances(user), 0);
        assertEq(token.balanceOf(user), 0);
        assertEq(user.balance, 0.1 ether);

        vm.stopPrank();
    }

    function testWithdrawSuccess() public {
        vm.startPrank(user);
        ido.setTotalFundsRaisedETH(99.9 ether);
        vm.deal(address(ido), 99.9 ether);
        assertEq(
            ido.totalFundsRaisedETH(),
            99.9 ether,
            "totalFundsRaisedETH should be 100 ether"
        );

        vm.deal(user, 0.1 ether);
        ido.presale{value: 0.1 ether}();
        vm.stopPrank();

        vm.warp(block.timestamp + 30 days + 1);

        require(ido.isSuccess(), "IDO failed");
        assertEq(address(ido).balance, 100 ether);
        assertEq(
            ido.totalFundsRaisedETH(),
            100 ether,
            "totalFundsRaisedETH should be 100 ether"
        );

        ido.withdraw();
        assertEq(address(ido).balance, 0);
    }

    // 必须有 receive 函数，否则无法向合约转账，withdraw 会报错
    receive() external payable {}
}
