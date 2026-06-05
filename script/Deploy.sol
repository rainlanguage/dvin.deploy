// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std-1.16.1/src/Script.sol";
import {LibRainDeploy} from "rain-deploy-0.1.2/src/lib/LibRainDeploy.sol";
import {DvinReceipt} from "../src/concrete/DvinReceipt.sol";
import {DvinReceiptVault} from "../src/concrete/DvinReceiptVault.sol";
import {
    OffchainAssetReceiptVaultBeaconSetDeployer,
    OffchainAssetReceiptVaultBeaconSetDeployerConfig
} from "rain-vats-0.1.6/src/concrete/deploy/OffchainAssetReceiptVaultBeaconSetDeployer.sol";
import {LibProdDeploy} from "../src/lib/LibProdDeploy.sol";
import {
    DEPLOYED_ADDRESS as RECEIPT_DEPLOYED_ADDRESS,
    BYTECODE_HASH as RECEIPT_BYTECODE_HASH
} from "../src/generated/DvinReceipt.pointers.sol";
import {
    DEPLOYED_ADDRESS as VAULT_DEPLOYED_ADDRESS,
    BYTECODE_HASH as VAULT_BYTECODE_HASH
} from "../src/generated/DvinReceiptVault.pointers.sol";
import {
    DEPLOYED_ADDRESS as BEACON_DEPLOYED_ADDRESS,
    BYTECODE_HASH as BEACON_BYTECODE_HASH
} from "../src/generated/DvinReceiptVaultBeaconSetDeployer.pointers.sol";

bytes32 constant DEPLOYMENT_SUITE_DVIN = keccak256("dvin");

/// @title Deploy
/// @notice Deterministic deployment of DvinReceipt + DvinReceiptVault
/// implementations and the OffchainAssetReceiptVaultBeaconSetDeployer (wired to
/// the two implementations) via the Zoltu factory across all supported
/// networks. Requires DEPLOYMENT_KEY + DEPLOYMENT_SUITE=dvin.
contract Deploy is Script {
    mapping(string => mapping(address => bytes32)) internal sDepCodeHashes;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");
        bytes32 suite = keccak256(bytes(vm.envString("DEPLOYMENT_SUITE")));

        if (suite == DEPLOYMENT_SUITE_DVIN) {
            string[] memory networks = LibRainDeploy.supportedNetworks();

            LibRainDeploy.deployAndBroadcast(
                vm,
                networks,
                deployerPrivateKey,
                type(DvinReceipt).creationCode,
                "src/concrete/DvinReceipt.sol:DvinReceipt",
                RECEIPT_DEPLOYED_ADDRESS,
                RECEIPT_BYTECODE_HASH,
                new address[](0),
                sDepCodeHashes
            );

            LibRainDeploy.deployAndBroadcast(
                vm,
                networks,
                deployerPrivateKey,
                type(DvinReceiptVault).creationCode,
                "src/concrete/DvinReceiptVault.sol:DvinReceiptVault",
                VAULT_DEPLOYED_ADDRESS,
                VAULT_BYTECODE_HASH,
                new address[](0),
                sDepCodeHashes
            );

            bytes memory beaconCreationCode = abi.encodePacked(
                type(OffchainAssetReceiptVaultBeaconSetDeployer).creationCode,
                abi.encode(
                    OffchainAssetReceiptVaultBeaconSetDeployerConfig({
                        initialOwner: LibProdDeploy.BEACON_INIITAL_OWNER,
                        initialReceiptImplementation: RECEIPT_DEPLOYED_ADDRESS,
                        initialOffchainAssetReceiptVaultImplementation: VAULT_DEPLOYED_ADDRESS
                    })
                )
            );

            address[] memory dependencies = new address[](2);
            dependencies[0] = RECEIPT_DEPLOYED_ADDRESS;
            dependencies[1] = VAULT_DEPLOYED_ADDRESS;

            LibRainDeploy.deployAndBroadcast(
                vm,
                networks,
                deployerPrivateKey,
                beaconCreationCode,
                "dependencies/rain-vats-0.1.6/src/concrete/deploy/OffchainAssetReceiptVaultBeaconSetDeployer.sol:OffchainAssetReceiptVaultBeaconSetDeployer",
                BEACON_DEPLOYED_ADDRESS,
                BEACON_BYTECODE_HASH,
                dependencies,
                sDepCodeHashes
            );
        } else {
            revert("Unknown deployment suite");
        }
    }
}
