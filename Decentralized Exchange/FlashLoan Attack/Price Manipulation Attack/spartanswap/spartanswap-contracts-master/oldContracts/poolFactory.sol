pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;
import "./IContracts.sol";

contract Pool is iBEP20 {
    using SafeMath for uint256;

    address public BASE;
    address public TOKEN;

    uint256 public one = 10**18;

    // ERC-20 Parameters
    string _name; string _symbol;
    uint256 public override decimals; uint256 public override totalSupply;
    // ERC-20 Mappings
    mapping(address => uint) private _balances;
    mapping(address => mapping(address => uint)) private _allowances;

    uint public genesis;
    uint public baseAmount;
    uint public tokenAmount;
    uint public baseAmountPooled;
    uint public tokenAmountPooled;
    uint public fees;
    uint public volume;
    uint public txCount;

    event AddLiquidity(address member, uint inputBase, uint inputToken, uint unitsIssued);
    event RemoveLiquidity(address member, uint outputBase, uint outputToken, uint unitsClaimed);
    event Swapped(address tokenFrom, address tokenTo, uint inputAmount, uint outputAmount, uint fee, address recipient);

    function _DAO() internal view returns(iDAO) {
        return iBASE(BASE).DAO();
    }

    constructor (address _base, address _token) public payable {
        BASE = _base;
        TOKEN = _token;
        string memory poolName = "SpartanPoolV1-";
        string memory poolSymbol = "SPT1-";
        _name = string(abi.encodePacked(poolName, iBEP20(_token).name()));
        _symbol = string(abi.encodePacked(poolSymbol, iBEP20(_token).symbol()));
        decimals = 18;
        genesis = now;
    }

    //========================================iBEP20=========================================//
    function name() public view override returns (string memory) {
        return _name;
    }
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    // iBEP20 Transfer function
    function transfer(address to, uint256 value) public override returns (bool success) {
        _transfer(msg.sender, to, value);
        return true;
    }
    // iBEP20 Approve function
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    // iBEP20 TransferFrom function
    function transferFrom(address from, address to, uint256 value) public override returns (bool success) {
        require(value <= _allowances[from][msg.sender], 'AllowanceErr');
        _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
        _transfer(from, to, value);
        return true;
    }

    // Internal transfer function
    function _transfer(address _from, address _to, uint256 _value) private {
        require(_balances[_from] >= _value, 'BalanceErr');
        require(_balances[_to] + _value >= _balances[_to], 'BalanceErr');
        _balances[_from] -= _value;
        _balances[_to] += _value;
        emit Transfer(_from, _to, _value);
    }

    // Contract can mint
    function _mint(address account, uint256 amount) internal {
        totalSupply = totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }
    // Burn supply
    function burn(uint256 amount) public virtual {
        _burn(msg.sender, amount);
    }
    function burnFrom(address from, uint256 value) public virtual override {
        require(value <= _allowances[from][msg.sender], 'AllowanceErr');
        _allowances[from][msg.sender] -= value;
        _burn(from, value);
    }
    function _burn(address account, uint256 amount) internal virtual {
        _balances[account] = _balances[account].sub(amount, "BalanceErr");
        totalSupply = totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }


    //==================================================================================//
    // Asset Movement Functions

    // TransferTo function
    function transferTo(address recipient, uint256 amount) public returns (bool) {
                _transfer(tx.origin, recipient, amount);
        return true;
    }

    // Sync internal balances to actual
    function sync() public {
        baseAmount = iBEP20(BASE).balanceOf(address(this));
        tokenAmount = iBEP20(TOKEN).balanceOf(address(this));
    }

    // Add liquidity for self
    function addLiquidity() public returns(uint liquidityUnits){
        liquidityUnits = addLiquidityForMember(msg.sender);
        return liquidityUnits;
    }

    // Add liquidity for a member
    function addLiquidityForMember(address member) public returns(uint liquidityUnits){
        uint256 _actualInputBase = _getAddedBaseAmount();
        uint256 _actualInputToken = _getAddedTokenAmount();
        liquidityUnits = iUTILS(_DAO().UTILS()).calcLiquidityUnits(_actualInputBase, baseAmount, _actualInputToken, tokenAmount, totalSupply);
        _incrementPoolBalances(_actualInputBase, _actualInputToken);
        _mint(member, liquidityUnits);
        emit AddLiquidity(member, _actualInputBase, _actualInputToken, liquidityUnits);
        return liquidityUnits;
    }

    // Remove Liquidity
    function removeLiquidity() public returns (uint outputBase, uint outputToken) {
        return removeLiquidityForMember(msg.sender);
    } 

    // Remove Liquidity for a member
    function removeLiquidityForMember(address member) public returns (uint outputBase, uint outputToken) {
        uint units = balanceOf(member);
        outputBase = iUTILS(_DAO().UTILS()).calcLiquidityShare(units, BASE, address(this), member);
        outputToken = iUTILS(_DAO().UTILS()).calcLiquidityShare(units, TOKEN, address(this), member);
        _decrementPoolBalances(outputBase, outputToken);
        _burn(address(this), units);
        iBEP20(BASE).transfer(member, outputBase);
        iBEP20(TOKEN).transfer(member, outputToken);
        emit RemoveLiquidity(member, outputBase, outputToken, units);
        return (outputBase, outputToken);
    }

    function swap(address token) public returns (uint outputAmount, uint fee){
        (outputAmount, fee) = swapTo(token, msg.sender);
        return (outputAmount, fee);
    }

    function swapTo(address token, address member) public payable returns (uint outputAmount, uint fee) {
        require((token == BASE || token == TOKEN), "Must be BASE or TOKEN");
        address _fromToken; uint _amount;
        if(token == BASE){
            _fromToken = TOKEN;
            _amount = _getAddedTokenAmount();
            (outputAmount, fee) = _swapTokenToBase(_amount);
        } else {
            _fromToken = BASE;
            _amount = _getAddedBaseAmount();
            (outputAmount, fee) = _swapBaseToToken(_amount);
        }
        emit Swapped(_fromToken, token, _amount, outputAmount, fee, member);
        iBEP20(token).transfer(member, outputAmount);
        return (outputAmount, fee);
    }

    function _getAddedBaseAmount() internal view returns(uint256 _actual){
        uint _baseBalance = iBEP20(BASE).balanceOf(address(this)); 
        if(_baseBalance > baseAmount){
            _actual = _baseBalance.sub(baseAmount);
        } else {
            _actual = 0;
        }
        return _actual;
    }
    function _getAddedTokenAmount() internal view returns(uint256 _actual){
        uint _tokenBalance = iBEP20(TOKEN).balanceOf(address(this)); 
        if(_tokenBalance > tokenAmount){
            _actual = _tokenBalance.sub(tokenAmount);
        } else {
            _actual = 0;
        }
        return _actual;
    }

    function _swapBaseToToken(uint256 _x) internal returns (uint256 _y, uint256 _fee){
        uint256 _X = baseAmount;
        uint256 _Y = tokenAmount;
        _y =  iUTILS(_DAO().UTILS()).calcSwapOutput(_x, _X, _Y);
        _fee = iUTILS(_DAO().UTILS()).calcSwapFee(_x, _X, _Y);
        _setPoolAmounts(_X.add(_x), _Y.sub(_y));
        _addPoolMetrics(_y+_fee, _fee, false);
        return (_y, _fee);
    }

    function _swapTokenToBase(uint256 _x) internal returns (uint256 _y, uint256 _fee){
        uint256 _X = tokenAmount;
        uint256 _Y = baseAmount;
        _y =  iUTILS(_DAO().UTILS()).calcSwapOutput(_x, _X, _Y);
        _fee = iUTILS(_DAO().UTILS()).calcSwapFee(_x, _X, _Y);
        _setPoolAmounts(_Y.sub(_y), _X.add(_x));
        _addPoolMetrics(_y+_fee, _fee, true);
        return (_y, _fee);
    }

    //==================================================================================//
    // Data Model


    // Increment internal balances
    function _incrementPoolBalances(uint _baseAmount, uint _tokenAmount) internal  {
        baseAmount += _baseAmount;
        tokenAmount += _tokenAmount;
        baseAmountPooled += _baseAmount;
        tokenAmountPooled += _tokenAmount; 
    }
    function _setPoolAmounts(uint256 _baseAmount, uint256 _tokenAmount) internal  {
        baseAmount = _baseAmount;
        tokenAmount = _tokenAmount; 
    }

    // Decrement internal balances
    function _decrementPoolBalances(uint _baseAmount, uint _tokenAmount) internal  {
        uint _removedBase = iUTILS(_DAO().UTILS()).calcShare(_baseAmount, baseAmount, baseAmountPooled);
        uint _removedToken = iUTILS(_DAO().UTILS()).calcShare(_tokenAmount, tokenAmount, tokenAmountPooled);
        baseAmountPooled = baseAmountPooled.sub(_removedBase);
        tokenAmountPooled = tokenAmountPooled.sub(_removedToken); 
        baseAmount = baseAmount.sub(_baseAmount);
        tokenAmount = tokenAmount.sub(_tokenAmount); 
    }

    function _addPoolMetrics(uint256 _volume, uint256 _fee, bool _toBase) internal {
        if(_toBase){
            volume += _volume;
            fees += _fee;
        } else {
            volume += iUTILS(_DAO().UTILS()).calcSpotValueInBaseWithPool(address(this), _volume);
            fees += iUTILS(_DAO().UTILS()).calcSpotValueInBaseWithPool(address(this), _fee);
        }
        txCount += 1;
    }
}
