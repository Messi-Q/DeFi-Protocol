// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/ProxyAdmin.sol";

import "../interface/IGovernor.sol";
import "../interface/ILiquidityPool.sol";
import "../interface/IProxyAdmin.sol";
import "../interface/IPoolCreator.sol";

import "./Tracer.sol";
import "./VersionControl.sol";
import "./Variables.sol";
import "./AccessControl.sol";

abstract contract PoolCreatorV1 is
    Initializable,
    Tracer,
    VersionControl,
    Variables,
    AccessControl,
    IPoolCreator
{
    using AddressUpgradeable for address;

    IProxyAdmin public override upgradeAdmin;

    event CreateLiquidityPool(
        bytes32 versionKey,
        address indexed liquidityPool,
        address indexed governor,
        address indexed operator,
        address shareToken, //  downward compatibility for offline infrastructure
        address collateral,
        uint256 collateralDecimals,
        bytes initData
    );
    event UpgradeLiquidityPool(
        bytes32 versionKey,
        address indexed liquidityPool,
        address indexed governor
    );

    function initialize(
        address symbolService,
        address globalVault,
        int256 globalVaultFeeRate
    ) external initializer {
        __Ownable_init();
        __Variables_init(symbolService, globalVault, globalVaultFeeRate);

        upgradeAdmin = IProxyAdmin(address(new ProxyAdmin()));
    }

    /**
     * @notice Owner of version control.
     */
    function owner() public view virtual override(VersionControl, Variables) returns (address) {
        return OwnableUpgradeable.owner();
    }

    /**
     * @notice  Create a liquidity pool with the latest version.
     *          The sender will be the operator of pool.
     *
     * @param   collateral              he collateral address of the liquidity pool.
     * @param   collateralDecimals      The collateral's decimals of the liquidity pool.
     * @param   nonce                   A random nonce to calculate the address of deployed contracts.
     * @param   initData                A bytes array contains data to initialize new created liquidity pool.
     * @return  liquidityPool           The address of the created liquidity pool.
     */
    function createLiquidityPool(
        address collateral,
        uint256 collateralDecimals,
        int256 nonce,
        bytes calldata initData
    ) external override returns (address liquidityPool, address governor) {
        (liquidityPool, governor) = _createLiquidityPoolWith(
            getLatestVersion(),
            collateral,
            collateralDecimals,
            nonce,
            initData
        );
    }

    // /**
    //  * @notice  Create a liquidity pool with the specific version. The operator will be the sender.
    //  *
    //  * @param   versionKey          The key of the version to create.
    //  * @param   collateral          The collateral address of the liquidity pool.
    //  * @param   collateralDecimals  The collateral's decimals of the liquidity pool.
    //  * @param   nonce               A random nonce to calculate the address of deployed contracts.
    //  * @param   initData            A bytes array contains data to initialize new created liquidity pool.
    //  * @return  liquidityPool       The address of the created liquidity pool.
    //  * @return  governor            The address of the created governor.
    //  */
    // function createLiquidityPoolWith(
    //     bytes32 versionKey,
    //     address collateral,
    //     uint256 collateralDecimals,
    //     int256 nonce,
    //     bytes memory initData
    // ) external override returns (address liquidityPool, address governor) {
    //     (liquidityPool, governor) = _createLiquidityPoolWith(
    //         versionKey,
    //         collateral,
    //         collateralDecimals,
    //         nonce,
    //         initData
    //     );
    // }

    /**
     * @notice  Upgrade a liquidity pool and governor pair then call a patch function on the upgraded contract (optional).
     *          This method checks the sender and forwards the request to ProxyAdmin to do upgrading.
     *
     * @param   targetVersionKey        The key of version to be upgrade up. The target version must be compatiable with
     *                                  current version.
     * @param   dataForLiquidityPool    The patch calldata for upgraded liquidity pool.
     * @param   dataForGovernor         The patch calldata of upgraded governor.
     */
    function upgradeToAndCall(
        bytes32 targetVersionKey,
        bytes memory dataForLiquidityPool,
        bytes memory dataForGovernor
    ) external override {
        (
            address liquidityPool,
            address governor,
            address liquidityPoolTemplate,
            address governorTemplate
        ) = _getUpgradeContext(targetVersionKey);

        if (dataForLiquidityPool.length > 0) {
            upgradeAdmin.upgradeAndCall(liquidityPool, liquidityPoolTemplate, dataForLiquidityPool);
        } else {
            upgradeAdmin.upgrade(liquidityPool, liquidityPoolTemplate);
        }
        if (dataForGovernor.length > 0) {
            upgradeAdmin.upgradeAndCall(governor, governorTemplate, dataForGovernor);
        } else {
            upgradeAdmin.upgrade(governor, governorTemplate);
        }
        _updateDeployedInstances(targetVersionKey, liquidityPool, governor);

        emit UpgradeLiquidityPool(targetVersionKey, liquidityPool, governor);
    }

    /**
     * @dev     Create a liquidity pool with the specific version. The operator will be the sender.
     *
     * @param   versionKey          The address of version
     * @param   collateral          The collateral address of the liquidity pool.
     * @param   collateralDecimals  The collateral's decimals of the liquidity pool.
     * @param   nonce               A random nonce to calculate the address of deployed contracts.
     * @param   initData            A bytes array contains data to initialize new created liquidity pool.
     * @return  liquidityPool       The address of the created liquidity pool.
     * @return  governor            The address of the created governor.
     */
    function _createLiquidityPoolWith(
        bytes32 versionKey,
        address collateral,
        uint256 collateralDecimals,
        int256 nonce,
        bytes memory initData
    ) internal returns (address liquidityPool, address governor) {
        require(isVersionKeyValid(versionKey), "invalid version");
        // initialize
        address operator = msg.sender;
        (address liquidityPoolTemplate, address governorTemplate, ) = getVersion(versionKey);
        bytes32 salt = keccak256(abi.encode(versionKey, collateral, initData, nonce));

        liquidityPool = _createUpgradeableProxy(liquidityPoolTemplate, salt);
        governor = _createUpgradeableProxy(governorTemplate, salt);

        ILiquidityPool(liquidityPool).initialize(
            operator,
            collateral,
            collateralDecimals,
            governor,
            initData
        );
        IGovernor(governor).initialize(
            "MCDEX Share Token",
            "STK",
            liquidityPool,
            liquidityPool,
            getMCBToken(),
            address(this)
        );
        // register pool to tracer
        _registerLiquidityPool(liquidityPool, operator);
        _updateDeployedInstances(versionKey, liquidityPool, governor);
        // [EVENT UPDATE]
        emit CreateLiquidityPool(
            versionKey,
            liquidityPool,
            governor,
            operator,
            governor,
            collateral,
            collateralDecimals,
            initData
        );
    }

    /**
     * @dev     Create an upgradeable proxy contract of the implementation of liquidity pool.
     *
     * @param   implementation The address of the implementation.
     * @param   salt        The random number for create2.
     * @return  instance    The address of the created upgradeable proxy contract.
     */
    function _createUpgradeableProxy(address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        require(implementation.isContract(), "implementation must be contract");
        bytes memory deploymentData = abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(implementation, address(upgradeAdmin), "")
        );
        assembly {
            instance := create2(0x0, add(0x20, deploymentData), mload(deploymentData), salt)
        }
        require(instance != address(0), "create2 call failed");
    }

    /**
     * @dev Validate sender:
     *      - the transaction must be sent from a governor.
     *      - the sender governor and its liquidity pool must be already registered.
     *      - the target version must be compatible with the current version.
     */
    function _getUpgradeContext(bytes32 targetVersionKey)
        internal
        view
        returns (
            address liquidityPool,
            address governor,
            address liquidityPoolTemplate,
            address governorTemplate
        )
    {
        governor = _msgSender();
        require(governor.isContract(), "sender must be a contract");
        liquidityPool = IGovernor(governor).getTarget();
        require(isLiquidityPool(liquidityPool), "sender is not the governor of a registered pool");

        bytes32 deployedAddressHash = _getVersionHash(liquidityPool, governor);
        bytes32 baseVersionKey = _deployedVersions[deployedAddressHash];
        require(
            isVersionCompatible(targetVersionKey, baseVersionKey),
            "the target version is not compatible"
        );
        (liquidityPoolTemplate, governorTemplate, ) = getVersion(targetVersionKey);
    }
}
