// SPDX-License-Identifier: AGPL V3.0

pragma solidity >=0.6.0 <0.8.0;

pragma experimental ABIEncoderV2;

interface IYRegistry {
    function getVaultInfo(address _vault)
        external
        view
        returns (
            address controller,
            address token,
            address strategy,
            bool isWrapped,
            bool isDelegated
        );
}
