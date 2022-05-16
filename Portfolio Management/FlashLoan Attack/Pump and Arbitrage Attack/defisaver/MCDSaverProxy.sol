pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../loggers/DefisaverLogger.sol";
import "../../utils/Discount.sol";

import "../../interfaces/Spotter.sol";
import "../../interfaces/Jug.sol";
import "../../interfaces/DaiJoin.sol";
import "../../interfaces/Join.sol";

import "./MCDSaverProxyHelper.sol";
import "../../utils/BotRegistry.sol";
import "../../exchangeV3/DFSExchangeCore.sol";

/// @title Implements Boost and Repay for MCD CDPs
contract MCDSaverProxy is DFSExchangeCore, MCDSaverProxyHelper {
    uint256 public constant MANUAL_SERVICE_FEE = 400; // 0.25% Fee
    uint256 public constant AUTOMATIC_SERVICE_FEE = 333; // 0.3% Fee

    bytes32 public constant ETH_ILK =
        0x4554482d41000000000000000000000000000000000000000000000000000000;

    address public constant VAT_ADDRESS = 0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B;
    address public constant SPOTTER_ADDRESS = 0x65C79fcB50Ca1594B025960e539eD7A9a6D434A3;
    address public constant DAI_JOIN_ADDRESS = 0x9759A6Ac90977b93B58547b4A71c78317f391A28;
    address public constant JUG_ADDRESS = 0x19c0976f590D67707E62397C87829d896Dc0f1F1;
    address public constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public constant BOT_REGISTRY_ADDRESS = 0x637726f8b08a7ABE3aE3aCaB01A80E2d8ddeF77B;

    Vat public constant vat = Vat(VAT_ADDRESS);
    DaiJoin public constant daiJoin = DaiJoin(DAI_JOIN_ADDRESS);
    Spotter public constant spotter = Spotter(SPOTTER_ADDRESS);

    DefisaverLogger public constant logger =
        DefisaverLogger(0x5c55B921f590a89C1Ebe84dF170E655a82b62126);

    /// @notice Repay - draws collateral, converts to Dai and repays the debt
    /// @dev Must be called by the DSProxy contract that owns the CDP
    function repay(
        ExchangeData memory _exchangeData,
        uint256 _cdpId,
        uint256 _gasCost,
        address _joinAddr,
        ManagerType _managerType
    ) public payable {
        address managerAddr = getManagerAddr(_managerType);

        address user = getOwner(Manager(managerAddr), _cdpId);
        bytes32 ilk = Manager(managerAddr).ilks(_cdpId);

        drawCollateral(managerAddr, _cdpId, _joinAddr, _exchangeData.srcAmount);

        _exchangeData.user = user;
        _exchangeData.dfsFeeDivider = isAutomation() ? AUTOMATIC_SERVICE_FEE : MANUAL_SERVICE_FEE;
        (, uint256 daiAmount) = _sell(_exchangeData);

        daiAmount = sub(daiAmount, takeFee(_gasCost, daiAmount));

        paybackDebt(managerAddr, _cdpId, ilk, daiAmount, user);

        // if there is some eth left (0x fee), return it to user
        if (address(this).balance > 0) {
            tx.origin.transfer(address(this).balance);
        }

        logger.Log(
            address(this),
            msg.sender,
            "MCDRepay",
            abi.encode(_cdpId, user, _exchangeData.srcAmount, daiAmount)
        );
    }

    /// @notice Boost - draws Dai, converts to collateral and adds to CDP
    /// @dev Must be called by the DSProxy contract that owns the CDP
    function boost(
        ExchangeData memory _exchangeData,
        uint256 _cdpId,
        uint256 _gasCost,
        address _joinAddr,
        ManagerType _managerType
    ) public payable {
        address managerAddr = getManagerAddr(_managerType);

        address user = getOwner(Manager(managerAddr), _cdpId);
        bytes32 ilk = Manager(managerAddr).ilks(_cdpId);

        uint256 daiDrawn = drawDai(managerAddr, _cdpId, ilk, _exchangeData.srcAmount);

        _exchangeData.user = user;
        _exchangeData.dfsFeeDivider = isAutomation() ? AUTOMATIC_SERVICE_FEE : MANUAL_SERVICE_FEE;
        _exchangeData.srcAmount = sub(daiDrawn, takeFee(_gasCost, daiDrawn));
        (, uint256 swapedColl) = _sell(_exchangeData);

        addCollateral(managerAddr, _cdpId, _joinAddr, swapedColl);

        // if there is some eth left (0x fee), return it to the caller
        if (address(this).balance > 0) {
            tx.origin.transfer(address(this).balance);
        }

        logger.Log(
            address(this),
            msg.sender,
            "MCDBoost",
            abi.encode(_cdpId, user, _exchangeData.srcAmount, swapedColl)
        );
    }

    /// @notice Draws Dai from the CDP
    /// @dev If _daiAmount is bigger than max available we'll draw max
    /// @param _managerAddr Address of the CDP Manager
    /// @param _cdpId Id of the CDP
    /// @param _ilk Ilk of the CDP
    /// @param _daiAmount Amount of Dai to draw
    function drawDai(
        address _managerAddr,
        uint256 _cdpId,
        bytes32 _ilk,
        uint256 _daiAmount
    ) internal returns (uint256) {
        uint256 rate = Jug(JUG_ADDRESS).drip(_ilk);
        uint256 daiVatBalance = vat.dai(Manager(_managerAddr).urns(_cdpId));

        uint256 maxAmount = getMaxDebt(_managerAddr, _cdpId, _ilk);

        if (_daiAmount >= maxAmount) {
            _daiAmount = sub(maxAmount, 1);
        }

        Manager(_managerAddr).frob(
            _cdpId,
            int256(0),
            normalizeDrawAmount(_daiAmount, rate, daiVatBalance)
        );
        Manager(_managerAddr).move(_cdpId, address(this), toRad(_daiAmount));

        if (vat.can(address(this), address(DAI_JOIN_ADDRESS)) == 0) {
            vat.hope(DAI_JOIN_ADDRESS);
        }

        DaiJoin(DAI_JOIN_ADDRESS).exit(address(this), _daiAmount);

        return _daiAmount;
    }

    /// @notice Adds collateral to the CDP
    /// @param _managerAddr Address of the CDP Manager
    /// @param _cdpId Id of the CDP
    /// @param _joinAddr Address of the join contract for the CDP collateral
    /// @param _amount Amount of collateral to add
    function addCollateral(
        address _managerAddr,
        uint256 _cdpId,
        address _joinAddr,
        uint256 _amount
    ) internal {
        int256 convertAmount = 0;

        if (isEthJoinAddr(_joinAddr)) {
            Join(_joinAddr).gem().deposit{value: _amount}();
            convertAmount = toPositiveInt(_amount);
        } else {
            convertAmount = toPositiveInt(convertTo18(_joinAddr, _amount));
        }

        ERC20(address(Join(_joinAddr).gem())).safeApprove(_joinAddr, _amount);

        Join(_joinAddr).join(address(this), _amount);

        vat.frob(
            Manager(_managerAddr).ilks(_cdpId),
            Manager(_managerAddr).urns(_cdpId),
            address(this),
            address(this),
            convertAmount,
            0
        );
    }

    /// @notice Draws collateral and returns it to DSProxy
    /// @param _managerAddr Address of the CDP Manager
    /// @dev If _amount is bigger than max available we'll draw max
    /// @param _cdpId Id of the CDP
    /// @param _joinAddr Address of the join contract for the CDP collateral
    /// @param _amount Amount of collateral to draw
    function drawCollateral(
        address _managerAddr,
        uint256 _cdpId,
        address _joinAddr,
        uint256 _amount
    ) internal returns (uint256) {
        uint256 frobAmount = _amount;

        uint256 tokenDecimal = Join(_joinAddr).dec();

        require(tokenDecimal <= 18, "Token decimals too big");

        if (tokenDecimal != 18) {
            frobAmount = _amount * (10**(18 - tokenDecimal));
        }

        Manager(_managerAddr).frob(_cdpId, -toPositiveInt(frobAmount), 0);
        Manager(_managerAddr).flux(_cdpId, address(this), frobAmount);

        Join(_joinAddr).exit(address(this), _amount);

        if (isEthJoinAddr(_joinAddr)) {
            Join(_joinAddr).gem().withdraw(_amount); // Weth -> Eth
        }

        return _amount;
    }

    /// @notice Paybacks Dai debt
    /// @param _managerAddr Address of the CDP Manager
    /// @dev If the _daiAmount is bigger than the whole debt, returns extra Dai
    /// @param _cdpId Id of the CDP
    /// @param _ilk Ilk of the CDP
    /// @param _daiAmount Amount of Dai to payback
    /// @param _owner Address that owns the DSProxy that owns the CDP
    function paybackDebt(
        address _managerAddr,
        uint256 _cdpId,
        bytes32 _ilk,
        uint256 _daiAmount,
        address _owner
    ) internal {
        address urn = Manager(_managerAddr).urns(_cdpId);

        uint256 wholeDebt = getAllDebt(VAT_ADDRESS, urn, urn, _ilk);

        if (_daiAmount > wholeDebt) {
            ERC20(DAI_ADDRESS).transfer(_owner, sub(_daiAmount, wholeDebt));
            _daiAmount = wholeDebt;
        }

        if (ERC20(DAI_ADDRESS).allowance(address(this), DAI_JOIN_ADDRESS) == 0) {
            ERC20(DAI_ADDRESS).approve(DAI_JOIN_ADDRESS, uint256(-1));
        }

        daiJoin.join(urn, _daiAmount);

        Manager(_managerAddr).frob(_cdpId, 0, normalizePaybackAmount(VAT_ADDRESS, urn, _ilk));
    }

    /// @notice Gets the maximum amount of collateral available to draw
    /// @param _managerAddr Address of the CDP Manager
    /// @param _cdpId Id of the CDP
    /// @param _ilk Ilk of the CDP
    /// @param _joinAddr Joind address of collateral
    /// @dev Substracts 10 wei to aviod rounding error later on
    function getMaxCollateral(
        address _managerAddr,
        uint256 _cdpId,
        bytes32 _ilk,
        address _joinAddr
    ) public view returns (uint256) {
        uint256 price = getPrice(_ilk);

        (uint256 collateral, uint256 debt) = getCdpInfo(Manager(_managerAddr), _cdpId, _ilk);

        (, uint256 mat) = Spotter(SPOTTER_ADDRESS).ilks(_ilk);

        uint256 maxCollateral = sub(collateral, (div(mul(mat, debt), price)));

        uint256 tokenDecimal = Join(_joinAddr).dec();

        require(tokenDecimal <= 18, "Token decimals too big");

        uint256 normalizeMaxCollateral = maxCollateral / (10**(18 - tokenDecimal));

        // take one percent due to precision issues
        return (normalizeMaxCollateral * 99) / 100;
    }

    /// @notice Gets the maximum amount of debt available to generate
    /// @param _managerAddr Address of the CDP Manager
    /// @param _cdpId Id of the CDP
    /// @param _ilk Ilk of the CDP
    /// @dev Substracts 10 wei to aviod rounding error later on
    function getMaxDebt(
        address _managerAddr,
        uint256 _cdpId,
        bytes32 _ilk
    ) public view virtual returns (uint256) {
        uint256 price = getPrice(_ilk);

        (, uint256 mat) = spotter.ilks(_ilk);
        (uint256 collateral, uint256 debt) = getCdpInfo(Manager(_managerAddr), _cdpId, _ilk);

        return sub(sub(div(mul(collateral, price), mat), debt), 10);
    }

    /// @notice Gets a price of the asset
    /// @param _ilk Ilk of the CDP
    function getPrice(bytes32 _ilk) public view returns (uint256) {
        (, uint256 mat) = spotter.ilks(_ilk);
        (, , uint256 spot, , ) = vat.ilks(_ilk);

        return rmul(rmul(spot, spotter.par()), mat);
    }

    function isAutomation() internal view returns (bool) {
        return BotRegistry(BOT_REGISTRY_ADDRESS).botList(tx.origin);
    }

    function takeFee(uint256 _gasCost, uint256 _amount) internal returns (uint256) {
        if (_gasCost > 0) {
            uint256 ethDaiPrice = getPrice(ETH_ILK);
            uint256 feeAmount = rmul(_gasCost, ethDaiPrice);

            if (feeAmount > _amount / 5) {
                feeAmount = _amount / 5;
            }

            address walletAddr = _feeRecipient.getFeeAddr();

            ERC20(DAI_ADDRESS).safeTransfer(walletAddr, feeAmount);

            return feeAmount;
        }

        return 0;
    }
}
