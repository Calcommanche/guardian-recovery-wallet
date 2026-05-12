// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/GuardianRecoveryWallet.sol";

interface Vm {
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract DeployGuardianRecoveryWallet {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (GuardianRecoveryWallet wallet) {
        vm.startBroadcast();
        wallet = new GuardianRecoveryWallet();
        vm.stopBroadcast();
    }
}
