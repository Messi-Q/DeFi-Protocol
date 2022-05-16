
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;
pragma experimental ABIEncoderV2;
import "@nomiclabs/buidler/console.sol";
//iBEP20 Interface
interface iBEP20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint);
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address, uint) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}
interface iBASE {
    function claim(address asset, uint256 amount) external payable;  
    function DAO() external view returns (iDAO);
    function burn(uint) external;
}
interface iROUTER {
    function addLiquidity(uint inputBase, uint inputToken, address token) external payable returns (uint units);
}
interface iUTILS {
    function calcValueInBaseWithPool(address pool, uint256 amount) external view returns (uint256 value);
    function calcValueInBase(address token, uint256 amount) external view returns (uint256 value);
    function getPool(address token)external view returns (address value);
}
interface iDAO {
    function ROUTER() external view returns(address);
    function UTILS() external view returns(address);
}


library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
}
    //======================================SPARTA=========================================//
contract BondV2M is iBEP20 {
    using SafeMath for uint256;

    // ERC-20 Parameters
    string public override name; string public override symbol;
    uint256 public override decimals; uint256 public override totalSupply;  

    // ERC-20 Mappings
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;


    struct ListedAssets {
        bool isListed;
        address[] members;
        mapping(address => bool) isMember;
        mapping(address => uint256) bondedLP;
        mapping(address => uint256) claimRate;
        mapping(address => uint256) lastBlockTime;
    }
    struct MemberDetails {
        bool isMember;
        uint256 bondedLP;
        uint256 claimRate;
        uint256 lastBlockTime;
    }

  // Parameters
    address public BASE;
    address [] public arrayMembers;
    address public DEPLOYER;
    address [] listedBondAssets;
    uint256 baseSupply;
    uint256 public bondingPeriodSeconds = 31536000;
    uint256 public emissionBP = 2500;
    uint256 private basisPoints = 10000;

    mapping(address => ListedAssets) public mapAddress_listedAssets;
    mapping(address => bool) public isListed;
    

    event ListedAsset(address indexed DEPLOYER, address indexed asset);
    event DepositAsset(address indexed owner, uint256 indexed depositAmount, uint256 indexed bondedLP);

    modifier onlyDeployer() {
        require(msg.sender == DEPLOYER, "Must be DAO");
        _;
    }

    //=====================================CREATION=========================================//
    // Constructor
    constructor(address _base) public {
        BASE = _base;
        name = "SpartanBondTokenV2";
        symbol  = "SPT-BOND-V2";
        decimals = 18;
        DEPLOYER = msg.sender;
        totalSupply = 1 * (10 ** 18);
        _balances[address(this)] = totalSupply;
        emit Transfer(address(0), address(this), totalSupply);

    }
    function _DAO() internal view returns(iDAO) {
        return iBASE(BASE).DAO();
    }
    //========================================iBEP20=========================================//
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    // iBEP20 Transfer function
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    // iBEP20 Approve, change allowance functions
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "iBEP20: decreased allowance below zero"));
        return true;
    }
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "iBEP20: approve from the zero address");
        require(spender != address(0), "iBEP20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    // iBEP20 TransferFrom function
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "iBEP20: transfer amount exceeds allowance"));
        return true;
    }

    // TransferTo function
    function transferTo(address recipient, uint256 amount) public returns (bool) {
        _transfer(tx.origin, recipient, amount);
        return true;
    }

    // Internal transfer function
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "iBEP20: transfer from the zero address");
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }
    function _mint(address _account, uint256 _amount) internal virtual {
        require(_account != address(0), "iBEP20: mint to the zero address");
        totalSupply = totalSupply.add(_amount);
        _balances[_account] = _balances[_account].add(_amount);
        emit Transfer(address(0), _account, _amount);
    }
    function mintBond() public onlyDeployer returns (bool) {
        uint256 amount =1*10**18;
        _mint(address(this), amount);
       return true;
    }

    function burnBond() public returns (bool success){
        require(totalSupply >= 1, 'burnt already');
        _approve(address(this), BASE, totalSupply);
        iBASE(BASE).claim(address(this), totalSupply);
        totalSupply = totalSupply.sub(totalSupply);
        baseSupply = iBEP20(BASE).balanceOf(address(this));
        iBEP20(BASE).approve(_DAO().ROUTER(), baseSupply);
        return true;
    }
    //====================DEPLOYER=========================
    function listBondAsset(address asset) public onlyDeployer returns (bool){
         if(!isListed[asset]){
            isListed[asset] = true;
            listedBondAssets.push(asset);
        }
        emit ListedAsset(msg.sender, asset);
        return true;
    }
    function changeEmissionBP(uint256 bp) public onlyDeployer returns (bool){
        emissionBP = bp;
        return true;
    }
    function changeBondingPeriod(uint256 bondingSeconds) public onlyDeployer returns (bool){
        bondingPeriodSeconds = bondingSeconds;
        return true;
    }
    function burnBalance() public onlyDeployer {
        uint256 baseBal = iBEP20(BASE).balanceOf(address(this));
        iBASE(BASE).burn(baseBal);
    }


     function deposit(address asset, uint amount) public payable returns (bool success) {
        require(amount > 0, 'must get asset');
        require(isListed[asset], 'must be listed');
        uint liquidityUnits; address _pool = iUTILS(_DAO().UTILS()).getPool(asset); uint lpBondedAdjusted;
        liquidityUnits = handleTransferIn(asset, amount);
        uint lpAdjusted = liquidityUnits.mul(emissionBP).div(basisPoints);
        lpBondedAdjusted = liquidityUnits.sub(lpAdjusted);
        if(!mapAddress_listedAssets[asset].isMember[msg.sender]){
          mapAddress_listedAssets[asset].isMember[msg.sender] = true;
          arrayMembers.push(msg.sender);
          mapAddress_listedAssets[asset].members.push(msg.sender);
        }
        mapAddress_listedAssets[asset].bondedLP[msg.sender] = mapAddress_listedAssets[asset].bondedLP[msg.sender].add(lpBondedAdjusted);
        mapAddress_listedAssets[asset].lastBlockTime[msg.sender] = block.timestamp;
        mapAddress_listedAssets[asset].claimRate[msg.sender] = mapAddress_listedAssets[asset].bondedLP[msg.sender].div(bondingPeriodSeconds);
        iBEP20(_pool).transfer(msg.sender, lpAdjusted);
        emit DepositAsset(msg.sender, amount, lpAdjusted);
        return true;
    }

    function handleTransferIn(address _token, uint _amount) internal returns (uint LPunits){
        uint spartaAllocation;
        spartaAllocation = iUTILS(_DAO().UTILS()).calcValueInBase(_token, _amount);
        if(_token == address(0)){
                require((_amount == msg.value), "InputErr");
                LPunits = iROUTER(_DAO().ROUTER()).addLiquidity{value:_amount}(spartaAllocation, _amount, _token);
            } else {
                iBEP20(_token).transferFrom(msg.sender, address(this), _amount);
                if(iBEP20(_token).allowance(address(this), _DAO().ROUTER()) < _amount){
                    uint256 approvalTNK = iBEP20(_token).totalSupply();  
                    iBEP20(_token).approve(_DAO().ROUTER(), approvalTNK);  
                }
                LPunits = iROUTER(_DAO().ROUTER()).addLiquidity(spartaAllocation, _amount, _token);
            }
    }
    //============================== CLAIM LP TOKENS ================================//

    function claim(address asset) public returns(bool){
        require(mapAddress_listedAssets[asset].bondedLP[msg.sender] > 0, 'must have bonded lps');
        require(mapAddress_listedAssets[asset].isMember[msg.sender], 'must have deposited first');
        uint256 claimable = calcClaimBondedLP(msg.sender, asset); 
        address _pool = iUTILS(_DAO().UTILS()).getPool(asset);
        require(claimable <= mapAddress_listedAssets[asset].bondedLP[msg.sender],'attempted to overclaim');
        mapAddress_listedAssets[asset].lastBlockTime[msg.sender] = block.timestamp;
        mapAddress_listedAssets[asset].bondedLP[msg.sender] = mapAddress_listedAssets[asset].bondedLP[msg.sender].sub(claimable);
        iBEP20(_pool).transfer(msg.sender, claimable);
        return true;
    }
    

    function calcClaimBondedLP(address bondedMember, address asset) public returns (uint256 claimAmount){
        uint256 secondsSinceClaim = block.timestamp.sub(mapAddress_listedAssets[asset].lastBlockTime[bondedMember]); // Get time since last claim
        uint256 rate = mapAddress_listedAssets[asset].claimRate[bondedMember];
        if(secondsSinceClaim >= bondingPeriodSeconds){
            mapAddress_listedAssets[asset].claimRate[bondedMember] = 0;
            return claimAmount = mapAddress_listedAssets[asset].bondedLP[bondedMember];
        }else{
            return claimAmount = secondsSinceClaim.mul(rate);
        }
        
    }



    //============================== HELPERS ================================//
    function assetListedCount() public view returns (uint256 count){
        return listedBondAssets.length;
    }
    function allListedAssets() public view returns (address[] memory _allListedAssets){
        return listedBondAssets;
    }
    function memberCount() public view returns (uint256 count){
        return arrayMembers.length;
    }
    function allMembers() public view returns (address[] memory _allMembers){
        return arrayMembers;
    }

    function getMemberDetails(address member, address asset) public view returns (MemberDetails memory memberDetails){
        memberDetails.isMember = mapAddress_listedAssets[asset].isMember[member];
        memberDetails.bondedLP = mapAddress_listedAssets[asset].bondedLP[member];
        memberDetails.claimRate = mapAddress_listedAssets[asset].claimRate[member];
        memberDetails.lastBlockTime = mapAddress_listedAssets[asset].lastBlockTime[member];
        return memberDetails;
    }
    
}