// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std-1.16.1/src/Script.sol";
import {LibRainDeploy} from "rain-deploy-0.1.2/src/lib/LibRainDeploy.sol";
import {LibCodeGen} from "rain-sol-codegen-0.1.0/src/lib/LibCodeGen.sol";
import {LibFs} from "rain-sol-codegen-0.1.0/src/lib/LibFs.sol";
import {DvinReceipt} from "../src/concrete/DvinReceipt.sol";
import {DvinReceiptVault} from "../src/concrete/DvinReceiptVault.sol";
import {
    OffchainAssetReceiptVaultBeaconSetDeployer,
    OffchainAssetReceiptVaultBeaconSetDeployerConfig
} from "rain-vats-0.1.6/src/concrete/deploy/OffchainAssetReceiptVaultBeaconSetDeployer.sol";
import {LibProdDeploy} from "../src/lib/LibProdDeploy.sol";

/// @title BuildPointers
/// @notice Deploys DvinReceipt, DvinReceiptVault and the
/// OffchainAssetReceiptVaultBeaconSetDeployer (configured with the two
/// deterministic implementation addresses) via the Zoltu factory in a local
/// environment and generates `.pointers.sol` files with deterministic deploy
/// addresses and bytecode hashes.
contract BuildPointers is Script {
    function addressConstantString(address addr) internal pure returns (string memory) {
        return string.concat(
            "\n",
            "/// @dev The deterministic deploy address of the contract when deployed via\n",
            "/// the Zoltu factory.\n",
            "address constant DEPLOYED_ADDRESS = address(",
            vm.toString(addr),
            ");\n"
        );
    }

    function run() external {
        LibRainDeploy.etchZoltuFactory(vm);

        address receipt = LibRainDeploy.deployZoltu(type(DvinReceipt).creationCode);
        LibFs.buildFileForContract(
            vm,
            receipt,
            "DvinReceipt",
            string.concat(
                addressConstantString(receipt),
                LibCodeGen.bytesConstantString(
                    vm,
                    "/// @dev The creation bytecode of the contract.",
                    "CREATION_CODE",
                    type(DvinReceipt).creationCode
                )
            )
        );

        address vault = LibRainDeploy.deployZoltu(type(DvinReceiptVault).creationCode);
        LibFs.buildFileForContract(
            vm,
            vault,
            "DvinReceiptVault",
            string.concat(
                addressConstantString(vault),
                LibCodeGen.bytesConstantString(
                    vm,
                    "/// @dev The creation bytecode of the contract.",
                    "CREATION_CODE",
                    type(DvinReceiptVault).creationCode
                )
            )
        );

        bytes memory beaconCreationCode = abi.encodePacked(
            type(OffchainAssetReceiptVaultBeaconSetDeployer).creationCode,
            abi.encode(
                OffchainAssetReceiptVaultBeaconSetDeployerConfig({
                    initialOwner: LibProdDeploy.BEACON_INIITAL_OWNER,
                    initialReceiptImplementation: receipt,
                    initialOffchainAssetReceiptVaultImplementation: vault
                })
            )
        );
        address beacon = LibRainDeploy.deployZoltu(beaconCreationCode);
        LibFs.buildFileForContract(
            vm,
            beacon,
            "DvinReceiptVaultBeaconSetDeployer",
            string.concat(
                addressConstantString(beacon),
                LibCodeGen.bytesConstantString(
                    vm,
                    "/// @dev The creation bytecode of the contract (includes constructor args).",
                    "CREATION_CODE",
                    beaconCreationCode
                )
            )
        );
    }
}
