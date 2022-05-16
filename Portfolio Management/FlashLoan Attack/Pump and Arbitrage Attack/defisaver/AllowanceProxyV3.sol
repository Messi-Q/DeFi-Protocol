pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../auth/AdminAuth.sol";
import "./DFSExchange.sol";
import "../utils/SafeERC20.sol";

contract AllowanceProxy is AdminAuth {

    using SafeERC20 for ERC20;

    address public constant KYBER_ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    DFSExchange dfsExchange = DFSExchange(0xc2Ce04e2FB4DD20964b4410FcE718b95963a1587);

    function callSell(DFSExchangeCore.ExchangeData memory exData) public payable {
        pullAndSendTokens(exData.srcAddr, exData.srcAmount);

        dfsExchange.sell{value: msg.value}(exData, msg.sender);
    }

    function callBuy(DFSExchangeCore.ExchangeData memory exData) public payable {
        pullAndSendTokens(exData.srcAddr, exData.srcAmount);

        dfsExchange.buy{value: msg.value}(exData, msg.sender);
    }

    function pullAndSendTokens(address _tokenAddr, uint _amount) internal {
        if (_tokenAddr == KYBER_ETH_ADDRESS) {
            require(msg.value >= _amount, "msg.value smaller than amount");
        } else {
            ERC20(_tokenAddr).safeTransferFrom(msg.sender, address(dfsExchange), _amount);
        }
    }

    function ownerChangeExchange(address payable _newExchange) public onlyOwner {
        dfsExchange = DFSExchange(_newExchange);
    }
}
