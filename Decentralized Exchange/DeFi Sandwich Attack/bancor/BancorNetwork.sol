// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./IBancorNetwork.sol";
import "./IConversionPathFinder.sol";
import "./converter/interfaces/IConverter.sol";
import "./converter/interfaces/IConverterAnchor.sol";
import "./converter/interfaces/IBancorFormula.sol";
import "./utility/ContractRegistryClient.sol";
import "./utility/ReentrancyGuard.sol";
import "./utility/TokenHolder.sol";

import "./token/interfaces/IDSToken.sol";
import "./token/SafeERC20Ex.sol";
import "./token/ReserveToken.sol";

import "./bancorx/interfaces/IBancorX.sol";

// interface of older converters for backward compatibility
interface ILegacyConverter {
    function change(
        IReserveToken _sourceToken,
        IReserveToken _targetToken,
        uint256 _amount,
        uint256 _minReturn
    ) external returns (uint256);
}

/**
 * @dev This contract is the main entry point for Bancor token conversions.
 * It also allows for the conversion of any token in the Bancor Network to any other token in a single
 * transaction by providing a conversion path.
 *
 * A note on Conversion Path: Conversion path is a data structure that is used when converting a token
 * to another token in the Bancor Network, when the conversion cannot necessarily be done by a single
 * converter and might require multiple 'hops'.
 * The path defines which converters should be used and what kind of conversion should be done in each step.
 *
 * The path format doesn't include complex structure; instead, it is represented by a single array
 * in which each 'hop' is represented by a 2-tuple - converter anchor & target token.
 * In addition, the first element is always the source token.
 * The converter anchor is only used as a pointer to a converter (since converter addresses are more
 * likely to change as opposed to anchor addresses).
 *
 * Format:
 * [source token, converter anchor, target token, converter anchor, target token...]
 */
contract BancorNetwork is IBancorNetwork, TokenHolder, ContractRegistryClient, ReentrancyGuard {
    using SafeMath for uint256;
    using ReserveToken for IReserveToken;
    using SafeERC20 for IERC20;
    using SafeERC20Ex for IERC20;

    struct ConversionStep {
        IConverter converter;
        IConverterAnchor anchor;
        IReserveToken sourceToken;
        IReserveToken targetToken;
        address payable beneficiary;
        bool isV28OrHigherConverter;
    }

    /**
     * @dev triggered when a conversion between two tokens occurs
     *
     * @param _smartToken  anchor governed by the converter
     * @param _fromToken   source reserve token
     * @param _toToken     target reserve token
     * @param _fromAmount  amount converted, in the source token
     * @param _toAmount    amount returned, minus conversion fee
     * @param _trader      wallet that initiated the trade
     */
    event Conversion(
        IConverterAnchor indexed _smartToken,
        IReserveToken indexed _fromToken,
        IReserveToken indexed _toToken,
        uint256 _fromAmount,
        uint256 _toAmount,
        address _trader
    );

    /**
     * @dev initializes a new BancorNetwork instance
     *
     * @param _registry    address of a contract registry contract
     */
    constructor(IContractRegistry _registry) public ContractRegistryClient(_registry) {}

    /**
     * @dev returns the conversion path between two tokens in the network
     * note that this method is quite expensive in terms of gas and should generally be called off-chain
     *
     * @param _sourceToken source reserve token address
     * @param _targetToken target reserve token address
     *
     * @return conversion path between the two tokens
     */
    function conversionPath(IReserveToken _sourceToken, IReserveToken _targetToken)
        public
        view
        returns (address[] memory)
    {
        IConversionPathFinder pathFinder = IConversionPathFinder(addressOf(CONVERSION_PATH_FINDER));
        return pathFinder.findPath(_sourceToken, _targetToken);
    }

    /**
     * @dev returns the expected target amount of converting a given amount on a given path
     * note that there is no support for circular paths
     *
     * @param _path        conversion path (see conversion path format above)
     * @param _amount      amount of _path[0] tokens received from the sender
     *
     * @return expected target amount
     */
    function rateByPath(address[] memory _path, uint256 _amount) public view override returns (uint256) {
        uint256 amount;
        uint256 fee;
        uint256 supply;
        uint256 balance;
        uint32 weight;
        IConverter converter;
        IBancorFormula formula = IBancorFormula(addressOf(BANCOR_FORMULA));

        amount = _amount;

        // verify that the number of elements is larger than 2 and odd
        require(_path.length > 2 && _path.length % 2 == 1, "ERR_INVALID_PATH");

        // iterate over the conversion path
        for (uint256 i = 2; i < _path.length; i += 2) {
            IReserveToken sourceToken = IReserveToken(_path[i - 2]);
            address anchor = _path[i - 1];
            IReserveToken targetToken = IReserveToken(_path[i]);

            converter = IConverter(payable(IConverterAnchor(anchor).owner()));

            if (address(targetToken) == anchor) {
                // buy the anchor
                // check if the current anchor has changed
                if (i < 3 || anchor != _path[i - 3]) {
                    supply = IDSToken(anchor).totalSupply();
                }

                // get the amount & the conversion fee
                balance = converter.getConnectorBalance(sourceToken);
                (, weight, , , ) = converter.connectors(sourceToken);
                amount = formula.purchaseTargetAmount(supply, balance, weight, amount);
                fee = amount.mul(converter.conversionFee()).div(PPM_RESOLUTION);
                amount -= fee;

                // update the anchor supply for the next iteration
                supply = supply.add(amount);
            } else if (address(sourceToken) == anchor) {
                // sell the anchor
                // check if the current anchor has changed
                if (i < 3 || anchor != _path[i - 3]) {
                    supply = IDSToken(anchor).totalSupply();
                }

                // get the amount & the conversion fee
                balance = converter.getConnectorBalance(targetToken);
                (, weight, , , ) = converter.connectors(targetToken);
                amount = formula.saleTargetAmount(supply, balance, weight, amount);
                fee = amount.mul(converter.conversionFee()).div(PPM_RESOLUTION);
                amount -= fee;

                // update the anchor supply for the next iteration
                supply = supply.sub(amount);
            } else {
                // cross reserve conversion
                (amount, fee) = getReturn(converter, sourceToken, targetToken, amount);
            }
        }

        return amount;
    }

    /**
     * @dev converts the token to any other token in the bancor network by following
     * a predefined conversion path and transfers the result tokens to a target account
     * note that the network should already have been given allowance of the source token (if not ETH)
     *
     * @param _path                conversion path, see conversion path format above
     * @param _amount              amount to convert from, in the source token
     * @param _minReturn           if the conversion results in an amount smaller than the minimum return - it is cancelled, must be greater than zero
     * @param _beneficiary         account that will receive the conversion result or 0x0 to send the result to the sender account
     *
     * @return amount of tokens received from the conversion
     */
    function convertByPath2(
        address[] memory _path,
        uint256 _amount,
        uint256 _minReturn,
        address payable _beneficiary
    ) public payable protected greaterThanZero(_minReturn) returns (uint256) {
        // verify that the path contains at least a single 'hop' and that the number of elements is odd
        require(_path.length > 2 && _path.length % 2 == 1, "ERR_INVALID_PATH");

        // validate msg.value and prepare the source token for the conversion
        handleSourceToken(IReserveToken(_path[0]), IConverterAnchor(_path[1]), _amount);

        // check if beneficiary is set
        address payable beneficiary = msg.sender;
        if (_beneficiary != address(0)) {
            beneficiary = _beneficiary;
        }

        // convert and get the resulting amount
        ConversionStep[] memory data = createConversionData(_path, beneficiary);
        uint256 amount = doConversion(data, _amount, _minReturn);

        // handle the conversion target tokens
        handleTargetToken(data, amount, beneficiary);

        return amount;
    }

    /**
      * @dev converts any other token to BNT in the bancor network by following
      a predefined conversion path and transfers the result to an account on a different blockchain
      * note that the network should already have been given allowance of the source token (if not ETH)
      *
      * @param _path                conversion path, see conversion path format above
      * @param _amount              amount to convert from, in the source token
      * @param _minReturn           if the conversion results in an amount smaller than the minimum return - it is cancelled, must be greater than zero
      * @param _targetBlockchain    blockchain BNT will be issued on
      * @param _targetAccount       address/account on the target blockchain to send the BNT to
      * @param _conversionId        pre-determined unique (if non zero) id which refers to this transaction
      *
      * @return the amount of BNT received from this conversion
    */
    function xConvert(
        address[] memory _path,
        uint256 _amount,
        uint256 _minReturn,
        bytes32 _targetBlockchain,
        bytes32 _targetAccount,
        uint256 _conversionId
    ) public payable greaterThanZero(_minReturn) returns (uint256) {
        IReserveToken targetToken = IReserveToken(_path[_path.length - 1]);
        IBancorX bancorX = IBancorX(addressOf(BANCOR_X));

        // verify that the destination token is BNT
        require(targetToken == IReserveToken(addressOf(BNT_TOKEN)), "ERR_INVALID_TARGET_TOKEN");

        // convert and get the resulting amount
        uint256 amount = convertByPath2(_path, _amount, _minReturn, payable(address(this)));

        // grant BancorX allowance
        targetToken.ensureApprove(address(bancorX), amount);

        // transfer the resulting amount to BancorX
        bancorX.xTransfer(_targetBlockchain, _targetAccount, amount, _conversionId);

        return amount;
    }

    /**
     * @dev allows a user to convert a token that was sent from another blockchain into any other
     * token on the BancorNetwork
     * ideally this transaction is created before the previous conversion is even complete, so
     * so the input amount isn't known at that point - the amount is actually take from the
     * BancorX contract directly by specifying the conversion id
     *
     * @param _path            conversion path
     * @param _bancorX         address of the BancorX contract for the source token
     * @param _conversionId    pre-determined unique (if non zero) id which refers to this conversion
     * @param _minReturn       if the conversion results in an amount smaller than the minimum return - it is cancelled, must be nonzero
     * @param _beneficiary     wallet to receive the conversion result
     *
     * @return amount of tokens received from the conversion
     */
    function completeXConversion(
        address[] memory _path,
        IBancorX _bancorX,
        uint256 _conversionId,
        uint256 _minReturn,
        address payable _beneficiary
    ) public returns (uint256) {
        // verify that the source token is the BancorX token
        require(_path[0] == address(_bancorX.token()), "ERR_INVALID_SOURCE_TOKEN");

        // get conversion amount from BancorX contract
        uint256 amount = _bancorX.getXTransferAmount(_conversionId, msg.sender);

        // perform the conversion
        return convertByPath2(_path, amount, _minReturn, _beneficiary);
    }

    /**
     * @dev executes the actual conversion by following the conversion path
     *
     * @param _data                conversion data, see ConversionStep struct above
     * @param _amount              amount to convert from, in the source token
     * @param _minReturn           if the conversion results in an amount smaller than the minimum return - it is cancelled, must be greater than zero
     *
     * @return amount of tokens received from the conversion
     */
    function doConversion(
        ConversionStep[] memory _data,
        uint256 _amount,
        uint256 _minReturn
    ) private returns (uint256) {
        uint256 toAmount;
        uint256 fromAmount = _amount;

        // iterate over the conversion data
        for (uint256 i = 0; i < _data.length; i++) {
            ConversionStep memory stepData = _data[i];

            // newer converter
            if (stepData.isV28OrHigherConverter) {
                // transfer the tokens to the converter only if the network contract currently holds the tokens
                // not needed with ETH or if it's the first conversion step
                if (i != 0 && _data[i - 1].beneficiary == address(this) && !stepData.sourceToken.isNativeToken()) {
                    stepData.sourceToken.safeTransfer(address(stepData.converter), fromAmount);
                }
            } else if (address(stepData.sourceToken) != address(stepData.anchor)) {
                // if the source token is the liquid token, no need to do any transfers as the converter controls it

                // grant allowance for it to transfer the tokens from the network contract
                stepData.sourceToken.ensureApprove(address(stepData.converter), fromAmount);
            }

            // do the conversion
            if (!stepData.isV28OrHigherConverter) {
                toAmount = ILegacyConverter(address(stepData.converter)).change(
                    stepData.sourceToken,
                    stepData.targetToken,
                    fromAmount,
                    1
                );
            } else if (stepData.sourceToken.isNativeToken()) {
                toAmount = stepData.converter.convert{ value: msg.value }(
                    stepData.sourceToken,
                    stepData.targetToken,
                    fromAmount,
                    msg.sender,
                    stepData.beneficiary
                );
            } else {
                toAmount = stepData.converter.convert(
                    stepData.sourceToken,
                    stepData.targetToken,
                    fromAmount,
                    msg.sender,
                    stepData.beneficiary
                );
            }

            emit Conversion(
                stepData.anchor,
                stepData.sourceToken,
                stepData.targetToken,
                fromAmount,
                toAmount,
                msg.sender
            );
            fromAmount = toAmount;
        }

        // ensure the trade meets the minimum requested amount
        require(toAmount >= _minReturn, "ERR_RETURN_TOO_LOW");

        return toAmount;
    }

    /**
     * @dev validates msg.value and prepares the conversion source token for the conversion
     *
     * @param _sourceToken source token of the first conversion step
     * @param _anchor      converter anchor of the first conversion step
     * @param _amount      amount to convert from, in the source token
     */
    function handleSourceToken(
        IReserveToken _sourceToken,
        IConverterAnchor _anchor,
        uint256 _amount
    ) private {
        IConverter firstConverter = IConverter(payable(_anchor.owner()));
        bool isNewerConverter = isV28OrHigherConverter(firstConverter);

        if (msg.value > 0) {
            require(msg.value == _amount, "ERR_ETH_AMOUNT_MISMATCH");
            require(_sourceToken.isNativeToken(), "ERR_INVALID_SOURCE_TOKEN");
            require(isNewerConverter, "ERR_CONVERTER_NOT_SUPPORTED");
        } else {
            require(!_sourceToken.isNativeToken(), "ERR_INVALID_SOURCE_TOKEN");
            if (isNewerConverter) {
                // newer converter - transfer the tokens from the sender directly to the converter
                _sourceToken.safeTransferFrom(msg.sender, address(firstConverter), _amount);
            } else {
                // otherwise claim the tokens
                _sourceToken.safeTransferFrom(msg.sender, address(this), _amount);
            }
        }
    }

    /**
     * @dev handles the conversion target token if the network still holds it at the end of the conversion
     *
     * @param _data        conversion data, see ConversionStep struct above
     * @param _amount      conversion target amount
     * @param _beneficiary wallet to receive the conversion result
     */
    function handleTargetToken(
        ConversionStep[] memory _data,
        uint256 _amount,
        address payable _beneficiary
    ) private {
        ConversionStep memory stepData = _data[_data.length - 1];

        // network contract doesn't hold the tokens, do nothing
        if (stepData.beneficiary != address(this)) {
            return;
        }

        IReserveToken targetToken = stepData.targetToken;
        assert(!targetToken.isNativeToken());
        targetToken.safeTransfer(_beneficiary, _amount);
    }

    /**
     * @dev creates a memory cache of all conversion steps data to minimize logic and external calls during conversions
     *
     * @param _conversionPath      conversion path, see conversion path format above
     * @param _beneficiary         wallet to receive the conversion result
     *
     * @return cached conversion data to be ingested later on by the conversion flow
     */
    function createConversionData(address[] memory _conversionPath, address payable _beneficiary)
        private
        view
        returns (ConversionStep[] memory)
    {
        ConversionStep[] memory data = new ConversionStep[](_conversionPath.length / 2);

        // iterate the conversion path and create the conversion data for each step
        uint256 i;
        for (i = 0; i < _conversionPath.length - 1; i += 2) {
            IConverterAnchor anchor = IConverterAnchor(_conversionPath[i + 1]);
            IConverter converter = IConverter(payable(anchor.owner()));
            IReserveToken targetToken = IReserveToken(_conversionPath[i + 2]);

            data[i / 2] = ConversionStep({ // set the converter anchor
                anchor: anchor, // set the converter
                converter: converter, // set the source/target tokens
                sourceToken: IReserveToken(_conversionPath[i]),
                targetToken: targetToken, // requires knowledge about the next step, so initialize in the next phase
                beneficiary: address(0), // set flags
                isV28OrHigherConverter: isV28OrHigherConverter(converter)
            });
        }

        // set the beneficiary for each step
        for (i = 0; i < data.length; i++) {
            ConversionStep memory stepData = data[i];
            // check if the converter in this step is newer as older converters don't even support the beneficiary argument
            if (stepData.isV28OrHigherConverter) {
                if (i == data.length - 1) {
                    // converter in this step is newer, beneficiary is the user input address
                    stepData.beneficiary = _beneficiary;
                } else if (data[i + 1].isV28OrHigherConverter) {
                    // the converter in the next step is newer, beneficiary is the next converter
                    stepData.beneficiary = address(data[i + 1].converter);
                } else {
                    // the converter in the next step is older, beneficiary is the network contract
                    stepData.beneficiary = payable(address(this));
                }
            } else {
                // converter in this step is older, beneficiary is the network contract
                stepData.beneficiary = payable(address(this));
            }
        }

        return data;
    }

    bytes4 private constant GET_RETURN_FUNC_SELECTOR = bytes4(keccak256("getReturn(address,address,uint256)"));

    // using a static call to get the return from older converters
    function getReturn(
        IConverter _dest,
        IReserveToken _sourceToken,
        IReserveToken _targetToken,
        uint256 _amount
    ) internal view returns (uint256, uint256) {
        bytes memory data = abi.encodeWithSelector(GET_RETURN_FUNC_SELECTOR, _sourceToken, _targetToken, _amount);
        (bool success, bytes memory returnData) = address(_dest).staticcall(data);

        if (success) {
            if (returnData.length == 64) {
                return abi.decode(returnData, (uint256, uint256));
            }

            if (returnData.length == 32) {
                return (abi.decode(returnData, (uint256)), 0);
            }
        }

        return (0, 0);
    }

    bytes4 private constant IS_V28_OR_HIGHER_FUNC_SELECTOR = bytes4(keccak256("isV28OrHigher()"));

    // using a static call to identify converter version
    // can't rely on the version number since the function had a different signature in older converters
    function isV28OrHigherConverter(IConverter _converter) internal view returns (bool) {
        bytes memory data = abi.encodeWithSelector(IS_V28_OR_HIGHER_FUNC_SELECTOR);
        (bool success, bytes memory returnData) = address(_converter).staticcall{ gas: 4000 }(data);

        if (success && returnData.length == 32) {
            return abi.decode(returnData, (bool));
        }

        return false;
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function getReturnByPath(address[] memory _path, uint256 _amount) public view returns (uint256, uint256) {
        return (rateByPath(_path, _amount), 0);
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function convertByPath(
        address[] memory _path,
        uint256 _amount,
        uint256 _minReturn,
        address payable _beneficiary,
        address, /* _affiliateAccount */
        uint256 /* _affiliateFee */
    ) public payable override returns (uint256) {
        return convertByPath2(_path, _amount, _minReturn, _beneficiary);
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function convert(
        address[] memory _path,
        uint256 _amount,
        uint256 _minReturn
    ) public payable returns (uint256) {
        return convertByPath2(_path, _amount, _minReturn, address(0));
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function convert2(
        address[] memory _path,
        uint256 _amount,
        uint256 _minReturn,
        address, /* _affiliateAccount */
        uint256 /* _affiliateFee */
    ) public payable returns (uint256) {
        return convertByPath2(_path, _amount, _minReturn, address(0));
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function convertFor(
        address[] memory _path,
        uint256 _amount,
        uint256 _minReturn,
        address payable _beneficiary
    ) public payable returns (uint256) {
        return convertByPath2(_path, _amount, _minReturn, _beneficiary);
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function convertFor2(
        address[] memory _path,
        uint256 _amount,
        uint256 _minReturn,
        address payable _beneficiary,
        address, /* _affiliateAccount */
        uint256 /* _affiliateFee */
    ) public payable greaterThanZero(_minReturn) returns (uint256) {
        return convertByPath2(_path, _amount, _minReturn, _beneficiary);
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function claimAndConvert(
        address[] memory _path,
        uint256 _amount,
        uint256 _minReturn
    ) public returns (uint256) {
        return convertByPath2(_path, _amount, _minReturn, address(0));
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function claimAndConvert2(
        address[] memory _path,
        uint256 _amount,
        uint256 _minReturn,
        address, /* _affiliateAccount */
        uint256 /* _affiliateFee */
    ) public returns (uint256) {
        return convertByPath2(_path, _amount, _minReturn, address(0));
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function claimAndConvertFor(
        address[] memory _path,
        uint256 _amount,
        uint256 _minReturn,
        address payable _beneficiary
    ) public returns (uint256) {
        return convertByPath2(_path, _amount, _minReturn, _beneficiary);
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function claimAndConvertFor2(
        address[] memory _path,
        uint256 _amount,
        uint256 _minReturn,
        address payable _beneficiary,
        address, /* _affiliateAccount */
        uint256 /* _affiliateFee */
    ) public returns (uint256) {
        return convertByPath2(_path, _amount, _minReturn, _beneficiary);
    }
}
