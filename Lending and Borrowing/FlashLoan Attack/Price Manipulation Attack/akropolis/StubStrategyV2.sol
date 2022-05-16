// SPDX-License-Identifier: AGPL V3.0

pragma solidity >=0.6.0 <0.8.0;

pragma experimental ABIEncoderV2;

import {BaseStrategy, StrategyParams} from "@yearnvaults/contracts/BaseStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../interfaces/IERC20Mintable.sol";

contract StubStrategyV2 is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address investmentAddr;
    uint256 dumbYield;
    bool countProfit;
    uint256 uncountedProfit;
    string _name;

    constructor(
        address _vault,
        address _investmentAddr,
        uint256 _dumbYield
    ) public BaseStrategy(_vault) {
        maxReportDelay = 0;
        investmentAddr = _investmentAddr;
        dumbYield = _dumbYield;
        _name = "StubCurveStrategy";
    }

    //Overrides for BaseStrategy
    function name() external view override returns (string memory) {
        return _name;
    }

    //Analog of normalizedBalance()
    function estimatedTotalAssets() public view override returns (uint256) {
        //want - token registered in strategy, comes from the Vault
        return want.balanceOf(address(this)).add(want.balanceOf(investmentAddr));
    }

    function delegatedAssets() external view override returns (uint256) {
        return 0;
    }

    //Return some yield (profit) to the Vault or repay the debt (by demand)
    //All available funds are returned to the Vault
    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit, // THIS AMOUNT WILL BE AUTOMATICALLY WITHDRAWN BACK TO THE VAULT if available
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        if (countProfit && want.balanceOf(investmentAddr) > 0) {
            IERC20Mintable(address(want)).mint(dumbYield);
            //    want.transfer(investmentAddr, dumbYield);
            uncountedProfit = uncountedProfit.add(dumbYield);
        }
        //No steps to cover debt here. Just keep the yield
        _profit = uncountedProfit;
        uncountedProfit = 0;
    }

    //Re-investment strategy steps
    function adjustPosition(uint256 _debtOutstanding) internal override {
        //Dumb yield emulating
        uint256 currentBalance = want.balanceOf(address(this));

        if (currentBalance > 0) {
            want.transfer(investmentAddr, currentBalance);
        }

        if (!countProfit) {
            countProfit = true;
        }
    }

    //Return funds to the strategy contract ready to be withdrawn by Vault
    function liquidatePosition(uint256 _amountNeeded) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        if (_amountNeeded == 0) {
            return (0, 0);
        }

        uint256 balanceStrat = want.balanceOf(address(this));
        if (_amountNeeded > balanceStrat) {
            want.transferFrom(investmentAddr, address(this), _amountNeeded.sub(balanceStrat));
        }
        want.approve(address(vault), _amountNeeded);
        _liquidatedAmount = _amountNeeded; //Here fee should be subtracted
    }

    //Migrate funds to another strategy
    function prepareMigration(address _newStrategy) internal override {
        uint256 investedFunds = want.balanceOf(investmentAddr);
        want.transferFrom(investmentAddr, address(this), investedFunds);

        uint256 currentBalance = want.balanceOf(address(this));
        want.approve(_newStrategy, currentBalance);
    }

    function protectedTokens() internal view override returns (address[] memory) {}
}
