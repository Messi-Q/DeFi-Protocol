// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

// "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount)
    external
    returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
    external
    view
    returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount)
    public
    virtual
    override
    returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender)
    public
    view
    virtual
    override
    returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount)
    public
    virtual
    override
    returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue)
    public
    virtual
    returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
    public
    virtual
    returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(
            amount,
            "ERC20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(
            amount,
            "ERC20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/SafeERC20.sol";
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data)
    internal
    returns (bytes memory)
    {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return
        functionCallWithValue(
            target,
            data,
            value,
            "Address: low-level call with value failed"
        );
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(
            address(this).balance >= value,
            "Address: insufficient balance for call"
        );
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) =
        target.call{value: value}(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data)
    internal
    view
    returns (bytes memory)
    {
        return
        functionStaticCall(
            target,
            data,
            "Address: low-level static call failed"
        );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(address target, bytes memory data)
    internal
    returns (bytes memory)
    {
        return
        functionDelegateCall(
            target,
            data,
            "Address: low-level delegate call failed"
        );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance =
        token.allowance(address(this), spender).add(value);
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance =
        token.allowance(address(this), spender).sub(
            value,
            "SafeERC20: decreased allowance below zero"
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata =
        address(token).functionCall(
            data,
            "SafeERC20: low-level call failed"
        );
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}

// "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol";
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Pausable.sol";
contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() internal {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

interface IPancakeRouter01 {
    // function factory() external pure returns (address);

    // function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
    external
    returns (
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    // function addLiquidityETH(
    //     address token,
    //     uint256 amountTokenDesired,
    //     uint256 amountTokenMin,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline
    // )
    //     external
    //     payable
    //     returns (
    //         uint256 amountToken,
    //         uint256 amountETH,
    //         uint256 liquidity
    //     );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    // function removeLiquidityETH(
    //     address token,
    //     uint256 liquidity,
    //     uint256 amountTokenMin,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256 amountToken, uint256 amountETH);

    // function removeLiquidityWithPermit(
    //     address tokenA,
    //     address tokenB,
    //     uint256 liquidity,
    //     uint256 amountAMin,
    //     uint256 amountBMin,
    //     address to,
    //     uint256 deadline,
    //     bool approveMax,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) external returns (uint256 amountA, uint256 amountB);

    // function removeLiquidityETHWithPermit(
    //     address token,
    //     uint256 liquidity,
    //     uint256 amountTokenMin,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline,
    //     bool approveMax,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

     function swapTokensForExactTokens(
         uint256 amountOut,
         uint256 amountInMax,
         address[] calldata path,
         address to,
         uint256 deadline
     ) external returns (uint256[] memory amounts);

    // function swapExactETHForTokens(
    //     uint256 amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // ) external payable returns (uint256[] memory amounts);

    // function swapTokensForExactETH(
    //     uint256 amountOut,
    //     uint256 amountInMax,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256[] memory amounts);

    // function swapExactTokensForETH(
    //     uint256 amountIn,
    //     uint256 amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256[] memory amounts);

    // function swapETHForExactTokens(
    //     uint256 amountOut,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // ) external payable returns (uint256[] memory amounts);

    // function quote(
    //     uint256 amountA,
    //     uint256 reserveA,
    //     uint256 reserveB
    // ) external pure returns (uint256 amountB);

    // function getAmountOut(
    //     uint256 amountIn,
    //     uint256 reserveIn,
    //     uint256 reserveOut
    // ) external pure returns (uint256 amountOut);

    // function getAmountIn(
    //     uint256 amountOut,
    //     uint256 reserveIn,
    //     uint256 reserveOut
    // ) external pure returns (uint256 amountIn);

    // function getAmountsOut(uint256 amountIn, address[] calldata path)
    //     external
    //     view
    //     returns (uint256[] memory amounts);

    // function getAmountsIn(uint256 amountOut, address[] calldata path)
    //     external
    //     view
    //     returns (uint256[] memory amounts);
}

interface IPancakeRouter02 is IPancakeRouter01 {
    // function removeLiquidityETHSupportingFeeOnTransferTokens(
    //     address token,
    //     uint256 liquidity,
    //     uint256 amountTokenMin,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256 amountETH);
    // function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
    //     address token,
    //     uint256 liquidity,
    //     uint256 amountTokenMin,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline,
    //     bool approveMax,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) external returns (uint256 amountETH);
    // function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    //     uint256 amountIn,
    //     uint256 amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // ) external;
    // function swapExactETHForTokensSupportingFeeOnTransferTokens(
    //     uint256 amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // ) external payable;
    // function swapExactTokensForETHSupportingFeeOnTransferTokens(
    //     uint256 amountIn,
    //     uint256 amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // ) external;
}
interface IOracle {
    function getUnderlyingPrice(address vToken) external view returns (uint);
}
interface IVenusDistribution {
    function claimVenus(address holder) external;

    function enterMarkets(address[] memory _vtokens) external;

    function exitMarket(address _vtoken) external;

    function getAssetsIn(address account)
    external
    view
    returns (address[] memory);

    function oracle() view external returns (address);

    function getAccountLiquidity(address account)
    external
    view
    returns (
        uint256,
        uint256,
        uint256
    );
}

interface IWBNB is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

interface IVBNB {
    function mint() external payable;

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function repayBorrow() external payable;

    // function getAccountSnapshot(address account)
    //     external
    //     view
    //     returns (
    //         uint256,
    //         uint256,
    //         uint256,
    //         uint256
    //     );

    function balanceOfUnderlying(address owner) external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);
}

interface IVToken is IERC20 {
    function underlying() external returns (address);

    function mint(uint256 mintAmount) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function repayBorrow(uint256 repayAmount) external returns (uint256);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);
}

contract DfVenusFarm is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    bool public wantIsWBNB = false;
    address public baseAddress;
    address public boostedAddress;

    address public vBoostedTokenAddress;
    address public vBaseTokenAddress;
    
    address[] public venusMarkets;
    address public uniRouterAddress;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant venusAddress =
    0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63;
    address public constant earnedAddress = venusAddress;
    address public constant venusDistributionAddress =
    0xfD36E2c2a6789Db23113685031d7F16329158384;

    uint256 public sharesTotal = 0;
    uint256 public lastEarnBlock = 0;

    uint256 public controllerFee = 2000;
    uint256 public constant controllerFeeMax = 10000; // 100 = 1%
    uint256 public constant controllerFeeUL = 5000; // 50% upperlimit

    address[] public venusToWantPath;

    /**
     * @dev Variables that can be changed to config profitability and risk:
     * {borrowRate}          - What % of our collateral do we borrow per leverage level.
     * {borrowDepth}         - How many levels of leverage do we take.
     * {BORROW_RATE_MAX}     - A limit on how much we can push borrow risk.
     * {BORROW_DEPTH_MAX}    - A limit on how many steps we can leverage.
     */
    uint256 public borrowRate = 585;
    uint256 public borrowDepth = 3;
    uint256 public constant BORROW_RATE_MAX = 595;
    uint256 public constant BORROW_RATE_MAX_HARD = 599;
    uint256 public constant BORROW_DEPTH_MAX = 6;
    bool onlyGov = true;

    uint256 public supplyBalBase = 0; // Cached want supplied to venus base asset
    uint256 public supplyBal = 0; // Cached want supplied to venus
    uint256 public borrowBal = 0; // Cached want borrowed from venus
    uint256 public supplyBalTargeted = 0; // Cached targetted want supplied to venus to achieve desired leverage
    uint256 public supplyBalMin = 0;

    mapping (address => uint256) public userShares;
    /**
     * @dev Events that the contract emits
     */
    event StratRebalance(uint256 _borrowRate, uint256 _borrowDepth);

    constructor() public {
        boostedAddress = address(0x47bead2563dcbf3bf2c9407fea4dc236faba485a); // SXP
        baseAddress = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);// BNB

        vBoostedTokenAddress = address(0x2ff3d0f6990a40261c66e1ff2017acbc282eb6d0); // vSXP
        vBaseTokenAddress = address(0xa07c5b74c9b40447a954e1466938b865b6bbea36); //vBNB
        
        venusToWantPath = [venusAddress, wbnbAddress, boostedAddress];
        
        venusMarkets = [vBoostedTokenAddress, vBoostedTokenAddress];
        uniRouterAddress = address(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);

        transferOwnership(msg.sender);

        IERC20(venusAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(boostedAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(baseAddress).safeApprove(uniRouterAddress, uint256(-1));
        if (!wantIsWBNB) {
            IERC20(baseAddress).safeApprove(vBaseTokenAddress, uint256(-1));
        }
        IERC20(boostedAddress).safeApprove(vBoostedTokenAddress, uint256(-1));

        IVenusDistribution(venusDistributionAddress).enterMarkets(venusMarkets);
    }

    function _supply(address vToken, uint256 _amount) internal {
        if (wantIsWBNB) {
            IVBNB(vToken).mint{value: _amount}();
        } else {
            IVToken(vToken).mint(_amount);
        }
    }

    function _removeSupply(address vToken, uint256 _amount) internal {
        IVToken(vBoostedTokenAddress).redeemUnderlying(_amount);
    }

    function _borrow(address vToken, uint256 _amount) internal {
        IVToken(vToken).borrow(_amount);
    }

    function _repayBorrow(address vToken, uint256 _amount) internal {
        if (wantIsWBNB) {
            IVBNB(vToken).repayBorrow{value: _amount}();
        } else {
            IVToken(vToken).repayBorrow(_amount);
        }
    }

    function deposit(uint256 _wantAmt)
    public
    nonReentrant
    whenNotPaused
    returns (uint256)
    {
        updateBalance();

        uint256 sharesAdded = _wantAmt;
        if (wantLockedTotal() > 0 && sharesTotal > 0) {
            sharesAdded = _wantAmt
            .mul(sharesTotal)
            .div(wantLockedTotal());
        }

        userShares[msg.sender] = userShares[msg.sender].add(sharesAdded);

        sharesTotal = sharesTotal.add(sharesAdded);

        IERC20(boostedAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        _farm(true);

        return sharesAdded;
    }

    function farm(bool _withLev) public nonReentrant {
        _farm(_withLev);
    }

    function _farm(bool _withLev) internal {
        if (wantIsWBNB) {
            _unwrapBNB(); // WBNB -> BNB. Venus accepts BNB, not WBNB.
            _leverage(address(this).balance, _withLev);
        } else {
            _leverage(wantLockedInHere(), _withLev);
        }

        updateBalance();

        deleverageUntilNotOverLevered(); // It is possible to still be over-levered after depositing.
    }

    function baseToBoosted(uint256 _amount) internal returns (uint256) {
        IOracle oracle = IOracle(IVenusDistribution(venusDistributionAddress).oracle());
        return oracle.getUnderlyingPrice(vBaseTokenAddress)
            .mul(1e18)
            .div(_amount)
            .mul(1e18)
            .div(oracle.getUnderlyingPrice(vBoostedTokenAddress));
    }

    function boostedToBase(uint256 _amount) internal returns (uint256) {
//        IOracle oracle = IOracle(IVenusDistribution(venusDistributionAddress).oracle());
//        return oracle.getUnderlyingPrice(vBaseTokenAddress)
//        .mul(1e18)
//        .div(_amount)
//        .mul(1e18)
//        .div(oracle.getUnderlyingPrice(vBoostedTokenAddress));
    }

    /**
     * @dev Repeatedly supplies and borrows bnb following the configured {borrowRate} and {borrowDepth}
     * into the vToken contract.
     */
    function _leverage(uint256 _amount, bool _withLev) internal {
        if (_withLev) {
            _supply(vBaseTokenAddress, _amount);
            uint256 _boostedAmount = baseToBoosted(_amount);
            _boostedAmount = _boostedAmount.mul(borrowRate).div(1000);
            _borrow(vBoostedTokenAddress, _boostedAmount);
            for (uint256 i = 0; i < borrowDepth; i++) {
                _supply(vBoostedTokenAddress, _boostedAmount);
                _boostedAmount = _boostedAmount.mul(borrowRate).div(1000);
                _borrow(vBoostedTokenAddress, _boostedAmount);
            }
        }

        _supply(vBoostedTokenAddress, _boostedAmount); // Supply remaining want that was last borrowed.
    }

    /**
     * @dev Redeem to the desired leverage amount, then use it to repay borrow.
     * If already over leverage, redeem max amt redeemable, then use it to repay borrow.
     */
    function deleverageOnce() public onlyOwner {

        _deleverageOnce();
    }

    function _deleverageOnce() internal {
        updateBalance(); // Updates borrowBal & supplyBal & supplyBalTargeted & supplyBalMin

        if (supplyBal <= supplyBalTargeted) {
            _removeSupply(vBoostedTokenAddress, supplyBal.sub(supplyBalMin));
        } else {
            _removeSupply(vBoostedTokenAddress, supplyBal.sub(supplyBalTargeted));
        }

        if (wantIsWBNB) {
            _unwrapBNB(); // WBNB -> BNB
            _repayBorrow(vBoostedTokenAddress, address(this).balance);
        } else {
            _repayBorrow(vBoostedTokenAddress, wantLockedInHere());
        }

        updateBalance(); // Updates borrowBal & supplyBal & supplyBalTargeted & supplyBalMin
    }

    /**
     * @dev Redeem the max possible, use it to repay borrow
     */
    function deleverageUntilNotOverLevered() public {
        // updateBalance(); // To be more accurate, call updateBalance() first to cater for changes due to interest rates

        // If borrowRate slips below targetted borrowRate, withdraw the max amt first.
        // Further actual deleveraging will take place later on.
        // (This can happen in when net interest rate < 0, and supplied balance falls below targeted.)
        while (supplyBal > 0 && supplyBal <= supplyBalTargeted) {
            _deleverageOnce();
        }
    }

    /**
     * @dev Incrementally alternates between paying part of the debt and withdrawing part of the supplied
     * collateral. Continues to do this untill all want tokens is withdrawn. For partial deleveraging,
     * this continues until at least _minAmt of want tokens is reached.
     */

    function _deleverage(bool _delevPartial, uint256 _minBaseAmt) internal {
        updateBalance(); // Updates borrowBal & supplyBal & supplyBalTargeted & supplyBalMin

        deleverageUntilNotOverLevered();

        if (wantIsWBNB) {
            _wrapBNB(); // WBNB -> BNB
        }

        uint256 _minAmt = baseToBoosted(_minBaseAmt);

        _removeSupply(supplyBal.sub(supplyBalMin));

        uint256 wantBal = wantLockedInHere();

        // Recursively repay borrowed + remove more from supplied
        while (wantBal < borrowBal) {
            // If only partially deleveraging, when sufficiently deleveraged, do not repay anymore
            if (_delevPartial && wantBal >= _minAmt) {
                return;
            }

            _repayBorrow(wantBal);

            // TODO: optimize it ?
            updateBalance(); // Updates borrowBal & supplyBal & supplyBalTargeted & supplyBalMin

            _removeSupply(supplyBal.sub(supplyBalMin));

            wantBal = wantLockedInHere();
        }

        // If only partially deleveraging, when sufficiently deleveraged, do not repay
        if (_delevPartial && wantBal >= _minAmt) {
            return;
        }

        // Make a final repayment of borrowed
        _repayBorrow(borrowBal);

        // remove all supplied
        uint256 vTokenBal = IERC20(vBoostedTokenAddress).balanceOf(address(this));
        IVToken(vBoostedTokenAddress).redeem(vTokenBal);
    }

    /**
     * @dev Updates the risk profile and rebalances the vault funds accordingly.
     * @param _borrowRate percent to borrow on each leverage level.
     * @param _borrowDepth how many levels to leverage the funds.
     */
    function rebalance(uint256 _borrowRate, uint256 _borrowDepth) onlyOwner external {
        require(_borrowRate <= BORROW_RATE_MAX, "!rate");
        require(_borrowDepth <= BORROW_DEPTH_MAX, "!depth");

        _deleverage(false, uint256(-1)); // deleverage all supplied want tokens
        borrowRate = _borrowRate;
        borrowDepth = _borrowDepth;
        _farm(true);
    }

    function earn() external whenNotPaused onlyOwner {
        IVenusDistribution(venusDistributionAddress).claimVenus(address(this));

        updateBalance();

        if (borrowBal > supplyBal) {
            IPancakeRouter02(uniRouterAddress).swapTokensForExactTokens(
                borrowBal - supplyBal,
                IERC20(venusAddress).balanceOf(address(this)),
                venusToBoostedPath,
                address(this),
                now.add(600)
            );
            _supply(vBoostedTokenAddress, IERC20(baseAddress).balanceOf(address(this)));
        }

        if (venusAddress != boostedAddress) {
            IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
                IERC20(venusAddress).balanceOf(address(this)),
                0,
                venusToWantPath,
                address(this),
                now.add(600)
            );

        }

        uint256 _earnedWant = IERC20(baseAddress).balanceOf(address(this));

        uint256 _devFee  = _earnedWant.mul(controllerFee).div(controllerFeeMax);
        IERC20(_earnedWant).safeTransfer(owner(), _devFee);

        lastEarnBlock = block.number;

        _supply(vBaseTokenAddress, _earnedWant.sub(_devFee));
        updateBalance();
    }


    function getFundsByAccount(address _userWallet) public returns (uint256) {
        updateBalance();
        return userShares[_userWallet].mul(wantLockedTotal()).div(sharesTotal);
    }

    function withdraw(uint256 _wantAmt)
    external
    nonReentrant
    returns (uint256)
    {
        uint256 sharesRemoved =
        _wantAmt.mul(sharesTotal).div(wantLockedTotal());
        require(sharesRemoved <= sharesTotal);

        userShares[msg.sender] = userShares[msg.sender].sub(sharesRemoved);
        sharesTotal = sharesTotal.sub(sharesRemoved);

        uint256 wantBal = IERC20(baseAddress).balanceOf(address(this));
        if (wantBal < _wantAmt) {
            _deleverage(true, _wantAmt.sub(wantBal));
            if (wantIsWBNB) {
                _wrapBNB(); // wrap BNB -> WBNB before sending it back to user
            }
            wantBal = IERC20(baseAddress).balanceOf(address(this));
        }

        if (wantBal < _wantAmt) {
            _wantAmt = wantBal;
        }

        _removeSupply(vBaseTokenAddress, _wantAmt);
        IERC20(baseAddress).safeTransfer(msg.sender, _wantAmt);

        _farm(true);

        return sharesRemoved;
    }

    /**
     * @dev Pauses the strat.
     */
    function pause() onlyOwner public {
        _pause();

        IERC20(venusAddress).safeApprove(uniRouterAddress, 0);
        IERC20(boostedAddress).safeApprove(uniRouterAddress, 0);
        if (!wantIsWBNB) {
            IERC20(boostedAddress).safeApprove(vBoostedTokenAddress, 0);
        }
    }

    /**
     * @dev Unpauses the strat.
     */
    function unpause() onlyOwner external {
        _unpause();

        IERC20(venusAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(boostedAddress).safeApprove(uniRouterAddress, uint256(-1));
        if (!wantIsWBNB) {
            IERC20(boostedAddress).safeApprove(vBoostedTokenAddress, 0);
        }
    }

    /**
     * @dev Updates want locked in Venus after interest is accrued to this very block.
     * To be called before sensitive operations.
     */
    function updateBalance() public {

        supplyBalBase = IVToken(vBaseTokenAddress).balanceOfUnderlying(address(this));

        supplyBal = IVToken(vBoostedTokenAddress).balanceOfUnderlying(address(this)); // a payable function because of acrueInterest()
        borrowBal = IVToken(vBoostedTokenAddress).borrowBalanceCurrent(address(this));
        IOracle oracle = IOracle(IVenusDistribution(venusDistributionAddress).oracle());
        uint256 _basePrice = oracle.getUnderlyingPrice(vBaseTokenAddress);
        uint256 _boostedPrice = oracle.getUnderlyingPrice(vBoostedTokenAddress);

        supplyBalTargeted = (borrowBal.mul(_boostedPrice).div(1e18) - borrowRate.mul(supplyBalBase).mul(_basePrice).div(1e18).div(1000)) / (_boostedPrice.mul(borrowRate).div(1000));

//        supplyBalTargeted = borrowBal.mul(1000).div(borrowRate);

        supplyBalMin = borrowBal.mul(1000).div(BORROW_RATE_MAX_HARD);
    }

    // read supplyBal + borrowBal

    function wantLockedTotal() public view returns (uint256) {
        return wantLockedInHere().add(supplyBalBase); // .sub(borrowBal)
    }

    function wantLockedInHere() public view returns (uint256) {
        uint256 wantBal = IERC20(baseAddress).balanceOf(address(this));
        if (wantIsWBNB) {
            uint256 bnbBal = address(this).balance;
            return bnbBal.add(wantBal);
        } else {
            return wantBal;
        }
    }

    function setControllerFee(uint256 _controllerFee) public onlyOwner {
        require(_controllerFee <= controllerFeeUL, "too high");
        controllerFee = _controllerFee;
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) public onlyOwner {
//        require(_token != earnedAddress, "!safe");
//        require(_token != boostedAddress, "!safe");
//        require(_token != baseAddress, "!safe");
//        require(_token != vBoostedTokenAddress, "!safe");
//        require(_token != vBaseTokenAddress, "!safe");

        IERC20(_token).safeTransfer(_to, _amount);
    }

    function _wrapBNB() internal {
        // BNB -> WBNB
        uint256 bnbBal = address(this).balance;
        if (bnbBal > 0) {
            IWBNB(wbnbAddress).deposit{value: bnbBal}(); // BNB -> WBNB
        }
    }

    function _unwrapBNB() internal {
        // WBNB -> BNB
        uint256 wbnbBal = IERC20(wbnbAddress).balanceOf(address(this));
        if (wbnbBal > 0) {
            IWBNB(wbnbAddress).withdraw(wbnbBal);
        }
    }

    /**
     * @dev We should not have significant amts of BNB in this contract if any at all.
     * In case we do (eg. Venus returns all users' BNB to this contract or for any other reason),
     * We can wrap all BNB, allowing users to withdraw() as per normal.
     */
    function wrapBNB() public onlyOwner {
        _wrapBNB();
    }

    receive() external payable {}
}
