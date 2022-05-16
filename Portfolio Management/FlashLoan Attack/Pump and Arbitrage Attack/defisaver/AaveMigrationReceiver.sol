// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../utils/SafeERC20.sol";
import "../../DS/DSProxy.sol";
import "../../auth/AdminAuth.sol";
import "./AaveMigration.sol";
import "./AaveMigrationTaker.sol";

contract AaveMigrationReceiver is AdminAuth {
    using SafeERC20 for ERC20;

    address public AAVE_MIGRATION_ADDR = 0x08c28BddD974bE326838cB1CAE064796335480CE;
    address public constant AAVE_V2_LENDING_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;

    function executeOperation(
        address[] calldata borrowAssets,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        address initiator,
        bytes calldata params
    ) public returns (bool) {

        // send loan tokens to proxy
        for (uint256 i = 0; i < borrowAssets.length; i++) {
            ERC20(borrowAssets[i]).safeTransfer(initiator, amounts[i]);
        }

        (AaveMigrationTaker.FlMigrationData memory flData) =
            abi.decode(params, (AaveMigrationTaker.FlMigrationData));

        AaveMigration.MigrateLoanData memory migrateLoanData =
            AaveMigration.MigrateLoanData({
                market: flData.market,
                collAssets: flData.collTokens,
                isColl: flData.isColl,
                borrowAssets: borrowAssets,
                borrowAmounts: amounts,
                fees: fees,
                modes: flData.modes
            });


        // call DsProxy
        DSProxy(payable(initiator)).execute{value: address(this).balance}(
            AAVE_MIGRATION_ADDR,
            abi.encodeWithSignature(
                "migrateLoan((address,address[],bool[],address[],uint256[],uint256[],uint256[]))",
                migrateLoanData
            )
        );

        return true;
    }

    function setAaveMigrationAddr(address _aaveMigrationAddr) public onlyOwner {
        AAVE_MIGRATION_ADDR = _aaveMigrationAddr;
    }

    /// @dev Allow contract to receive eth
    receive() external payable {}
}
