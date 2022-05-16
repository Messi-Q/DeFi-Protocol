// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.6.12;

import "../utility/ContractRegistryClient.sol";

import "../token/ReserveToken.sol";

import "./interfaces/IConverter.sol";
import "./interfaces/IConverterUpgrader.sol";
import "./interfaces/IConverterFactory.sol";

interface ILegacyConverterVersion45 is IConverter {
    function withdrawTokens(
        IReserveToken _token,
        address _to,
        uint256 _amount
    ) external;

    function withdrawETH(address payable _to) external;
}

/**
 * @dev This contract contract allows upgrading an older converter contract (0.4 and up)
 * to the latest version.
 * To begin the upgrade process, simply execute the 'upgrade' function.
 * At the end of the process, the ownership of the newly upgraded converter will be transferred
 * back to the original owner and the original owner will need to execute the 'acceptOwnership' function.
 *
 * The address of the new converter is available in the ConverterUpgrade event.
 *
 * Note that for older converters that don't yet have the 'upgrade' function, ownership should first
 * be transferred manually to the ConverterUpgrader contract using the 'transferOwnership' function
 * and then the upgrader 'upgrade' function should be executed directly.
 */
contract ConverterUpgrader is IConverterUpgrader, ContractRegistryClient {
    using ReserveToken for IReserveToken;

    /**
     * @dev triggered when the contract accept a converter ownership
     *
     * @param _converter   converter address
     * @param _owner       new owner - local upgrader address
     */
    event ConverterOwned(IConverter indexed _converter, address indexed _owner);

    /**
     * @dev triggered when the upgrading process is done
     *
     * @param _oldConverter    old converter address
     * @param _newConverter    new converter address
     */
    event ConverterUpgrade(address indexed _oldConverter, address indexed _newConverter);

    /**
     * @dev initializes a new ConverterUpgrader instance
     *
     * @param _registry    address of a contract registry contract
     */
    constructor(IContractRegistry _registry) public ContractRegistryClient(_registry) {}

    /**
     * @dev upgrades an old converter to the latest version
     * will throw if ownership wasn't transferred to the upgrader before calling this function.
     * ownership of the new converter will be transferred back to the original owner.
     * fires the ConverterUpgrade event upon success.
     * can only be called by a converter
     *
     * @param _version old converter version
     */
    function upgrade(bytes32 _version) external override {
        upgradeOld(IConverter(msg.sender), _version);
    }

    /**
     * @dev upgrades an old converter to the latest version
     * will throw if ownership wasn't transferred to the upgrader before calling this function.
     * ownership of the new converter will be transferred back to the original owner.
     * fires the ConverterUpgrade event upon success.
     * can only be called by a converter
     *
     * @param _version old converter version
     */
    function upgrade(uint16 _version) external override {
        upgrade(IConverter(msg.sender), _version);
    }

    /**
     * @dev upgrades an old converter to the latest version
     * will throw if ownership wasn't transferred to the upgrader before calling this function.
     * ownership of the new converter will be transferred back to the original owner.
     * fires the ConverterUpgrade event upon success.
     *
     * @param _converter old converter contract address
     */
    function upgradeOld(
        IConverter _converter,
        bytes32 /* _version */
    ) public {
        // the upgrader doesn't require the version for older converters
        upgrade(_converter, 0);
    }

    /**
     * @dev upgrades an old converter to the latest version
     * will throw if ownership wasn't transferred to the upgrader before calling this function.
     * ownership of the new converter will be transferred back to the original owner.
     * fires the ConverterUpgrade event upon success.
     *
     * @param _converter old converter contract address
     * @param _version old converter version
     */
    function upgrade(IConverter _converter, uint16 _version) private {
        IConverter converter = IConverter(_converter);
        address prevOwner = converter.owner();
        acceptConverterOwnership(converter);
        IConverter newConverter = createConverter(converter);
        copyReserves(converter, newConverter);
        copyConversionFee(converter, newConverter);
        transferReserveBalances(converter, newConverter, _version);
        IConverterAnchor anchor = converter.token();

        if (anchor.owner() == address(converter)) {
            converter.transferTokenOwnership(address(newConverter));
            newConverter.acceptAnchorOwnership();
        }

        converter.transferOwnership(prevOwner);
        newConverter.transferOwnership(prevOwner);

        newConverter.onUpgradeComplete();

        emit ConverterUpgrade(address(converter), address(newConverter));
    }

    /**
     * @dev the first step when upgrading a converter is to transfer the ownership to the local contract.
     * the upgrader contract then needs to accept the ownership transfer before initiating
     * the upgrade process.
     * fires the ConverterOwned event upon success
     *
     * @param _oldConverter       converter to accept ownership of
     */
    function acceptConverterOwnership(IConverter _oldConverter) private {
        _oldConverter.acceptOwnership();
        emit ConverterOwned(_oldConverter, address(this));
    }

    /**
     * @dev creates a new converter with same basic data as the original old converter
     * the newly created converter will have no reserves at this step.
     *
     * @param _oldConverter    old converter contract address
     *
     * @return the new converter  new converter contract address
     */
    function createConverter(IConverter _oldConverter) private returns (IConverter) {
        IConverterAnchor anchor = _oldConverter.token();
        uint32 maxConversionFee = _oldConverter.maxConversionFee();
        uint16 reserveTokenCount = _oldConverter.connectorTokenCount();

        // determine new converter type
        uint16 newType = 0;
        // new converter - get the type from the converter itself
        if (isV28OrHigherConverter(_oldConverter)) {
            newType = _oldConverter.converterType();
        } else if (reserveTokenCount > 1) {
            // old converter - if it has 1 reserve token, the type is a liquid token, otherwise the type liquidity pool
            newType = 1;
        }

        if (newType == 1 && reserveTokenCount == 2) {
            (, uint32 weight0, , , ) = _oldConverter.connectors(_oldConverter.connectorTokens(0));
            (, uint32 weight1, , , ) = _oldConverter.connectors(_oldConverter.connectorTokens(1));
            if (weight0 == PPM_RESOLUTION / 2 && weight1 == PPM_RESOLUTION / 2) {
                newType = 3;
            }
        }

        IConverterFactory converterFactory = IConverterFactory(addressOf(CONVERTER_FACTORY));
        IConverter converter = converterFactory.createConverter(newType, anchor, registry, maxConversionFee);

        converter.acceptOwnership();
        return converter;
    }

    /**
     * @dev copies the reserves from the old converter to the new one.
     * note that this will not work for an unlimited number of reserves due to block gas limit constraints.
     *
     * @param _oldConverter    old converter contract address
     * @param _newConverter    new converter contract address
     */
    function copyReserves(IConverter _oldConverter, IConverter _newConverter) private {
        uint16 reserveTokenCount = _oldConverter.connectorTokenCount();

        for (uint16 i = 0; i < reserveTokenCount; i++) {
            IReserveToken reserveAddress = _oldConverter.connectorTokens(i);
            (, uint32 weight, , , ) = _oldConverter.connectors(reserveAddress);

            _newConverter.addReserve(reserveAddress, weight);
        }
    }

    /**
     * @dev copies the conversion fee from the old converter to the new one
     *
     * @param _oldConverter    old converter contract address
     * @param _newConverter    new converter contract address
     */
    function copyConversionFee(IConverter _oldConverter, IConverter _newConverter) private {
        uint32 conversionFee = _oldConverter.conversionFee();
        _newConverter.setConversionFee(conversionFee);
    }

    /**
     * @dev transfers the balance of each reserve in the old converter to the new one.
     * note that the function assumes that the new converter already has the exact same number of reserves
     * also, this will not work for an unlimited number of reserves due to block gas limit constraints.
     *
     * @param _oldConverter    old converter contract address
     * @param _newConverter    new converter contract address
     * @param _version old converter version
     */
    function transferReserveBalances(
        IConverter _oldConverter,
        IConverter _newConverter,
        uint16 _version
    ) private {
        if (_version <= 45) {
            transferReserveBalancesVersion45(ILegacyConverterVersion45(address(_oldConverter)), _newConverter);

            return;
        }

        _oldConverter.transferReservesOnUpgrade(address(_newConverter));
    }

    /**
     * @dev transfers the balance of each reserve in the old converter to the new one.
     * note that the function assumes that the new converter already has the exact same number of reserves
     * also, this will not work for an unlimited number of reserves due to block gas limit constraints.
     *
     * @param _oldConverter old converter contract address
     * @param _newConverter new converter contract address
     */
    function transferReserveBalancesVersion45(ILegacyConverterVersion45 _oldConverter, IConverter _newConverter)
        private
    {
        uint16 reserveTokenCount = _oldConverter.connectorTokenCount();
        for (uint16 i = 0; i < reserveTokenCount; i++) {
            IReserveToken reserveToken = _oldConverter.connectorTokens(i);

            uint256 reserveBalance = reserveToken.balanceOf(address(_oldConverter));
            if (reserveBalance > 0) {
                if (reserveToken.isNativeToken()) {
                    _oldConverter.withdrawETH(address(_newConverter));
                } else {
                    _oldConverter.withdrawTokens(reserveToken, address(_newConverter), reserveBalance);
                }
            }
        }
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
}
