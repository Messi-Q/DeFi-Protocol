// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../../interfaces/common/IUniswapRouterETH.sol";
import "../../interfaces/spooky/IXPool.sol";
import "../../interfaces/spooky/IXChef.sol";
import "../Common/StratManager.sol";
import "../Common/FeeManager.sol";
import "../../utils/GasThrottler.sol";

contract StrategyXSyrup is StratManager, FeeManager, GasThrottler {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Tokens used
    address public native;
    address public output;
    address public want;

    // Third party contracts
    address public xChef;
    uint256 public pid;
    address public xWant;

    // Routes
    address[] public outputToNativeRoute;
    address[] public outputToWantRoute;

    bool public harvestOnDeposit;
    uint256 public lastHarvest;

    event StratHarvest(address indexed harvester, uint256 wantHarvested, uint256 tvl);
    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);
    event SwapXChefPool(uint256 pid);

    constructor(
        address _want,
        address _xWant,
        uint256 _pid,
        address _xChef,
        address _vault,
        address _unirouter,
        address _keeper,
        address _strategist,
        address _beefyFeeRecipient,
        address[] memory _outputToNativeRoute,
        address[] memory _outputToWantRoute
    ) StratManager(_keeper, _strategist, _unirouter, _vault, _beefyFeeRecipient) public {
        want = _want;
        xWant = _xWant;
        pid = _pid;
        xChef = _xChef;

        output = _outputToNativeRoute[0];
        native = _outputToNativeRoute[_outputToNativeRoute.length - 1];
        outputToNativeRoute = _outputToNativeRoute;

        require(_outputToWantRoute[0] == output, "toDeposit[0] != output");
        require(_outputToWantRoute[_outputToWantRoute.length - 1] == want, "!want");
        outputToWantRoute = _outputToWantRoute;

        _giveAllowances();
    }

    // puts the funds to work
    function deposit() public whenNotPaused {
        uint256 wantBal = balanceOfWant();

        if (wantBal > 0) {
            IXPool(xWant).enter(wantBal);
            uint256 xWantBal = balanceOfXWant();
            IXChef(xChef).deposit(pid, xWantBal);
            emit Deposit(balanceOf());
        }
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");

        uint256 wantBal = balanceOfWant();
        uint256 xWantBal = IXPool(xWant).BOOForxBOO(wantBal);
        uint256 xAmount = IXPool(xWant).BOOForxBOO(_amount);

        if (wantBal < _amount) {
            IXChef(xChef).withdraw(pid, xAmount.sub(xWantBal));
            IXPool(xWant).leave(xAmount.sub(xWantBal));
            wantBal = balanceOfWant();
        }

        if (wantBal > _amount) {
            wantBal = _amount;
        }

        if (tx.origin != owner() && !paused()) {
            uint256 withdrawalFeeAmount = wantBal.mul(withdrawalFee).div(WITHDRAWAL_MAX);
            wantBal = wantBal.sub(withdrawalFeeAmount);
        }

        IERC20(want).safeTransfer(vault, wantBal);

        emit Withdraw(balanceOf());
    }

    function beforeDeposit() external override {
        if (harvestOnDeposit) {
            require(msg.sender == vault, "!vault");
            _harvest(tx.origin);
        }
    }

    function harvest() external gasThrottle virtual {
        _harvest(tx.origin);
    }

    function harvest(address callFeeRecipient) external gasThrottle virtual {
        _harvest(callFeeRecipient);
    }

    function managerHarvest() external onlyManager {
        _harvest(tx.origin);
    }

    // compounds earnings and charges performance fee
    function _harvest(address callFeeRecipient) internal whenNotPaused {
        IXChef(xChef).deposit(pid, 0);
        uint256 outputBal = IERC20(output).balanceOf(address(this));
        if (outputBal > 0) {
            chargeFees(callFeeRecipient);
            swapRewards();
            uint256 wantHarvested = balanceOfWant();
            deposit();

            lastHarvest = block.timestamp;
            emit StratHarvest(msg.sender, wantHarvested, balanceOf());
        }
    }

    // performance fees
    function chargeFees(address callFeeRecipient) internal {
        uint256 nativeBal;
        if (output != native) {
            uint256 toNative = IERC20(output).balanceOf(address(this)).mul(45).div(1000);
            IUniswapRouterETH(unirouter).swapExactTokensForTokens(toNative, 0, outputToNativeRoute, address(this), now);
            nativeBal = IERC20(native).balanceOf(address(this));
        } else {
            nativeBal = IERC20(native).balanceOf(address(this)).mul(45).div(1000);
        }

        uint256 callFeeAmount = nativeBal.mul(callFee).div(MAX_FEE);
        IERC20(native).safeTransfer(callFeeRecipient, callFeeAmount);

        uint256 beefyFeeAmount = nativeBal.mul(beefyFee).div(MAX_FEE);
        IERC20(native).safeTransfer(beefyFeeRecipient, beefyFeeAmount);

        uint256 strategistFee = nativeBal.mul(STRATEGIST_FEE).div(MAX_FEE);
        IERC20(native).safeTransfer(strategist, strategistFee);
    }

    // swap rewards to {want}
    function swapRewards() internal {
        if (want != output) {
            uint256 outputBal = IERC20(output).balanceOf(address(this));
            IUniswapRouterETH(unirouter).swapExactTokensForTokens(outputBal, 0, outputToWantRoute, address(this), block.timestamp);
        }
    }

    // calculate the total underlaying 'want' held by the strat.
    function balanceOf() public view returns (uint256) {
        return balanceOfWant().add(balanceOfPool());
    }

    // it calculates how much 'want' this contract holds.
    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    // it calculates how much 'xWant' this contract holds.
    function balanceOfXWant() public view returns (uint256) {
        return IERC20(xWant).balanceOf(address(this));
    }

    // it calculates how much 'want' the strategy has working in the farm.
    function balanceOfPool() public view returns (uint256) {
        (uint256 xWantBal,) = IXChef(xChef).userInfo(pid, address(this));
        return IXPool(xWant).xBOOForBOO(xWantBal);
    }

    // it calculates how much 'xWant' the strategy has working in the farm.
    function balanceOfXPool() public view returns (uint256) {
        (uint256 xWantBal,) = IXChef(xChef).userInfo(pid, address(this));
        return xWantBal;
    }

    function rewardsAvailable() public view returns (uint256) {
       return IXChef(xChef).pendingReward(pid, address(this));
    }

    function callReward() public view returns (uint256) {
        uint256 outputBal = rewardsAvailable();
        uint256 nativeOut;

        if (output != native) {
            uint256[] memory amountsOut = IUniswapRouterETH(unirouter).getAmountsOut(outputBal, outputToNativeRoute);
            nativeOut = amountsOut[amountsOut.length - 1].mul(45).div(1000).mul(callFee).div(MAX_FEE);
        } else {
            nativeOut = outputBal.mul(45).div(1000).mul(callFee).div(MAX_FEE);
        }

        return nativeOut;
    }

    function setHarvestOnDeposit(bool _harvestOnDeposit) external onlyManager {
        harvestOnDeposit = _harvestOnDeposit;

        if (harvestOnDeposit) {
            setWithdrawalFee(0);
        } else {
            setWithdrawalFee(10);
        }
    }

    function setShouldGasThrottle(bool _shouldGasThrottle) external onlyManager {
        shouldGasThrottle = _shouldGasThrottle;
    }

    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external {
        require(msg.sender == vault, "!vault");

        IXChef(xChef).withdraw(pid, balanceOfXPool());
        IXPool(xWant).leave(balanceOfXWant());

        uint256 wantBal = balanceOfWant();
        IERC20(want).transfer(vault, wantBal);
    }

    // pauses deposits and withdraws all funds from third party systems.
    function panic() public onlyManager {
        pause();
        IXChef(xChef).withdraw(pid, balanceOfXPool());
        IXPool(xWant).leave(balanceOfXWant());
    }

    function pause() public onlyManager {
        _pause();

        _removeAllowances();
    }

    function unpause() external onlyManager {
        _unpause();

        _giveAllowances();

        deposit();
    }

    function _giveAllowances() internal {
        IERC20(want).safeApprove(xWant, uint256(-1));
        IERC20(xWant).safeApprove(xChef, uint256(-1));
        IERC20(output).safeApprove(unirouter, uint256(-1));
    }

    function _removeAllowances() internal {
        IERC20(want).safeApprove(xWant, 0);
        IERC20(xWant).safeApprove(xChef, 0);
        IERC20(output).safeApprove(unirouter, 0);
    }

    function outputToNative() public view returns (address[] memory) {
        return outputToNativeRoute;
    }

    function outputToWant() public view returns (address[] memory) {
        return outputToWantRoute;
    }

    function swapXChefPool(uint256 _pid, address[] memory _outputToNativeRoute, address[] memory _outputToWantRoute) external onlyOwner {
        (address _output,,,,,,,,,) = IXChef(xChef).poolInfo(_pid);

        require((_output == _outputToNativeRoute[0]) && (_output == _outputToWantRoute[0]), "Proposed output in route is not valid");
        require(_outputToNativeRoute[_outputToNativeRoute.length - 1] == native, "Proposed native in route is not valid");
        require(_outputToWantRoute[_outputToWantRoute.length - 1] == want, "Proposed want in route is not valid");

        _harvest(tx.origin);
        IXChef(xChef).emergencyWithdraw(pid);
        IERC20(output).safeApprove(unirouter, 0);

        pid = _pid;
        output = _output;
        outputToNativeRoute = _outputToNativeRoute;
        outputToWantRoute = _outputToWantRoute;

        IERC20(output).safeApprove(unirouter, uint256(-1));
        IXChef(xChef).deposit(pid, balanceOfXWant());
        emit SwapXChefPool(pid);
    }
}
