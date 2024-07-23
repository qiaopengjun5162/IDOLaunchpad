// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IDOLaunchpad} from "../src/IDOLaunchpad.sol";
import {RNTToken} from "../src/RNTToken.sol";

contract IDOLaunchpadScript is Script {
    IDOLaunchpad public ido;
    RNTToken public rnt;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with the account:", deployerAddress);
        vm.startBroadcast(deployerPrivateKey);
        rnt = new RNTToken(deployerAddress);
        console.log("RNT address:", address(rnt));
        ido = new IDOLaunchpad(address(rnt));

        vm.stopBroadcast();
    }
}
