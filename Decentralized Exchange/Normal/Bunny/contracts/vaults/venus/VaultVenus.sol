// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

/*
  ___                      _   _
 | _ )_  _ _ _  _ _ _  _  | | | |
 | _ \ || | ' \| ' \ || | |_| |_|
 |___/\_,_|_||_|_||_\_, | (_) (_)
                    |__/

*
* MIT License
* ===========
*
* Copyright (c) 2020 BunnyFinance
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../../library/PausableUpgradeable.sol";
import "../../library/SafeToken.sol";
import "../../library/SafeVenus.sol";

import "../../interfaces/IStrategy.sol";
import "../../interfaces/IVToken.sol";
import "../../interfaces/IVenusDistribution.sol";
import "../../interfaces/IVaultVenusBridge.sol";
import "../../interfaces/IBank.sol";
import "../VaultController.sol";
import "./VaultVenusBridgeOwner.sol";
import "../../interfaces/qubit/IVaultQubit.sol";
import "../../interfaces/IVaultVenus.sol";

contract VaultVenus is VaultController, IVaultVenus, ReentrancyGuardUpgradeable {
    using SafeMath for uint;
    using SafeToken for address;

    /* ========== CONSTANTS ============= */

    uint public constant override pid = 9999;
    PoolConstant.PoolTypes public constant override poolType = PoolConstant.PoolTypes.Venus;

    IVenusDistribution private constant VENUS_UNITROLLER = IVenusDistribution(0xfD36E2c2a6789Db23113685031d7F16329158384);
    VaultVenusBridgeOwner private constant VENUS_BRIDGE_OWNER = VaultVenusBridgeOwner(0x500f1F9b16ff707F81d5281de6E5D5b14cE8Ea71);

    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant XVS = 0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63;

    uint private constant COLLATERAL_RATIO_INIT = 975;
    uint private constant COLLATERAL_RATIO_EMERGENCY = 998;
    uint private constant COLLATERAL_RATIO_SYSTEM_DEFAULT = 6e17;
    uint private constant DUST = 1000;

    uint private constant VENUS_EXIT_BASE = 10000;

    /* ========== STATE VARIABLES ========== */

    IVToken public vToken;
    IVaultVenusBridge public venusBridge;
    SafeVenus public safeVenus;
    address public bank;

    uint public venusBorrow;
    uint public venusSupply;

    uint public collateralDepth;
    uint public collateralRatioFactor;

    uint public collateralRatio;
    uint public collateralRatioLimit;
    uint public collateralRatioEmergency;

    uint public reserveRatio;

    uint public totalShares;
    mapping(address => uint) private _shares;
    mapping(address => uint) private _principal;
    mapping(address => uint) private _depositedAt;

    uint public venusExitRatio;
    uint public collateralRatioSystem;

    address public migrationVault;

    /* ========== EVENTS ========== */

    event CollateralFactorsUpdated(uint collateralRatioFactor, uint collateralDepth);
    event DebtAdded(address bank, uint amount);
    event DebtRemoved(address bank, uint amount);

    /* ========== MODIFIERS ========== */

    modifier onlyBank {
        require(bank != address(0) && msg.sender == bank, 'VaultVenus: caller is not the bank');
        _;
    }

    modifier accrueBank {
        if (bank != address(0)) {
            IBank(bank).executeAccrue();
        }
        _;
    }

    /* ========== INITIALIZER ========== */

    receive() external payable {}

    function initialize(address _token, address _vToken) external initializer {
        require(_token != address(0), "VaultVenus: invalid token");
        __VaultController_init(IBEP20(_token));
        __ReentrancyGuard_init();

        vToken = IVToken(_vToken);

        (, uint collateralFactorMantissa,) = VENUS_UNITROLLER.markets(_vToken);
        collateralFactorMantissa = Math.min(collateralFactorMantissa, Math.min(collateralRatioSystem, COLLATERAL_RATIO_SYSTEM_DEFAULT));

        collateralDepth = 8;
        collateralRatioFactor = COLLATERAL_RATIO_INIT;

        collateralRatio = 0;
        collateralRatioEmergency = collateralFactorMantissa.mul(COLLATERAL_RATIO_EMERGENCY).div(1000);
        collateralRatioLimit = collateralFactorMantissa.mul(collateralRatioFactor).div(1000);

        reserveRatio = 10;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function totalSupply() external view override returns (uint) {
        return totalShares;
    }

    function balance() public view override returns (uint) {
        uint debtOfBank = bank == address(0) ? 0 : IBank(bank).debtToProviders();
        return balanceAvailable().add(venusSupply).sub(venusBorrow).add(debtOfBank);
    }

    function balanceAvailable() public view returns (uint) {
        return venusBridge.availableOf(address(this));
    }

    function balanceReserved() public view returns (uint) {
        return Math.min(balanceAvailable(), balance().mul(reserveRatio).div(1000));
    }

    function balanceOf(address account) public view override returns (uint) {
        if (totalShares == 0) return 0;
        return balance().mul(sharesOf(account)).div(totalShares);
    }

    function withdrawableBalanceOf(address account) public view override returns (uint) {
        return balanceOf(account);
    }

    function sharesOf(address account) public view override returns (uint) {
        return _shares[account];
    }

    function principalOf(address account) override public view returns (uint) {
        return _principal[account];
    }

    function earned(address account) override public view returns (uint) {
        uint accountBalance = balanceOf(account);
        uint accountPrincipal = principalOf(account);
        if (accountBalance >= accountPrincipal + DUST) {
            return accountBalance.sub(accountPrincipal);
        } else {
            return 0;
        }
    }

    function depositedAt(address account) external view override returns (uint) {
        return _depositedAt[account];
    }

    function rewardsToken() external view override returns (address) {
        return address(_stakingToken);
    }

    function priceShare() external view override returns (uint) {
        if (totalShares == 0) return 1e18;
        return balance().mul(1e18).div(totalShares);
    }

    function getUtilizationInfo() external view returns (uint liquidity, uint utilized) {
        liquidity = balance();
        utilized = balance().sub(balanceReserved());
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    //    function setVenusBridge(address payable newBridge) public payable onlyOwner {
    //        require(newBridge != address(0), "VenusVault: bridge must be non-zero address");
    //        if (_stakingToken.allowance(address(this), address(newBridge)) == 0) {
    //            _stakingToken.safeApprove(address(newBridge), uint(- 1));
    //        }
    //
    //        uint _balanceBefore;
    //        if (address(venusBridge) != address(0) && totalShares > 0) {
    //            _balanceBefore = balance();
    //
    //            venusBridge.harvest();
    //            _decreaseCollateral(uint(- 1));
    //
    //            (venusBorrow, venusSupply) = safeVenus.venusBorrowAndSupply(address(this));
    //            require(venusBorrow == 0 && venusSupply == 0, "VaultVenus: borrow and supply must be zero");
    //            venusBridge.migrateTo(newBridge);
    //        }
    //
    //        venusBridge = IVaultVenusBridge(newBridge);
    //        uint _balanceAfter = balance();
    //        if (_balanceAfter < _balanceBefore && address(_stakingToken) != WBNB) {
    //            uint migrationCost = _balanceBefore.sub(_balanceAfter);
    //            _stakingToken.transferFrom(owner(), address(venusBridge), migrationCost);
    //            venusBridge.deposit(address(this), migrationCost);
    //        }
    //
    //        IVaultVenusBridge.MarketInfo memory market = venusBridge.infoOf(address(this));
    //        require(market.token != address(0) && market.vToken != address(0), "VaultVenus: invalid market info");
    //        _increaseCollateral(safeVenus.safeCompoundDepth(address(this)));
    //    }
    //
    //    function setMinter(address newMinter) public override onlyOwner {
    //        VaultController.setMinter(newMinter);
    //    }
    //
    //    function setBunnyChef(IBunnyChef newChef) public override onlyOwner {
    //        require(address(_bunnyChef) == address(0), "VaultVenus: bunnyChef exists");
    //        VaultController.setBunnyChef(IBunnyChef(newChef));
    //    }
    //
    //    function setCollateralFactors(uint _collateralRatioFactor, uint _collateralDepth) external onlyOwner {
    //        require(_collateralRatioFactor < COLLATERAL_RATIO_EMERGENCY, "VenusVault: invalid collateral ratio factor");
    //
    //        collateralRatioFactor = _collateralRatioFactor;
    //        collateralDepth = _collateralDepth;
    //        _increaseCollateral(safeVenus.safeCompoundDepth(address(this)));
    //        emit CollateralFactorsUpdated(_collateralRatioFactor, _collateralDepth);
    //    }
    //
    //    function setCollateralRatioSystem(uint _collateralRatioSystem) external onlyOwner {
    //        require(_collateralRatioSystem <= COLLATERAL_RATIO_SYSTEM_DEFAULT, "VenusVault: invalid collateral ratio system");
    //        collateralRatioSystem = _collateralRatioSystem;
    //    }
    //
    //    function setReserveRatio(uint _reserveRatio) external onlyOwner {
    //        require(_reserveRatio < 1000, "VaultVenus: invalid reserve ratio");
    //        reserveRatio = _reserveRatio;
    //    }

    function setVenusExitRatio(uint _ratio) external onlyOwner {
        require(_ratio <= VENUS_EXIT_BASE);
        venusExitRatio = _ratio;
    }

    function setSafeVenus(address payable _safeVenus) public onlyOwner {
        safeVenus = SafeVenus(_safeVenus);
    }

    function setBank(address newBank) external onlyOwner {
        require(address(bank) == address(0), "VaultVenus: bank exists");
        bank = newBank;
    }

    function increaseCollateral() external onlyKeeper {
        _increaseCollateral(safeVenus.safeCompoundDepth(address(this)));
    }

    function decreaseCollateral(uint amountMin, uint supply) external payable onlyKeeper {
        updateVenusFactors();

        uint _balanceBefore = balance();

        supply = msg.value > 0 ? msg.value : supply;
        if (address(_stakingToken) == WBNB) {
            venusBridge.deposit{value : supply}(address(this), supply);
        } else {
            _stakingToken.safeTransferFrom(msg.sender, address(venusBridge), supply);
            venusBridge.deposit(address(this), supply);
        }

        venusBridge.mint(balanceAvailable());
        _decreaseCollateral(amountMin);
        venusBridge.withdraw(msg.sender, supply);

        updateVenusFactors();
        uint _balanceAfter = balance();
        if (_balanceAfter < _balanceBefore && address(_stakingToken) != WBNB) {
            uint migrationCost = _balanceBefore.sub(_balanceAfter);
            _stakingToken.safeTransferFrom(owner(), address(venusBridge), migrationCost);
            venusBridge.deposit(address(this), migrationCost);
        }
    }

    function setMigrationVault(address _vault) external onlyOwner {
        IVaultQubit qubitVault = IVaultQubit(_vault);
        require(qubitVault.stakingToken() == address(_stakingToken), "VaultVenus: Invalid migration vault address");

        migrationVault = _vault;
    }

    /* ========== BANKING FUNCTIONS ========== */

    function borrow(uint amount) external onlyBank returns (uint) {
        updateVenusFactors();
        uint available = balanceAvailable();
        if (available < amount) {
            _decreaseCollateral(amount);
            available = balanceAvailable();
        }

        amount = Math.min(amount, available);
        venusBridge.withdraw(bank, amount);

        emit DebtAdded(bank, amount);
        return amount;
    }

    function repay() external payable onlyBank returns (uint) {
        uint amount = msg.value;
        venusBridge.deposit{value : amount}(address(this), amount);

        emit DebtRemoved(bank, amount);
        return amount;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function updateVenusFactors() public {
        (venusBorrow, venusSupply) = safeVenus.venusBorrowAndSupply(address(this));
        (, uint collateralFactorMantissa,) = VENUS_UNITROLLER.markets(address(vToken));
        collateralFactorMantissa = Math.min(collateralFactorMantissa, Math.min(collateralRatioSystem, COLLATERAL_RATIO_SYSTEM_DEFAULT));

        collateralRatio = venusBorrow == 0 ? 0 : venusBorrow.mul(1e18).div(venusSupply);
        collateralRatioLimit = collateralFactorMantissa.mul(collateralRatioFactor).div(1000);
        collateralRatioEmergency = collateralFactorMantissa.mul(COLLATERAL_RATIO_EMERGENCY).div(1000);
    }

    function deposit(uint amount) public override accrueBank notPaused nonReentrant {
        require(address(_stakingToken) != WBNB, 'VaultVenus: invalid asset');
        updateVenusFactors();

        uint _balance = balance();
        uint _before = balanceAvailable();
        _stakingToken.safeTransferFrom(msg.sender, address(venusBridge), amount);
        venusBridge.deposit(address(this), amount);
        amount = balanceAvailable().sub(_before);

        uint shares = totalShares == 0 ? amount : amount.mul(totalShares).div(_balance);
        if (address(_bunnyChef) != address(0)) {
            _bunnyChef.updateRewardsOf(address(this));
        }

        totalShares = totalShares.add(shares);
        _shares[msg.sender] = _shares[msg.sender].add(shares);
        _principal[msg.sender] = _principal[msg.sender].add(amount);
        _depositedAt[msg.sender] = block.timestamp;

        if (address(_bunnyChef) != address(0)) {
            _bunnyChef.notifyDeposited(msg.sender, shares);
        }
        emit Deposited(msg.sender, amount);
    }

    function depositAll() external override {
        deposit(_stakingToken.balanceOf(msg.sender));
    }

    function depositBNB() public payable accrueBank notPaused nonReentrant {
        require(address(_stakingToken) == WBNB, 'VaultVenus: invalid asset');
        updateVenusFactors();

        uint _balance = balance();
        uint amount = msg.value;
        venusBridge.deposit{value : amount}(address(this), amount);

        uint shares = totalShares == 0 ? amount : amount.mul(totalShares).div(_balance);
        if (address(_bunnyChef) != address(0)) {
            _bunnyChef.updateRewardsOf(address(this));
        }

        totalShares = totalShares.add(shares);
        _shares[msg.sender] = _shares[msg.sender].add(shares);
        _principal[msg.sender] = _principal[msg.sender].add(amount);
        _depositedAt[msg.sender] = block.timestamp;

        if (address(_bunnyChef) != address(0)) {
            _bunnyChef.notifyDeposited(msg.sender, shares);
        }
        emit Deposited(msg.sender, amount);
    }

    function withdrawAll() external override accrueBank {
        (uint amount, uint withdrawalFee) = _getExitAmount();
        amount = _getAmountWithExitRatio(amount);
        venusBridge.withdraw(msg.sender, amount);
        if (collateralRatio > collateralRatioLimit) {
            _decreaseCollateral(0);
        }
        emit Withdrawn(msg.sender, amount, withdrawalFee);
    }

    function withdraw(uint) external override {
        revert("N/A");
    }

    function withdrawUnderlying(uint _amount) external accrueBank {
        updateVenusFactors();
        uint amount = Math.min(_amount, _principal[msg.sender]);
        uint available = balanceAvailable();
        if (available < amount) {
            _decreaseCollateral(_getBufferedAmountMin(amount));
            available = balanceAvailable();
        }

        amount = Math.min(amount, available);
        uint shares = balance() == 0 ? 0 : Math.min(amount.mul(totalShares).div(balance()), _shares[msg.sender]);
        if (address(_bunnyChef) != address(0)) {
            _bunnyChef.notifyWithdrawn(msg.sender, shares);
        }

        totalShares = totalShares.sub(shares);
        _shares[msg.sender] = _shares[msg.sender].sub(shares);
        _principal[msg.sender] = _principal[msg.sender].sub(amount);

        uint depositTimestamp = _depositedAt[msg.sender];
        uint withdrawalFee = canMint() ? _minter.withdrawalFee(amount, depositTimestamp) : 0;
        if (withdrawalFee > DUST) {
            venusBridge.withdraw(address(this), withdrawalFee);
            if (address(_stakingToken) == WBNB) {
                _minter.mintFor{value : withdrawalFee}(address(0), withdrawalFee, 0, msg.sender, depositTimestamp);
            } else {
                _minter.mintFor(address(_stakingToken), withdrawalFee, 0, msg.sender, depositTimestamp);
            }
            amount = amount.sub(withdrawalFee);
        }

        amount = _getAmountWithExitRatio(amount);
        venusBridge.withdraw(msg.sender, amount);
        if (collateralRatio >= collateralRatioLimit) {
            _decreaseCollateral(0);
        }
        emit Withdrawn(msg.sender, amount, withdrawalFee);
    }

    function getReward() public override accrueBank nonReentrant {
        updateVenusFactors();
        uint amount = earned(msg.sender);
        uint available = balanceAvailable();
        if (available < amount) {
            _decreaseCollateral(_getBufferedAmountMin(amount));
            amount = earned(msg.sender);
            available = balanceAvailable();
        }

        amount = Math.min(amount, available);
        if (address(_bunnyChef) != address(0)) {
            uint bunnyAmount = _bunnyChef.safeBunnyTransfer(msg.sender);
            emit BunnyPaid(msg.sender, bunnyAmount, 0);
        }

        uint shares = balance() == 0 ? 0 : Math.min(amount.mul(totalShares).div(balance()), _shares[msg.sender]);
        if (address(_bunnyChef) != address(0)) {
            _bunnyChef.notifyWithdrawn(msg.sender, shares);
        }

        totalShares = totalShares.sub(shares);
        _shares[msg.sender] = _shares[msg.sender].sub(shares);

        // cleanup dust
        if (_shares[msg.sender] > 0 && _shares[msg.sender] < DUST) {
            if (address(_bunnyChef) != address(0)) {
                _bunnyChef.notifyWithdrawn(msg.sender, _shares[msg.sender]);
            }
            totalShares = totalShares.sub(_shares[msg.sender]);
            delete _shares[msg.sender];
        }

        uint depositTimestamp = _depositedAt[msg.sender];
        uint performanceFee = canMint() ? _minter.performanceFee(amount) : 0;
        if (performanceFee > DUST) {
            venusBridge.withdraw(address(this), performanceFee);
            if (address(_stakingToken) == WBNB) {
                _minter.mintFor{value : performanceFee}(address(0), 0, performanceFee, msg.sender, depositTimestamp);
            } else {
                _minter.mintFor(address(_stakingToken), 0, performanceFee, msg.sender, depositTimestamp);
            }
            amount = amount.sub(performanceFee);
        }

        amount = _getAmountWithExitRatio(amount);
        venusBridge.withdraw(msg.sender, amount);
        if (collateralRatio >= collateralRatioLimit) {
            _decreaseCollateral(0);
        }
        emit ProfitPaid(msg.sender, amount, performanceFee);
    }

    function harvest() public override accrueBank notPaused onlyKeeper {
        VENUS_BRIDGE_OWNER.harvestBehalf(address(this));
        _increaseCollateral(3);
    }

    function migrateTo() external override accrueBank {
        require(migrationVault != address(0), "VaultVenus: !migrationVault");
        IVaultQubit qubitVault = IVaultQubit(migrationVault);

        (uint amount, uint withdrawalFee) = _getExitAmount();

        amount = _getAmountWithExitRatio(amount);

        venusBridge.withdraw(address(this), amount);

        if (_stakingToken.allowance(address(this), migrationVault) == 0) {
            _stakingToken.safeApprove(migrationVault, uint(- 1));
        }

        if (address(_stakingToken) == WBNB) {
            qubitVault.depositBehalf{value: amount}(amount, msg.sender);
        } else {
            qubitVault.depositBehalf(amount, msg.sender);
        }
        if (collateralRatio > collateralRatioLimit) {
            _decreaseCollateral(0);
        }
        emit Withdrawn(msg.sender, amount, withdrawalFee);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _hasSufficientBalance(uint amount) private view returns (bool) {
        return balanceAvailable().add(venusSupply).sub(venusBorrow) >= amount;
    }

    function _getBufferedAmountMin(uint amount) private view returns (uint) {
        return venusExitRatio > 0 ? amount.mul(1005).div(1000) : amount;
    }

    function _getAmountWithExitRatio(uint amount) private view returns (uint) {
        uint redeemFee = amount.mul(1005).mul(venusExitRatio).div(1000).div(VENUS_EXIT_BASE);
        return amount.sub(redeemFee);
    }

    function _increaseCollateral(uint compound) private {
        updateVenusFactors();
        (uint mintable, uint mintableInUSD) = safeVenus.safeMintAmount(address(this));
        if (mintableInUSD > 1e18) {
            venusBridge.mint(mintable);
        }

        updateVenusFactors();
        uint borrowable = safeVenus.safeBorrowAmount(address(this));
        while (!paused && compound > 0 && borrowable > 1 szabo) {
            if (borrowable == 0 || collateralRatio >= collateralRatioLimit) {
                return;
            }

            venusBridge.borrow(borrowable);
            updateVenusFactors();
            (mintable, mintableInUSD) = safeVenus.safeMintAmount(address(this));
            if (mintableInUSD > 1e18) {
                venusBridge.mint(mintable);
            }

            updateVenusFactors();
            borrowable = safeVenus.safeBorrowAmount(address(this));
            compound--;
        }
    }

    function _decreaseCollateral(uint amountMin) private {
        updateVenusFactors();

        uint marketSupply = vToken.totalSupply().mul(vToken.exchangeRateCurrent()).div(1e18);
        uint marketLiquidity = marketSupply > vToken.totalBorrowsCurrent() ? marketSupply.sub(vToken.totalBorrowsCurrent()) : 0;
        require(marketLiquidity >= amountMin, "VaultVenus: not enough market liquidity");

        if (amountMin != uint(- 1) && collateralRatio == 0 && collateralRatioLimit == 0) {
            venusBridge.redeemUnderlying(Math.min(venusSupply, amountMin));
            updateVenusFactors();
        } else {
            uint redeemable = safeVenus.safeRedeemAmount(address(this));
            while (venusBorrow > 0 && redeemable > 0) {
                uint redeemAmount = amountMin > 0 ? Math.min(venusSupply, Math.min(redeemable, amountMin)) : Math.min(venusSupply, redeemable);
                venusBridge.redeemUnderlying(redeemAmount);
                venusBridge.repayBorrow(Math.min(venusBorrow, balanceAvailable()));
                updateVenusFactors();

                redeemable = safeVenus.safeRedeemAmount(address(this));
                uint available = balanceAvailable().add(redeemable);
                if (collateralRatio <= collateralRatioLimit && available >= amountMin) {
                    uint remain = amountMin > balanceAvailable() ? amountMin.sub(balanceAvailable()) : 0;
                    if (remain > 0) {
                        venusBridge.redeemUnderlying(Math.min(remain, redeemable));
                    }
                    updateVenusFactors();
                    return;
                }
            }

            if (amountMin == uint(- 1) && venusBorrow == 0) {
                venusBridge.redeemAll();
                updateVenusFactors();
            }
        }
    }

    function _getExitAmount() private returns (uint, uint) {
        updateVenusFactors();
        uint amount = balanceOf(msg.sender);
        require(_hasSufficientBalance(amount), "VaultVenus: insufficient balance");

        uint principal = principalOf(msg.sender);
        uint available = balanceAvailable();
        uint depositTimestamp = _depositedAt[msg.sender];
        if (available < amount) {
            _decreaseCollateral(_getBufferedAmountMin(amount));
            amount = balanceOf(msg.sender);
            available = balanceAvailable();
        }

        amount = Math.min(amount, available);
        uint shares = _shares[msg.sender];
        if (address(_bunnyChef) != address(0)) {
            _bunnyChef.notifyWithdrawn(msg.sender, shares);
            uint bunnyAmount = _bunnyChef.safeBunnyTransfer(msg.sender);
            emit BunnyPaid(msg.sender, bunnyAmount, 0);
        }

        totalShares = totalShares.sub(shares);
        delete _shares[msg.sender];
        delete _principal[msg.sender];
        delete _depositedAt[msg.sender];

        uint profit = amount > principal ? amount.sub(principal) : 0;
        uint withdrawalFee = canMint() ? _minter.withdrawalFee(principal, depositTimestamp) : 0;
        uint performanceFee = canMint() ? _minter.performanceFee(profit) : 0;
        if (withdrawalFee.add(performanceFee) > DUST) {
            venusBridge.withdraw(address(this), withdrawalFee.add(performanceFee));
            if (address(_stakingToken) == WBNB) {
                _minter.mintFor{value : withdrawalFee.add(performanceFee)}(address(0), withdrawalFee, performanceFee, msg.sender, depositTimestamp);
            } else {
                _minter.mintFor(address(_stakingToken), withdrawalFee, performanceFee, msg.sender, depositTimestamp);
            }

            if (performanceFee > 0) {
                emit ProfitPaid(msg.sender, profit, performanceFee);
            }
            amount = amount.sub(withdrawalFee).sub(performanceFee);
        }
        return (amount, withdrawalFee);
    }

    /* ========== SALVAGE PURPOSE ONLY ========== */

    function recoverToken(address tokenAddress, uint tokenAmount) external override onlyOwner {
        require(tokenAddress != address(0) && tokenAddress != address(_stakingToken) &&
        tokenAddress != address(vToken) && tokenAddress != XVS, "VaultVenus: cannot recover token");

        IBEP20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }
}
