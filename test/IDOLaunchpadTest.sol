// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IDOLaunchpad} from "../src/IDOLaunchpad.sol";
import {RNTToken} from "../src/RNTToken.sol";

contract IDOLaunchpadTest is Test {
    IDOLaunchpad public ido;
    RNTToken public rnt;
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        rnt = new RNTToken(owner);
        ido = new IDOLaunchpad(address(rnt));
    }
}
