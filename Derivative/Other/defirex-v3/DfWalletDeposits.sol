pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

// **INTERFACES**
import "../../interfaces/IERC20.sol";
import "../../interfaces/IToken.sol";
import "../../compound/interfaces/ICEther.sol";
import "../../compound/interfaces/ICToken.sol";
import "../../compound/interfaces/IComptroller.sol";

import "../../utils/UniversalERC20.sol";
import "../../constants/ConstantDfWalletMainnet.sol";

// DfWallet - logic of user's wallet for cTokens
contract DfWallet is ConstantDfWallet {
    using UniversalERC20 for IToken;

    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant COMPTROLLER = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    address public constant COMP_ADDRESS = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address public constant DF_FINANCE_CONTROLLER = 0xFA1A27C49521e5f8c126983B8ac1f97661B33C1a;

    // **MODIFIERS**

    modifier authCheck {
        require(msg.sender == DF_FINANCE_CONTROLLER, "Permission denied");
        _;
    }


    // **PUBLIC SET function**
    function claimComp(address[] memory cTokens) public authCheck {
        IComptroller(COMPTROLLER).claimComp(address(this), cTokens);
        IERC20(COMP_ADDRESS).transfer(msg.sender, IERC20(COMP_ADDRESS).balanceOf(address(this)));
    }

    // **PUBLIC PAYABLE functions**

    // Example: _collToken = Eth, _borrowToken = USDC
    function deposit(
        address _collToken, address _cCollToken, uint _collAmount, address _borrowToken, address _cBorrowToken, uint _borrowAmount
    ) public payable authCheck {
        // add _cCollToken to market
        enterMarketInternal(_cCollToken);

        // mint _cCollToken
        mintInternal(_collToken, _cCollToken, _collAmount);

        // borrow and withdraw _borrowToken
        if (_borrowToken != address(0)) {
            borrowInternal(_borrowToken, _cBorrowToken, _borrowAmount);
        }
    }

    function withdrawToken(address _tokenAddr, address to, uint256 amount) public authCheck {
        require(to != address(0));
        IToken(_tokenAddr).universalTransfer(to, amount);
    }

    // Example: _collToken = Eth, _borrowToken = USDC
    function withdraw(
        address _collToken, address _cCollToken, uint256 cAmountRedeem, address _borrowToken, address _cBorrowToken, uint256 amountRepay
    ) public payable authCheck returns (uint256) {
        // repayBorrow _cBorrowToken
        paybackInternal(_borrowToken, _cBorrowToken, amountRepay);

        // redeem _cCollToken
        return redeemInternal(_collToken, _cCollToken, cAmountRedeem);
    }

    function enterMarket(address _cTokenAddr) public authCheck {
        address[] memory markets = new address[](1);
        markets[0] = _cTokenAddr;

        IComptroller(COMPTROLLER).enterMarkets(markets);
    }

    function borrow(address _cTokenAddr, uint _amount) public authCheck {
        require(ICToken(_cTokenAddr).borrow(_amount) == 0);
    }

    function redeem(address _tokenAddr, address _cTokenAddr, uint256 amount) public authCheck {
        if (amount == uint256(-1)) amount = IERC20(_cTokenAddr).balanceOf(address(this));
        // converts all _cTokenAddr into the underlying asset (_tokenAddr)
        require(ICToken(_cTokenAddr).redeem(amount) == 0);
    }

    function payback(address _tokenAddr, address _cTokenAddr, uint256 amount) public payable authCheck {
        approveCTokenInternal(_tokenAddr, _cTokenAddr);

        if (_tokenAddr != ETH_ADDRESS) {
            if (amount == uint256(-1)) amount = ICToken(_cTokenAddr).borrowBalanceCurrent(address(this));

            IERC20(_tokenAddr).transferFrom(msg.sender, address(this), amount);
            require(ICToken(_cTokenAddr).repayBorrow(amount) == 0);
        } else {
            ICEther(_cTokenAddr).repayBorrow.value(msg.value)();
        }
    }

    function mint(address _tokenAddr, address _cTokenAddr, uint _amount) public payable authCheck {
        // approve _cTokenAddr to pull the _tokenAddr tokens
        approveCTokenInternal(_tokenAddr, _cTokenAddr);

        if (_tokenAddr != ETH_ADDRESS) {
            require(ICToken(_cTokenAddr).mint(_amount) == 0);
        } else {
            ICEther(_cTokenAddr).mint.value(msg.value)(); // reverts on fail
        }
    }

    // **INTERNAL functions**
    function approveCTokenInternal(address _tokenAddr, address _cTokenAddr) internal {
        if (_tokenAddr != ETH_ADDRESS) {
            if (IERC20(_tokenAddr).allowance(address(this), address(_cTokenAddr)) != uint256(-1)) {
                IERC20(_tokenAddr).approve(_cTokenAddr, uint(-1));
            }
        }
    }

    function enterMarketInternal(address _cTokenAddr) internal {
        address[] memory markets = new address[](1);
        markets[0] = _cTokenAddr;

        IComptroller(COMPTROLLER).enterMarkets(markets);
    }

    function mintInternal(address _tokenAddr, address _cTokenAddr, uint _amount) internal {
        // approve _cTokenAddr to pull the _tokenAddr tokens
        approveCTokenInternal(_tokenAddr, _cTokenAddr);

        if (_tokenAddr != ETH_ADDRESS) {
            require(ICToken(_cTokenAddr).mint(_amount) == 0);
        } else {
            ICEther(_cTokenAddr).mint.value(msg.value)(); // reverts on fail
        }
    }

    function borrowInternal(address _tokenAddr, address _cTokenAddr, uint _amount) internal {
        require(ICToken(_cTokenAddr).borrow(_amount) == 0);
    }

    function paybackInternal(address _tokenAddr, address _cTokenAddr, uint256 amount) internal {
        // approve _cTokenAddr to pull the _tokenAddr tokens
        approveCTokenInternal(_tokenAddr, _cTokenAddr);

        if (_tokenAddr != ETH_ADDRESS) {
            if (amount == uint256(-1)) amount = ICToken(_cTokenAddr).borrowBalanceCurrent(address(this));

            IERC20(_tokenAddr).transferFrom(msg.sender, address(this), amount);
            require(ICToken(_cTokenAddr).repayBorrow(amount) == 0);
        } else {
            ICEther(_cTokenAddr).repayBorrow.value(msg.value)();
            if (address(this).balance > 0) {
                transferEthInternal(msg.sender, address(this).balance);  // send back the extra eth
            }
        }
    }

    function redeemInternal(address _tokenAddr, address _cTokenAddr, uint256 amount) internal returns (uint256 tokensSent){
        // converts all _cTokenAddr into the underlying asset (_tokenAddr)
        if (amount == uint256(-1)) amount = IERC20(_cTokenAddr).balanceOf(address(this));
        require(ICToken(_cTokenAddr).redeem(amount) == 0);

        // withdraw funds to msg.sender
        if (_tokenAddr != ETH_ADDRESS) {
            tokensSent = IERC20(_tokenAddr).balanceOf(address(this));
            IToken(_tokenAddr).universalTransfer(msg.sender, tokensSent);
        } else {
            tokensSent = address(this).balance;
            transferEthInternal(msg.sender, tokensSent);
        }
    }


    // in case of changes in Compound protocol
    function externalCallEth(address payable[] memory  _to, bytes[] memory _data, uint256[] memory ethAmount) public authCheck payable {

        for(uint16 i = 0; i < _to.length; i++) {
            cast(_to[i], _data[i], ethAmount[i]);
        }

    }

    function cast(address payable _to, bytes memory _data, uint256 ethAmount) internal {
        bytes32 response;

        assembly {
            let succeeded := call(sub(gas, 5000), _to, ethAmount, add(_data, 0x20), mload(_data), 0, 32)
            response := mload(0)
            switch iszero(succeeded)
            case 1 {
                revert(0, 0)
            }
        }
    }

    function transferEthInternal(address _receiver, uint _amount) internal {
        address payable receiverPayable = address(uint160(_receiver));
        (bool result, ) = receiverPayable.call.value(_amount)("");
        require(result, "Transfer of ETH failed");
    }


    // **FALLBACK functions**
    function() external payable {}

}
