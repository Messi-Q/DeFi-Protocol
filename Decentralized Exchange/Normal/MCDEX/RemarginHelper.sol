// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../interface/ILiquidityPoolFull.sol";

contract RemarginHelper is ReentrancyGuard {
    function remargin(
        address from,
        uint256 fromIndex,
        address to,
        uint256 toIndex,
        int256 amount
    ) external nonReentrant {
        require(amount > 0, "remargin amount is zero");
        address collateralFrom = _collateral(from);
        if (from != to) {
            address collateralTo = _collateral(to);
            require(
                collateralFrom == collateralTo,
                "cannot remargin between perpetuals with different collaterals"
            );
        }
        require(
            IERC20(collateralFrom).allowance(msg.sender, to) >= uint256(amount),
            "remargin amount exceeds allowance"
        );
        ILiquidityPoolFull(from).withdraw(fromIndex, msg.sender, amount);
        ILiquidityPoolFull(to).deposit(toIndex, msg.sender, amount);
    }

    function _collateral(address perpetual) internal view returns (address collateral) {
        (, , address[7] memory addresses, , ) = ILiquidityPoolFull(perpetual)
            .getLiquidityPoolInfo();
        collateral = addresses[5];
    }
}
