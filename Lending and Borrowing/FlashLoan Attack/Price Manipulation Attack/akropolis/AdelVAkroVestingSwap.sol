// SPDX-License-Identifier: AGPL V3.0
pragma solidity ^0.6.12;

import "@ozUpgradesV3/contracts/access/OwnableUpgradeable.sol";
import "@ozUpgradesV3/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@ozUpgradesV3/contracts/token/ERC20/SafeERC20Upgradeable.sol";
import "@ozUpgradesV3/contracts/math/SafeMathUpgradeable.sol";
import "@ozUpgradesV3/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "@ozUpgradesV3/contracts/cryptography/MerkleProofUpgradeable.sol";

import "../../interfaces/IERC20Burnable.sol";
import "../../interfaces/IERC20Mintable.sol";
import "../../interfaces/delphi/IStakingPool.sol";

contract AdelVAkroVestingSwap is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    event AdelSwapped(address indexed receiver, uint256 adelAmount, uint256 akroAmount);

    //Addresses of affected contracts
    address public akro;
    address public adel;
    address public vakro;

    //Swap settings
    uint256 public minAmountToSwap = 0;
    uint256 public swapRateNumerator = 0; //Amount of vAkro for 1 ADEL - 0 by default
    uint256 public swapRateDenominator = 1; //Akro amount = Adel amount * swapRateNumerator / swapRateDenominator
    //1 Adel = swapRateNumerator/swapRateDenominator Akro

    bool public isVestedSwapEnabled;
    bytes32[] public merkleRootsWalletRewards;
    bytes32[] public merkleRootsTotalRewardsVested;
    mapping(address => uint256[2]) public swappedAdelRewards;

    enum AdelRewardsSource {WALLET, VESTED}

    modifier swapEnabled() {
        require(swapRateNumerator != 0, "Swap is disabled");
        _;
    }

    modifier vestedSwapEnabled() {
        require(isVestedSwapEnabled, "Swap is disabled");
        _;
    }

    modifier enoughAdel(uint256 _adelAmount) {
        require(_adelAmount > 0 && _adelAmount >= minAmountToSwap, "Insufficient ADEL amount");
        _;
    }

    function initialize(
        address _akro,
        address _adel,
        address _vakro
    ) public virtual initializer {
        require(_akro != address(0), "Zero address");
        require(_adel != address(0), "Zero address");
        require(_vakro != address(0), "Zero address");

        __Ownable_init();

        akro = _akro;
        adel = _adel;
        vakro = _vakro;

        isVestedSwapEnabled = true;
    }

    //Setters for the swap tuning

    /**
     * @notice Sets the minimum amount of ADEL which can be swapped. 0 by default
     * @param _minAmount Minimum amount in wei (the least decimals)
     */
    function setMinSwapAmount(uint256 _minAmount) external onlyOwner {
        minAmountToSwap = _minAmount;
    }

    /**
     * @notice Sets the rate of ADEL to vAKRO swap: 1 ADEL = _swapRateNumerator/_swapRateDenominator vAKRO
     * @notice By default is set to 0, that means that swap is disabled
     * @param _swapRateNumerator Numerator for Adel converting. Can be set to 0 - that stops the swap.
     * @param _swapRateDenominator Denominator for Adel converting. Can't be set to 0
     */
    function setSwapRate(uint256 _swapRateNumerator, uint256 _swapRateDenominator) external onlyOwner {
        require(_swapRateDenominator > 0, "Incorrect value");
        swapRateNumerator = _swapRateNumerator;
        swapRateDenominator = _swapRateDenominator;
    }

    /**
     * @notice Sets the Merkle roots for the rewards (on wallet)
     * @param _merkleRootsWalletRewards Array of hashes for on-wallet rewards
     */
    function setMerkleWalletRewardsRoots(bytes32[] memory _merkleRootsWalletRewards) external onlyOwner {
        require(_merkleRootsWalletRewards.length > 0, "Incorrect data");

        if (merkleRootsWalletRewards.length > 0) {
            delete merkleRootsWalletRewards;
        }
        merkleRootsWalletRewards = new bytes32[](_merkleRootsWalletRewards.length);
        merkleRootsWalletRewards = _merkleRootsWalletRewards;
    }

    /**
     * @notice Sets the Merkle roots for the rewards (vested)
     * @param _merkleRootsTotalRewardsVested Array of hashes for vested rewards
     */
    function setMerkleVestedRewardsRoots(bytes32[] memory _merkleRootsTotalRewardsVested) external onlyOwner {
        require(_merkleRootsTotalRewardsVested.length > 0, "Incorrect data");

        if (merkleRootsTotalRewardsVested.length > 0) {
            delete merkleRootsTotalRewardsVested;
        }

        merkleRootsTotalRewardsVested = new bytes32[](_merkleRootsTotalRewardsVested.length);
        merkleRootsTotalRewardsVested = _merkleRootsTotalRewardsVested;
    }

    /**
     * @notice Withdraws all ADEL collected on a Swap contract
     * @param _recepient Recepient of ADEL.
     */
    function withdrawAdel(address _recepient) external onlyOwner {
        require(_recepient != address(0), "Zero address");
        uint256 _adelAmount = IERC20Upgradeable(adel).balanceOf(address(this));
        require(_adelAmount > 0, "Nothing to withdraw");
        IERC20Upgradeable(adel).safeTransfer(_recepient, _adelAmount);
    }

    /**
     * @notice Allows to swap ADEL token from vesting rewards from the wallet for vAKRO
     * @param _adelAmount Amout of ADEL vested rewards the user approves for the swap.
     * @param merkleRootIndex Index of a merkle root to be used for calculations
     * @param adelAllowedToSwap Maximum ADEL allowed for a user to swap
     * @param merkleProofs Array of consiquent merkle hashes
     */
    function swapFromAdelWalletRewards(
        uint256 _adelAmount,
        uint256 merkleRootIndex,
        uint256 adelAllowedToSwap,
        bytes32[] memory merkleProofs
    ) external nonReentrant swapEnabled vestedSwapEnabled enoughAdel(_adelAmount) {
        require(verifyWalletRewardsMerkleProofs(_msgSender(), merkleRootIndex, adelAllowedToSwap, merkleProofs), "Merkle proofs not verified");

        IERC20Upgradeable(adel).safeTransferFrom(_msgSender(), address(this), _adelAmount);

        swapRewards(_adelAmount, adelAllowedToSwap, AdelRewardsSource.WALLET);
    }

    /**
     * @notice Allows to swap ADEL token from not sent vested rewards
     * @param merkleWalletRootIndex Index of a merkle root to be used for calculations (for rewards on wallet)
     * @param adelWalletAllowedToSwap Maximum ADEL allowed for a user to swap (for rewards on wallet)
     * @param merkleWalletProofs Array of consiquent merkle hashes (for rewards on wallet)
     * @param merkleTotalRootIndex Index of a merkle root to be used for calculations
     * @param adelTotalAllowedToSwap Maximum ADEL avested rewards llowed for a user to swap
     * @param merkleTotalProofs Array of consiquent merkle hashes
     */
    function swapFromAdelVestedRewards(
        uint256 merkleWalletRootIndex,
        uint256 adelWalletAllowedToSwap,
        bytes32[] memory merkleWalletProofs,
        uint256 merkleTotalRootIndex,
        uint256 adelTotalAllowedToSwap,
        bytes32[] memory merkleTotalProofs
    ) external nonReentrant swapEnabled vestedSwapEnabled {
        require(
            verifyWalletRewardsMerkleProofs(_msgSender(), merkleWalletRootIndex, adelWalletAllowedToSwap, merkleWalletProofs),
            "Merkle proofs not verified"
        );
        require(
            verifyVestedRewardsMerkleProofs(_msgSender(), merkleTotalRootIndex, adelTotalAllowedToSwap, merkleTotalProofs),
            "Merkle proofs not verified"
        );

        // No ADEL transfers here
        uint256 adelAllowedToSwap = adelTotalAllowedToSwap.sub(adelWalletAllowedToSwap);
        swapRewards(adelAllowedToSwap, adelAllowedToSwap, AdelRewardsSource.VESTED);
    }

    /**
     * @notice Toggles vested swap flag from active to inactive or vice versa
     */
    function toggleVestedSwap() public onlyOwner {
        isVestedSwapEnabled = !isVestedSwapEnabled;
    }

    /**
     * @notice Verifies rewards merkle proofs of user to be elligible for swap
     * @param _account Address of a user
     * @param _merkleRootIndex Index of a merkle root to be used for calculations
     * @param _adelAllowedToSwap Maximum ADEL allowed for a user to swap
     * @param _merkleProofs Array of consiquent merkle hashes
     */
    function verifyWalletRewardsMerkleProofs(
        address _account,
        uint256 _merkleRootIndex,
        uint256 _adelAllowedToSwap,
        bytes32[] memory _merkleProofs
    ) public view virtual returns (bool) {
        require(_merkleProofs.length > 0, "No Merkle proofs");
        require(_merkleRootIndex < merkleRootsWalletRewards.length, "Merkle roots are not set");

        bytes32 node = keccak256(abi.encodePacked(_account, _adelAllowedToSwap));
        return MerkleProofUpgradeable.verify(_merkleProofs, merkleRootsWalletRewards[_merkleRootIndex], node);
    }

    /**
     * @notice Verifies vested rewards merkle proofs of user to be elligible for swap
     * @param _account Address of a user
     * @param _merkleRootIndex Index of a merkle root to be used for calculations
     * @param _adelAllowedToSwap Maximum ADEL allowed for a user to swap
     * @param _merkleProofs Array of consiquent merkle hashes
     */
    function verifyVestedRewardsMerkleProofs(
        address _account,
        uint256 _merkleRootIndex,
        uint256 _adelAllowedToSwap,
        bytes32[] memory _merkleProofs
    ) public view virtual returns (bool) {
        require(_merkleProofs.length > 0, "No Merkle proofs");
        require(_merkleRootIndex < merkleRootsTotalRewardsVested.length, "Merkle roots are not set");

        bytes32 node = keccak256(abi.encodePacked(_account, _adelAllowedToSwap));
        return MerkleProofUpgradeable.verify(_merkleProofs, merkleRootsTotalRewardsVested[_merkleRootIndex], node);
    }

    /**
     * @notice Returns the actual amount of ADEL vesting rewards swapped by a user
     * @param _account Address of a user
     */
    function adelRewardsSwapped(address _account) public view returns (uint256) {
        return swappedAdelRewards[_account][0] + swappedAdelRewards[_account][1];
    }

    /**
     * @notice Internal function to mint vAkro for ADEL from vesting rewards
     * @notice Function lays on the fact, that ADEL is already on the contract
     * @param _adelAmount Amout of ADEL the contract needs to swap.
     * @param _adelAllowedToSwap Maximum ADEL vested rewards from any source allowed to swap for user.
     *                           Any extra ADEL which exceeds this value is sent to the user
     * @param _index Number of the source of vested rewards ADEL (wallet, vested unlock)
     */
    function swapRewards(
        uint256 _adelAmount,
        uint256 _adelAllowedToSwap,
        AdelRewardsSource _index
    ) internal {
        uint256 newAmount = swappedAdelRewards[_msgSender()][uint128(_index)].add(_adelAmount);

        require(newAmount <= _adelAllowedToSwap, "Limit exceeded");
        require(_adelAmount != 0 && _adelAmount >= minAmountToSwap, "Not enough ADEL");

        uint256 vAkroAmount = _adelAmount.mul(swapRateNumerator).div(swapRateDenominator);

        swappedAdelRewards[_msgSender()][uint128(_index)] = newAmount;
        IERC20Mintable(vakro).mint(address(this), vAkroAmount);
        IERC20Upgradeable(vakro).safeTransfer(_msgSender(), vAkroAmount);

        emit AdelSwapped(_msgSender(), _adelAmount, vAkroAmount);
    }
}
