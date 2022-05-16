pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./WarpWrapperToken.sol";
import "./interfaces/WarpControlI.sol";

////////////////////////////////////////////////////////////////////////////////////////////
/// @title WarpVaultLP
/// @author Christopher Dixon
////////////////////////////////////////////////////////////////////////////////////////////
/**
@notice the WarpVaultLP contract is the main point of interface for a specific LP asset class and an end user in the
Warp lending platform. This contract is responsible for distributing WarpWrapper tokens in exchange for stablecoin assets,
holding and accounting of stablecoins and LP tokens and all associates lending/borrowing calculations for a specific Warp LP asset class.
This contract inherits Ownership and ERC20 functionality from the Open Zeppelin Library as well as Exponential and the InterestRateModel contracts
from the coumpound protocol.
**/

contract WarpVaultLP {
    using SafeMath for uint256;

    uint256 public timeWizard;
    string public lpName;

    IERC20 public LPtoken;
    WarpControlI public warpControl;

    mapping(address => uint256) public collateralizedLP;

    event CollateralProvided(address _account, uint256 _amount);
    event CollateralWithdraw(address _account, uint256 _amount);
    event WarpControlChanged(address _newControl, address _oldControl);
    event AccountLiquidated(
        address _account,
        address _liquidator,
        uint256 _amount
    );

    /**
     * @dev Throws if called by any account other than a warp control
     */
    modifier onlyWarpControl() {
        require(msg.sender == address(warpControl));
        _;
    }

    /**
@dev Throws if a function is called before the time wizard allows it
**/
    modifier angryWizard() {
        require(now > timeWizard);
        _;
    }

    /**
    @notice constructor sets up token names and symbols for the WarpWrapperToken
    @param _lp is the address of the lp token a specific Warp vault will represent
    @param _lpName is the name of the lp token
    @param _timelock is a variable representing the number of seconds the timeWizard will prevent withdraws and borrows from a contracts(one week is 605800 seconds)
    @dev this function instantiates the lp token as a useable object and generates three WarpWrapperToken contracts to represent
        each type of stable coin this vault can hold. this also instantiates each of these contracts as a usable object in this contract giving
        this contract the ability to call their mint and burn functions.
    **/
    constructor(
        uint256 _timelock,
        address _lp,
        address _WarpControl,
        string memory _lpName
    ) public {
        lpName = _lpName;
        LPtoken = IERC20(_lp);
        warpControl = WarpControlI(_WarpControl);
        timeWizard = now.add(_timelock);
    }

    function updateWarpControl(address _warpControl) public onlyWarpControl {
        emit WarpControlChanged(_warpControl, address(warpControl));
        warpControl = WarpControlI(_warpControl);
    }

    /**
    @notice provideCollateral allows a user to collateralize this contracts associated LP token
    @param _amount is the amount of LP being collateralized
    **/
    function provideCollateral(uint256 _amount) public {
        require(
            LPtoken.allowance(msg.sender, address(this)) >= _amount,
            "Vault must have enough allowance."
        );
        require(
            LPtoken.balanceOf(msg.sender) >= _amount,
            "Must have enough LP to provide"
        );
        LPtoken.transferFrom(msg.sender, address(this), _amount);
        collateralizedLP[msg.sender] = collateralizedLP[msg.sender].add(
            _amount
        );

        emit CollateralProvided(msg.sender, _amount);
    }

    /**
    @notice withdrawCollateral allows the user to trade in his WarpLP tokens for hiss underlying LP token collateral
    @param _amount is the amount of LP tokens he wishes to withdraw
    **/
    function withdrawCollateral(uint256 _amount) public {
        uint256 amount;
        uint256 maxAmount = warpControl.getMaxWithdrawAllowed(
            msg.sender,
            address(LPtoken)
        );
        if (_amount == 0) {
            amount = maxAmount;
        } else {
            amount = _amount;
        }

        //require the availible value of the LP locked in this contract the user has
        //is greater than or equal to the amount being withdrawn
        require(maxAmount >= amount, "Trying to withdraw too much");
        //require the user has locked up enough collateral to withdraw this amount
        require(
            collateralizedLP[msg.sender] >= amount,
            "you are trying to withdraw more collateral than you have locked"
        );

        //subtract withdrawn amount from amount stored
        collateralizedLP[msg.sender] = collateralizedLP[msg.sender].sub(amount);
        //transfer them their token
        LPtoken.transfer(msg.sender, amount);
        emit CollateralWithdraw(msg.sender, amount);
    }

    /**
    @notice getAssetAdd allows for easy retrieval of a WarpVaults LP token Adress
    **/
    function getAssetAdd() public view returns (address) {
        return address(LPtoken);
    }

    /**
    @notice collateralOfAccount is a view function to retreive an accounts collateralized LP amount
    @param _account is the address of the account being looked up
    **/
    function collateralOfAccount(address _account)
        public
        view
        returns (uint256)
    {
        return collateralizedLP[_account];
    }

    /**
    @notice _liquidateAccount is a function to liquidate the LP tokens of the input account
    @param _account is the address of the account being liquidated
    @param _liquidator is the address of the account doing the liquidating who receives the liquidated LP's
    @dev this function uses the onlyWarpControl modifier meaning that only the Warp Control contract can call it
    **/
    function _liquidateAccount(address _account, address _liquidator)
        public
        onlyWarpControl
        angryWizard
    {
        emit AccountLiquidated(
            _account,
            _liquidator,
            collateralizedLP[_account]
        );
        //transfer the LP tokens to the liquidator
        LPtoken.transfer(_liquidator, collateralizedLP[_account]);
        //reset the borrowers collateral tracker
        collateralizedLP[_account] = 0;
    }

    function valueOfAccountCollateral(address _account)
        external
        view
        returns (uint256)
    {
        uint256 collateralPrice = warpControl.viewPriceOfCollateral(
            address(LPtoken)
        );
        uint256 collateralValue = collateralizedLP[_account].mul(
            collateralPrice
        );
        return collateralValue;
    }
}
