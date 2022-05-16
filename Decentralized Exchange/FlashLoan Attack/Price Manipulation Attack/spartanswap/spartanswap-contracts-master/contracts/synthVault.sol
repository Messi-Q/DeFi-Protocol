// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;
import "./iBEP20.sol";
import "./iDAO.sol";
import "./iBASE.sol";
import "./iPOOL.sol";
import "./iSYNTH.sol";
import "./iUTILS.sol";
import "./iRESERVE.sol";
import "./iSYNTHFACTORY.sol";
import "./iPOOLFACTORY.sol";
import "./TransferHelper.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
contract SynthVault is ReentrancyGuard{
    address public immutable BASE;      // Address of SPARTA base token contract
    address public DEPLOYER;            // Address that deployed the contract | can be purged to address(0)

    uint256 public minimumDepositTime;  // Withdrawal lockout period; intended to be 1 hour
    uint256 public erasToEarn;          // Amount of eras that make up the targeted RESERVE depletion; regulates incentives
    uint256 public vaultClaim;          // The SynthVaults's portion of rewards; intended to be ~10% initially
    uint public lastMonth;              // Timestamp of the start of current metric period (For UI)
    uint public immutable genesis;      // Timestamp from when the synth was first deployed (For UI)

    uint256 public map30DVaultRevenue;  // Tally of revenue during current incomplete metric period (for UI)
    uint256 public mapPast30DVaultRevenue; // Tally of revenue from last full metric period (for UI)
    uint256 [] public revenueArray;     // Array of the last two metric periods (For UI)

    // Restrict access
    modifier onlyDAO() {
        require(msg.sender == DEPLOYER || msg.sender == _DAO().DAO());
        _;
    }
    // Restrict access
    modifier onlyPROTOCOL() {
        require(iPOOLFACTORY(_DAO().POOLFACTORY()).isCuratedPool(msg.sender) == true); 
        _;
    }

    constructor(address _base) {
        BASE = _base;
        DEPLOYER = msg.sender;
        erasToEarn = 30;
        minimumDepositTime = 3600; //  1hr for mainnet 3600
        vaultClaim = 1000;
        genesis = block.timestamp;
        lastMonth = 0;
    }

    function _DAO() internal view returns(iDAO) {
        return iBASE(BASE).DAO(); // Get the DAO address reported by Sparta base contract
    }

    mapping(address => mapping(address => uint256)) private mapMemberSynth_deposit;
    mapping(address => uint256) public mapTotalSynth_balance;

    mapping(address => mapping(address => uint256)) private mapMemberSynth_lastTime;
    mapping(address => uint256) public mapMember_depositTime;

    event MemberDeposits(
        address indexed synth,
        address indexed member,
        uint256 newDeposit
    );
    event MemberWithdraws(
        address indexed synth,
        address indexed member,
        uint256 amount
    );
    event MemberHarvests(
        address indexed synth,
        address indexed member,
        uint256 amount
    );
    
    // Can purge deployer once DAO is stable and final
    function purgeDeployer() external onlyDAO {
        DEPLOYER = address(0);
    }

    function setParams(uint256 _erasToEarn, uint256 _minTime, uint256 _vaultClaim) external onlyDAO {
        erasToEarn = _erasToEarn;
        minimumDepositTime = _minTime;
        vaultClaim = _vaultClaim;
    }

    //====================================== DEPOSIT ========================================//
     function depositForMember(address synth, address member) external onlyPROTOCOL {
        require(iSYNTHFACTORY(_DAO().SYNTHFACTORY()).isSynth(synth), '!Synth'); // Must be a valid & active synth
        uint256 amount = _getAddedSynthAmount(synth);
        _deposit(synth, member, amount); // Assess and record the deposit
    }

    // Contract deposits Synths in the SynthVault for user
    function deposit(address synth, uint256 amount) external {
        require(iSYNTHFACTORY(_DAO().SYNTHFACTORY()).isSynth(synth), '!Synth'); // Must be a valid & active synth
        TransferHelper.safeTransferFrom(synth, msg.sender, address(this), amount);
        _deposit(synth, msg.sender, amount); // Assess and record the deposit
    }

    // Check and record the deposit
    function _deposit(address _synth, address _member, uint256 _amount) internal {
        require(_amount > 0, '!VALID'); // Must be a valid amount
        require((block.timestamp > mapMemberSynth_lastTime[_member][_synth] + 10), '!DepositTime');// Deposits every hour
        mapMemberSynth_lastTime[_member][_synth] = block.timestamp; // Record deposit time (scope: member -> synth)
        mapMember_depositTime[_member] = block.timestamp; // Record deposit time (scope: member)
        mapMemberSynth_deposit[_member][_synth] += _amount; // Update vault balance (scope: member -> synth
        mapTotalSynth_balance[_synth] +=_amount; // Update vault balance (scope: vault -> synth)
        emit MemberDeposits(_synth, _member, _amount);
    }

    //====================================== HARVEST ========================================//

    // User batch harvests synths via array of synth addresses
    function harvestAll(address [] memory synthAssets) external returns (bool) {
        for(uint i = 0; i < synthAssets.length; i++){
            harvestSingle(synthAssets[i]);
        }
        return true;
    }

    // User harvests available rewards of the chosen asset
   function harvestSingle(address synth) public returns (bool) { 
        require(iSYNTHFACTORY(_DAO().SYNTHFACTORY()).isSynth(synth), '!Synth'); // Must be a valid & active synth
        uint256 reward = calcCurrentReward(synth, msg.sender); // Calc user's current SPARTA reward
        if(reward > 0){
            require((block.timestamp > mapMemberSynth_lastTime[msg.sender][synth] + 10), 'LOCKED');  // Must not harvest before lockup period passed
            address _poolOUT = iSYNTH(synth).POOL(); // Get pool address
            iPOOL(_poolOUT).sync(); // Sync here to prevent using SYNTH.transfer() to bypass lockup
            uint256 steamAvailable = iPOOL(_poolOUT).stirCauldron(synth); 
            uint256 swapOut = iUTILS(_DAO().UTILS()).calcSwapValueInToken(iPOOL(_poolOUT).TOKEN(), reward);  
            if(steamAvailable < swapOut){
                iRESERVE(_DAO().RESERVE()).grantFunds(reward, msg.sender); // Tsf SPARTA (Reserve -> Pool)
                mapMemberSynth_lastTime[msg.sender][synth] = block.timestamp; // Set last harvest time as now
            }else{
                iRESERVE(_DAO().RESERVE()).grantFunds(reward, _poolOUT); // Tsf SPARTA (Reserve -> Pool)
                iPOOL(_poolOUT).mintSynth(msg.sender); // Mint SYNTH (Pool -> Synth -> SynthVault) 
            }
            _addVaultMetrics(reward); // Add to the revenue metrics (for UI)
            emit MemberHarvests(synth, msg.sender, reward);
        }
        return true;
    }

    // Calculate the user's current incentive-claim per era based on selected asset
    function calcCurrentReward(address synth, address member) public returns (uint256 reward){
        if (block.timestamp > mapMemberSynth_lastTime[member][synth]) {
            uint256 _secondsSinceClaim = block.timestamp - mapMemberSynth_lastTime[member][synth]; // Get seconds passed since last claim
            (uint256 _share, uint256 _vaultReward) = calcReward(synth,member); // Get member's share of RESERVE incentives
            reward = (_share * _secondsSinceClaim) / iBASE(BASE).secondsPerEra(); // User's share times eras since they last claimed
            if(reward > _vaultReward){
                reward = _vaultReward; // User cannot claim more than the vaultClaim limit
            }
        }
        return reward;
    }

    // Calculate the user's current total claimable incentive
    function calcReward(address _synth, address member) public returns (uint256 _share, uint256 _vaultReward) {
        (uint256 weight, uint256 synthWeight, uint256 totalSynthWeight) = getMemberSynthWeight(_synth, member);
        uint256 _reserve = reserveBASE() / erasToEarn; // Aim to deplete reserve over a number of days
        uint256 synthCount = iSYNTHFACTORY(_DAO().SYNTHFACTORY()).synthCount(); // Get count of valid synth assets
        _vaultReward = (_reserve * vaultClaim) / synthCount / 10000; // Get the vaults's total share of the reserve
        uint256 synthRewardShare = iUTILS(_DAO().UTILS()).calcShare(synthWeight, totalSynthWeight, _vaultReward); // Get the synth's total share of the reward
        _share = iUTILS(_DAO().UTILS()).calcShare(weight, synthWeight, synthRewardShare); // Get member's current claimable reward
    }

    // Update a member's weight 
    function getMemberSynthWeight(address _synth, address member) public returns (uint256 memberSynthWeight, uint256 synthWeight, uint256 totalSynthWeight) {
        require(iRESERVE(_DAO().RESERVE()).globalFreeze() != true, '!SAFE'); // Must not be a global freeze
        address [] memory _vaultAssets = iPOOLFACTORY(_DAO().POOLFACTORY()).getVaultAssets(); // Get list of vault enabled assets
        for(uint i = 0; i < _vaultAssets.length; i++){
            address synth = iPOOL(_vaultAssets[i]).SYNTH(); // Get the relevant syntyh address for each vault asset
            if (synth != address(0)) {
                totalSynthWeight += iUTILS(_DAO().UTILS()).calcSpotValueInBaseWithSynth(synth, mapTotalSynth_balance[synth]); // Get the cumulative weight (scope: synthVault)
            }
        }
        synthWeight = iUTILS(_DAO().UTILS()).calcSpotValueInBaseWithSynth(_synth, mapTotalSynth_balance[_synth]); // Get current weight (scope: vault -> synth)
        memberSynthWeight = iUTILS(_DAO().UTILS()).calcSpotValueInBaseWithSynth(_synth, mapMemberSynth_deposit[member][_synth]); // Get current weight (scope: member -> synth)
        return (memberSynthWeight, synthWeight, totalSynthWeight);
    }

    function _getAddedSynthAmount(address _synth) internal view returns(uint256 _actual){
        uint _synthBalance = iBEP20(_synth).balanceOf(address(this));
        if(_synthBalance > mapTotalSynth_balance[_synth]){
            _actual = _synthBalance - mapTotalSynth_balance[_synth];
        } else {
            _actual = 0;
        }
        return _actual;
    }


    //====================================== WITHDRAW ========================================//

    // User withdraws a percentage of their synths from the vault
    function withdraw(address synth, uint256 basisPoints) external nonReentrant {
        require(basisPoints > 0, '!VALID'); // Basis points must be valid
        require((block.timestamp > mapMember_depositTime[msg.sender] + minimumDepositTime), "lockout"); // Must not withdraw before lockup period passed
        uint256 redeemedAmount = iUTILS(_DAO().UTILS()).calcPart(basisPoints, mapMemberSynth_deposit[msg.sender][synth]); // Calc amount to withdraw
        mapMemberSynth_deposit[msg.sender][synth] -= redeemedAmount; // Update vault balance (scope: member -> synth)
        mapTotalSynth_balance[synth] -= redeemedAmount; // Update vault balance (scope: vault -> synth)
        TransferHelper.safeTransfer( synth,  msg.sender,  redeemedAmount);
        emit MemberWithdraws(synth, msg.sender, redeemedAmount);
    }


    //================================ Helper Functions ===============================//

    function reserveBASE() public view returns (uint256) {
        return iBEP20(BASE).balanceOf(_DAO().RESERVE());
    }

    function getMemberDeposit(address member, address synth) external view returns (uint256){
        return mapMemberSynth_deposit[member][synth];
    }
    function getTotalDeposit(address synth) external view returns (uint256){
        return mapTotalSynth_balance[synth];
    }

    function getMemberLastSynthTime(address synth, address member) external view returns (uint256){
        return mapMemberSynth_lastTime[member][synth];
    }

    function setReserveClaim(uint256 _setSynthClaim) external onlyDAO {
        vaultClaim = _setSynthClaim;
    }

    //=============================== SynthVault Metrics =================================//

    function _addVaultMetrics(uint256 _fee) internal {
        if(lastMonth == 0){
            lastMonth = block.timestamp;
        }
        if(block.timestamp <= lastMonth + 2592000){ // 30 days
            map30DVaultRevenue = map30DVaultRevenue + _fee;
        } else {
            lastMonth = block.timestamp;
            mapPast30DVaultRevenue = map30DVaultRevenue;
            _addRevenue(mapPast30DVaultRevenue);
            map30DVaultRevenue = _fee;
        }
    }

    function _addRevenue(uint _totalRev) internal {
        if(!(revenueArray.length == 2)){
            revenueArray.push(_totalRev);
        } else {
            _addFee(_totalRev);
        }
    }

    function _addFee(uint _rev) internal {
        uint [] memory _revArray = revenueArray;
        uint _n = _revArray.length; // 2
        for (uint i = _n - 1; i > 0; i--) {
            _revArray[i] = _revArray[i - 1];
        }
        _revArray[0] = _rev;
        revenueArray = _revArray;
    }
}
