pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "./DfProfits.sol";
import "../../utils/DSMath.sol";
import "../../upgradable/OwnableUpgradable.sol";
import "../../utils/UniversalERC20.sol";

// **INTERFACES**
import "../../interfaces/IDfDepositToken.sol";
import "../../interfaces/ITransferAndCall.sol";
import "../../interfaces/IERC20.sol";
import "../../interfaces/IToken.sol";
import "../../interfaces/IDfVenusFarm.sol";

contract DfPool is Initializable, OwnableUpgradable, DSMath {
    using UniversalERC20 for IToken;

    address public constant BRIDGE_ADDRESS = 0xD83893F31AA1B6B9D97C9c70D3492fe38D24d218;
    IERC20 constant dai = IERC20(0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3);                    // BSC dai
    IERC20 constant dDaiWrapper = IERC20(0x29213043820EE69761a7Cd23646BAF5743926912);            // dDai from bridge
    IDfDepositToken constant dDai = IDfDepositToken(0x308853AeC7cF0ECF133ed19C0c1fb3b35f5a4E7B); // dDai for user

    DfProfits public dfProfits;     // contract that contains only profit funds

    struct ProfitData {
        uint64 blockNumber;
        uint64 daiProfit; // div 1e12 (6 dec)
    }
    ProfitData[] public profits;

    mapping(address => uint64) public lastProfitDistIndex;

    event Profit(address indexed user, uint64 index, uint64 daiProfit);
    event CreateDfProfit(address indexed dfProfit);

    IDfVenusFarm constant dfVenusFarm = IDfVenusFarm(0x7a8d722F7083495ea436f9216a76e02836CB842a);

// ** INITIALIZER – Constructor for Upgradable contracts **
    function initialize() public initializer {
        OwnableUpgradable.initialize(msg.sender);    // Initialize Parent Contract
    }

//    function initOnce() public {
//        require(profits.length == 0);
//        // migrate from old contract
//        profits.push(ProfitData(3003751, 50000));
//        profits.push(ProfitData(4416559, 500000));
//
//        // init dfProfits
//        if (dfProfits == DfProfits(0)) {
//            dfProfits = new DfProfits(address(this));
//            emit CreateDfProfit(address(dfProfits));
//        }
//    }

    // ** PUBLIC VIEW functions **
    function calcUserProfit(address userAddress, uint256 max) public view returns(
        uint256 totalDaiProfit, uint64 index
    ) {
        (totalDaiProfit, index) = getUserProfitFromCustomIndex(userAddress, lastProfitDistIndex[userAddress], max);
    }

    function getUserProfitFromCustomIndex(address userAddress, uint64 fromIndex, uint256 max) public view returns(
        uint256 totalDaiProfit, uint64 index
    ) {
        if (profits.length < max) max = profits.length;

        for(index = fromIndex; index < max; index++) {

            (uint256 balanceAtBlock, uint256 totalSupplyAt) = userShare(userAddress, index + 1);

            if (balanceAtBlock > 0) {
                ProfitData memory p = profits[index];
                uint256 profitDai = wdiv(wmul(mul(uint256(p.daiProfit), 1e12), balanceAtBlock), totalSupplyAt);
                totalDaiProfit = add(totalDaiProfit, profitDai);
            }
        }
    }

    function userShare(address userAddress, uint256 snapshotId) view public returns (uint256 totalLiquidity, uint256 totalSupplay) {
        if (snapshotId == uint256(-1)) snapshotId = profits.length;

        totalLiquidity = dDai.balanceOfAt(userAddress, snapshotId);
        if (totalLiquidity > 0) totalSupplay = dDai.totalSupplyAt(snapshotId);
    }

    // ** PUBLIC functions **
    function totalUnlockedDDai() view public returns (uint256) {
        return sub(dDaiWrapper.balanceOf(address(this)), dDai.totalSupply());
    }

    // 1 dai == 1 dDai dDai
    function deposit(uint256 _amount) public {
        dai.transferFrom(msg.sender, address(this), _amount);
        dDai.transfer(msg.sender, _amount);
    }

    // 1 dDai == 1 dai dDai
    function withdraw(uint256 _amount) public {
        // dDai.transferFrom(msg.sender, address(this), _amount);
        dDai.burnFrom(msg.sender, _amount); // use burnFrom & mint to emulate transferFrom (user don't need to approve)
        dDai.mint(address(this), _amount);
        if (dai.balanceOf(address(this)) >= _amount) {
            dai.transfer(msg.sender, _amount);
        } else {
            dfVenusFarm.withdraw(_amount);
            dai.transfer(msg.sender, _amount);
        }

    }

    function userClaimProfit(uint64 max) public {
        require(msg.sender == tx.origin);

        (uint256 totalDaiProfit, uint64 index) = calcUserProfit(msg.sender, max);

        sendRewardToUser(msg.sender, msg.sender, index, totalDaiProfit, false);

        emit Profit(msg.sender, index, uint64(totalDaiProfit));
    }

    function burnDDai(uint256 _amount) public {
        dDai.burnFrom(msg.sender, _amount);
        dDaiWrapper.transfer(msg.sender, _amount);
    }

    function transferToEth(uint256 _amount) public {
        transferToEth(_amount, msg.sender);
    }

    function transferToEth(uint256 _amount, address ethAddress) public {
        dDai.burnFrom(msg.sender, _amount);
        ITransferAndCall(address(dDaiWrapper)).transferAndCall(BRIDGE_ADDRESS, _amount, abi.encodePacked(ethAddress));
    }

    // ** ONLY_OWNER functions **
    function appendDDai(uint256 _amount) public onlyOwner {
        if (_amount == uint256(-1)) _amount = dDaiWrapper.balanceOf(msg.sender);
        dDaiWrapper.transferFrom(msg.sender, address(this), _amount);
        // sync dDai and dDaiWrapper amounts
        dDai.mint(address(this), _amount);
    }

    // add profit from ethereum blockchain
    function addProfit(uint _amount) public onlyOwner {
        ProfitData memory p;
        p.blockNumber = uint64(block.number);

        require(address(dfProfits) != address(0));

        dai.transferFrom(msg.sender, address(dfProfits), _amount);
        p.daiProfit = uint64(_amount / 1e12); // reduce decimals to 1e6

        // UPD state
        profits.push(p);
        dDai.snapshot();
    }

    function moveDaiToVenusFarm(uint256 _amount) public onlyOwner {
        if (dai.allowance(address(this), address(dfVenusFarm)) != uint(-1)) {
            dai.approve(address(dfVenusFarm), uint(-1));
        }
        dfVenusFarm.deposit(_amount);
    }

    function extractDaiFromVenusFarm(uint256 _amount) public onlyOwner {
        if(_amount == uint256(-1)) {
            _amount = dfVenusFarm.getFundsByAccount(address(this));
        }
        dfVenusFarm.withdraw(_amount);
    }

    function selfClaimProfit(uint64 max) public onlyOwner {
        address fixProfitFor = address(this);
        address sendProfitTo = msg.sender;
        (uint256 totalDaiProfit, uint64 index) = calcUserProfit(fixProfitFor, max);

        sendRewardToUser(fixProfitFor, sendProfitTo, index, totalDaiProfit, false);

        emit Profit(fixProfitFor, index, uint64(totalDaiProfit));
    }

    function withdrawToken(address token, uint256 _amount) public onlyOwner {
        if (token == address(0x0)) {
            owner.transfer(_amount);
        } else {
            if (token == address(dDaiWrapper)) { // we can't withdraw dDAI locked by another users
                require(_amount <= totalUnlockedDDai(), "locked");
            }
            IToken(token).universalTransfer(owner, _amount);
        }
    }

    // check dDaiWrapper in withdrawToken function
    function withdrawTokenAll(address[] memory tokens) public onlyOwner {
        for(uint256 i = 0; i < tokens.length;i++) {
            withdrawToken(tokens[i], IToken(tokens[i]).universalBalanceOf(address(this)));
        }
    }


    // ** INTERNAL functions **
    function sendRewardToUser(address _account, address _profitToAddress, uint64 _index, uint256 _totalDaiProfit, bool _isReinvest) internal {
        lastProfitDistIndex[_account] = _index;

        if (_totalDaiProfit > 0) {
            dfProfits.cast(address(uint160(address(dai))), abi.encodeWithSelector(IERC20(dai).transfer.selector, _profitToAddress, _totalDaiProfit));
            if (_isReinvest) {
                deposit(_totalDaiProfit);
            }
        }
    }
}
