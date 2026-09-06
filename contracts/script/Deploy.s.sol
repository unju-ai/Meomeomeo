// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Meo404} from "../src/Meo404.sol";

/// @notice Deploy Meo404. Broadcast with a key from the environment — never hardcode.
///
///   export MEO404_DEPLOYER_PRIVATE_KEY=0x...
///   export MEO404_OWNER=0x...          # optional, defaults to deployer
///   export MEO404_MINTER=0x...         # hosted claim-service signer
///   forge script script/Deploy.s.sol --rpc-url $MEO404_RPC_URL --broadcast
contract Deploy is Script {
    function run() external returns (Meo404 token) {
        uint256 pk = vm.envUint("MEO404_DEPLOYER_PRIVATE_KEY");
        address owner = vm.envOr("MEO404_OWNER", vm.addr(pk));
        address minter = vm.envOr("MEO404_MINTER", owner);

        vm.startBroadcast(pk);
        token = new Meo404("Meo Meo Meo 404", "MEO404", owner);
        if (minter != owner) {
            token.setMinter(minter, true);
        }
        vm.stopBroadcast();
    }
}
