// SPDX-License-Identifier: AGPL V3.0
pragma solidity ^0.6.12;

import "@ozUpgradesV3/contracts/access/OwnableUpgradeable.sol";
import "@ozUpgradesV3/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@ozUpgradesV3/contracts/math/SafeMathUpgradeable.sol";
import "@ozUpgradesV3/contracts/token/ERC20/SafeERC20Upgradeable.sol";
import "./MinterRole.sol";
import "./VestedAkroSenderRole.sol";

/**
 * @notice VestedAkro token represents AKRO token vested for a vestingPeriod set by owner of this VestedAkro token.
 * Generic holders of this token CAN NOT transfer it. They only can redeem AKRO from unlocked vAKRO.
 * Minters can mint unlocked vAKRO from AKRO to special VestedAkroSenders.
 * VestedAkroSender can send his unlocked vAKRO to generic holders, and this vAKRO will be vested. He can not redeem AKRO himself.
 */
contract VestedAkro is OwnableUpgradeable, IERC20Upgradeable, MinterRole, VestedAkroSenderRole {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event Locked(address indexed holder, uint256 amount);
    event Unlocked(address indexed holder, uint256 amount);
    event AkroAdded(uint256 amount);

    struct VestedBatch {
        uint256 amount; // Full amount of vAKRO vested in this batch
        uint256 start; // Vesting start time;
        uint256 end; // Vesting end time
        uint256 claimed; // vAKRO already claimed from this batch to unlocked balance of holder
    }

    struct Balance {
        VestedBatch[] batches; // Array of vesting batches
        uint256 locked; // Amount locked in batches
        uint256 unlocked; // Amount of unlocked vAKRO (which either was previously claimed, or received from Minter)
        uint256 firstUnclaimedBatch; // First batch which is not fully claimed
    }

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    uint256 public override totalSupply;
    IERC20Upgradeable public akro;
    uint256 public vestingPeriod; //set by owner of this VestedAkro token
    uint256 public vestingStart; //set by owner, default value 01 May 2021, 00:00:00 GMT+0
    uint256 public vestingCliff; //set by owner, cliff for akro unlock, 1 month by default
    mapping(address => mapping(address => uint256)) private allowances;
    mapping(address => Balance) private holders;

    uint256 public swapToAkroRateNumerator; //Amount of 1 vAkro for 1 AKRO - 1 by default
    uint256 public swapToAkroRateDenominator;

    function initialize(address _akro, uint256 _vestingPeriod) public initializer {
        __Ownable_init();
        MinterRole.initialize(_msgSender());
        VestedAkroSenderRole.initialize(_msgSender());

        _name = "Vested AKRO";
        _symbol = "vAKRO";
        _decimals = 18;

        akro = IERC20Upgradeable(_akro);
        require(_vestingPeriod > 0, "VestedAkro: vestingPeriod should be > 0");
        vestingPeriod = _vestingPeriod;
        vestingStart = 1619827200; //01 May 2021, 00:00:00 GMT+0
        vestingCliff = 31 * 24 * 60 * 60; //1 month - 31 day in May

        swapToAkroRateNumerator = 1;
        swapToAkroRateDenominator = 1;
    }

    // Stub for compiler purposes only
    function initialize(address sender) public override(MinterRole, VestedAkroSenderRole) {}

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override onlySender returns (bool) {
        // We require both sender and _msgSender() to have VestedAkroSender role
        // to prevent sender from redeem and prevent unauthorized transfers via transferFrom.
        require(isSender(sender), "VestedAkro: sender should have VestedAkroSender role");

        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowances[sender][_msgSender()].sub(amount, "VestedAkro: transfer amount exceeds allowance"));
        return true;
    }

    function transfer(address recipient, uint256 amount) public override onlySender returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function setVestingPeriod(uint256 _vestingPeriod) public onlyOwner {
        require(_vestingPeriod > 0, "VestedAkro: vestingPeriod should be > 0");
        vestingPeriod = _vestingPeriod;
    }

    /**
     * @notice Sets vesting start date (as unix timestamp). Owner only
     * @param _vestingStart Unix timestamp.
     */
    function setVestingStart(uint256 _vestingStart) public onlyOwner {
        require(_vestingStart > 0, "VestedAkro: vestingStart should be > 0");
        vestingStart = _vestingStart;
    }

    /**
     * @notice Sets vesting start date (as unix timestamp). Owner only
     * @param _vestingCliff Cliff in seconds (1 month by default)
     */
    function setVestingCliff(uint256 _vestingCliff) public onlyOwner {
        vestingCliff = _vestingCliff;
    }

    /**
     * @notice Sets the rate of ADEL to vAKRO swap: 1 ADEL = _swapRateNumerator/_swapRateDenominator vAKRO
     * @notice By default is set to 0, that means that swap is disabled
     * @param _swapRateNumerator Numerator for Adel converting. Can be set to 0 - that stops the swap.
     * @param _swapRateDenominator Denominator for Adel converting. Can't be set to 0
     */
    function setSwapRate(uint256 _swapRateNumerator, uint256 _swapRateDenominator) external onlyOwner {
        require(_swapRateDenominator > 0, "Incorrect value");
        swapToAkroRateNumerator = _swapRateNumerator;
        swapToAkroRateDenominator = _swapRateDenominator;
    }

    function mint(address beneficiary, uint256 amount) public onlyMinter {
        totalSupply = totalSupply.add(amount);
        holders[beneficiary].unlocked = holders[beneficiary].unlocked.add(amount);
        emit Transfer(address(0), beneficiary, amount);
    }

    /**
     * @notice Burns locked token from the user by the Minter
     * @param sender User to burn tokens from
     * @param amount Amount to burn
     */
    function burnFrom(address sender, uint256 amount) public onlyMinter {
        require(amount > 0, "Incorrect amount");
        require(sender != address(0), "Zero address");

        require(block.timestamp <= vestingStart, "Vesting has started");

        Balance storage b = holders[sender];

        require(b.locked >= amount, "Insufficient vAkro");
        require(b.batches.length > 0 || b.firstUnclaimedBatch < b.batches.length, "Nothing to burn");

        totalSupply = totalSupply.sub(amount);
        b.locked = b.locked.sub(amount);

        uint256 batchAmount = b.batches[b.firstUnclaimedBatch].amount;
        b.batches[b.firstUnclaimedBatch].amount = batchAmount.sub(amount);

        emit Transfer(sender, address(0), amount);
    }

    /**
     * @notice Adds AKRO liquidity to the swap contract
     * @param _amount Amout of AKRO added to the contract.
     */
    function addAkroLiquidity(uint256 _amount) public onlyMinter {
        require(_amount > 0, "Incorrect amount");

        IERC20Upgradeable(akro).safeTransferFrom(_msgSender(), address(this), _amount);

        emit AkroAdded(_amount);
    }

    /**
     * @notice Unlocks all avilable vAKRO for a holder
     * @param holder Whose funds to unlock
     * @return total unlocked amount awailable for redeem
     */
    function unlockAvailable(address holder) public returns (uint256) {
        require(holders[holder].batches.length > 0, "VestedAkro: nothing to unlock");
        claimAllFromBatches(holder);
        return holders[holder].unlocked;
    }

    /**
     * @notice Unlock all available vAKRO and redeem it
     * @return Amount redeemed
     */
    function unlockAndRedeemAll() public returns (uint256) {
        address beneficiary = _msgSender();
        claimAllFromBatches(beneficiary);
        return redeemAllUnlocked();
    }

    /**
     * @notice Redeem all already unlocked vAKRO. Sends AKRO by the set up rate
     * @return Amount vAkro redeemed
     */
    function redeemAllUnlocked() public returns (uint256) {
        address beneficiary = _msgSender();
        require(!isSender(beneficiary), "VestedAkro: VestedAkroSender is not allowed to redeem");
        uint256 amount = holders[beneficiary].unlocked;
        if (amount == 0) return 0;

        uint256 akroAmount = amount.mul(swapToAkroRateNumerator).div(swapToAkroRateDenominator);
        require(akro.balanceOf(address(this)) >= akroAmount, "Not enough AKRO");

        holders[beneficiary].unlocked = 0;
        totalSupply = totalSupply.sub(amount);

        akro.safeTransfer(beneficiary, akroAmount);

        emit Transfer(beneficiary, address(0), amount);
        return amount;
    }

    /**
     * @notice Calculates AKRO amount according to vAkro
     * @param account Whose funds to get balance
     * @return Akro amount recalculated
     */
    function balanceOfAkro(address account) public view returns (uint256) {
        Balance storage b = holders[account];
        uint256 amount = b.locked.add(b.unlocked);
        uint256 akroAmount = amount.mul(swapToAkroRateNumerator).div(swapToAkroRateDenominator);
        return akroAmount;
    }

    function balanceOf(address account) public view override returns (uint256) {
        Balance storage b = holders[account];
        return b.locked.add(b.unlocked);
    }

    function balanceInfoOf(address account)
        public
        view
        returns (
            uint256 locked,
            uint256 unlocked,
            uint256 unlockable
        )
    {
        Balance storage b = holders[account];
        return (b.locked, b.unlocked, calculateClaimableFromBatches(account));
    }

    function batchesInfoOf(address account) public view returns (uint256 firstUnclaimedBatch, uint256 totalBatches) {
        Balance storage b = holders[account];
        return (b.firstUnclaimedBatch, b.batches.length);
    }

    function batchInfo(address account, uint256 batch)
        public
        view
        returns (
            uint256 amount,
            uint256 start,
            uint256 end,
            uint256 claimed,
            uint256 claimable
        )
    {
        VestedBatch storage vb = holders[account].batches[batch];
        (claimable, ) = calculateClaimableFromBatch(vb);
        return (vb.amount, vestingStart, vestingStart.add(vestingPeriod), vb.claimed, claimable);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "VestedAkro: approve from the zero address");
        require(spender != address(0), "VestedAkro: approve to the zero address");

        allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "VestedAkro: transfer from the zero address");
        require(recipient != address(0), "VestedAkro: transfer to the zero address");

        holders[sender].unlocked = holders[sender].unlocked.sub(amount, "VestedAkro: transfer amount exceeds unlocked balance");
        createOrModifyBatch(recipient, amount);

        emit Transfer(sender, recipient, amount);
    }

    function createOrModifyBatch(address holder, uint256 amount) internal {
        Balance storage b = holders[holder];

        if (b.batches.length == 0 || b.firstUnclaimedBatch == b.batches.length) {
            b.batches.push(VestedBatch({amount: amount, start: vestingStart, end: vestingStart.add(vestingPeriod), claimed: 0}));
        } else {
            uint256 batchAmount = b.batches[b.firstUnclaimedBatch].amount;
            b.batches[b.firstUnclaimedBatch].amount = batchAmount.add(amount);
        }
        b.locked = b.locked.add(amount);
        emit Locked(holder, amount);
    }

    function claimAllFromBatches(address holder) internal {
        claimAllFromBatches(holder, holders[holder].batches.length);
    }

    function claimAllFromBatches(address holder, uint256 tillBatch) internal {
        Balance storage b = holders[holder];
        bool firstUnclaimedFound;
        uint256 claiming;
        for (uint256 i = b.firstUnclaimedBatch; i < tillBatch; i++) {
            (uint256 claimable, bool fullyClaimable) = calculateClaimableFromBatch(b.batches[i]);
            if (claimable > 0) {
                b.batches[i].claimed = b.batches[i].claimed.add(claimable);
                claiming = claiming.add(claimable);
            }
            if (!fullyClaimable && !firstUnclaimedFound) {
                b.firstUnclaimedBatch = i;
                firstUnclaimedFound = true;
            }
        }
        if (!firstUnclaimedFound) {
            b.firstUnclaimedBatch = b.batches.length;
        }
        if (claiming > 0) {
            b.locked = b.locked.sub(claiming);
            b.unlocked = b.unlocked.add(claiming);
            emit Unlocked(holder, claiming);
        }
    }

    /**
     * @notice Calculates claimable amount from all batches
     * @param holder pointer to a batch
     * @return claimable amount
     */
    function calculateClaimableFromBatches(address holder) internal view returns (uint256) {
        Balance storage b = holders[holder];
        uint256 claiming;
        for (uint256 i = b.firstUnclaimedBatch; i < b.batches.length; i++) {
            (uint256 claimable, ) = calculateClaimableFromBatch(b.batches[i]);
            claiming = claiming.add(claimable);
        }
        return claiming;
    }

    /**
     * @notice Calculates one batch
     * @param vb pointer to a batch
     * @return claimable amount and bool which is true if batch is fully claimable
     */
    function calculateClaimableFromBatch(VestedBatch storage vb) internal view returns (uint256, bool) {
        if (now < vestingStart.add(vestingCliff)) {
            return (0, false); // No unlcoks before cliff period is over
        }
        if (now >= vestingStart.add(vestingPeriod)) {
            return (vb.amount.sub(vb.claimed), true);
        }
        uint256 claimable = (vb.amount.mul(now.sub(vestingStart)).div(vestingPeriod)).sub(vb.claimed);
        return (claimable, false);
    }
}
