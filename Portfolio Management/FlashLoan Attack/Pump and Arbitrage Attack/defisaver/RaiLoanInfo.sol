pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../DS/DSMath.sol";
import "../interfaces/reflexer/IGetSafes.sol";
import "../interfaces/reflexer/ISAFEEngine.sol";
import "../interfaces/reflexer/ISAFEManager.sol";
import "../interfaces/reflexer/IOracleRelayer.sol";
import "../interfaces/reflexer/IMedianOracle.sol";
import "../interfaces/reflexer/ITaxCollector.sol";

contract RaiLoanInfo is DSMath {
    // mainnet
    address public constant GET_SAFES_ADDR = 0xdf4BC9aA98cC8eCd90Ba2BEe73aD4a1a9C8d202B;
    address public constant MANAGER_ADDR = 0xEfe0B4cA532769a3AE758fD82E1426a03A94F185;
    address public constant SAFE_ENGINE_ADDRESS = 0xCC88a9d330da1133Df3A7bD823B95e52511A6962;
    address public constant ORACLE_RELAYER_ADDRESS = 0x4ed9C0dCa0479bC64d8f4EB3007126D5791f7851;
    address public constant MEDIAN_ORACLE_ADDRESS = 0x12A5E1c81B10B264A575930aEae80681DDF595fe;
    address public constant TAX_COLLECTOR_ADDRESS = 0xcDB05aEda142a1B0D6044C09C64e4226c1a281EB;

    // kovan
    // address public constant GET_SAFES_ADDR = 0x702dcf4a8C3bBBd243477D5704fc45F2762D3826;
    // address public constant MANAGER_ADDR = 0x807C8eCb73d9c8203d2b1369E678098B9370F2EA;
    // address public constant SAFE_ENGINE_ADDRESS = 0x7f63fE955fFF8EA474d990f1Fc8979f2C650edbE;
    // address public constant ORACLE_RELAYER_ADDRESS = 0xE5Ae4E49bEA485B5E5172EE6b1F99243cB15225c;
    // address public constant MEDIAN_ORACLE_ADDRESS = 0x82bEAd00751EFA3286c9Dd17e4Ea2570916B3944;
    // address public constant TAX_COLLECTOR_ADDRESS = 0xc1a94C5ad9FCD79b03F79B34d8C0B0C8192fdc16;

    struct SafeInfo {
        uint256 safeId;
        uint256 coll;
        uint256 debt;
        address safeAddr;
        bytes32 collType;
    }

    struct CollInfo {
        uint256 debtCeiling;
        uint256 currDebtAmount;
        uint256 currRate;
        uint256 dust;
        uint256 safetyPrice;
        uint256 liqPrice;
        uint256 assetPrice;
        uint256 liqRatio;
        uint256 stabilityFee;
    }

    struct RaiInfo {
        uint256 redemptionPrice;
        uint256 currRaiPrice;
        uint256 redemptionRate;
    }

    function getCollateralTypeInfo(bytes32 _collType)
        public
        returns (CollInfo memory collInfo)
    {
        (
            uint256 debtAmount,
            uint256 accumulatedRates,
            uint256 safetyPrice,
            uint256 debtCeiling,
            uint256 debtFloor,
            uint256 liquidationPrice
        ) = ISAFEEngine(SAFE_ENGINE_ADDRESS).collateralTypes(_collType);

        (, uint liqRatio) = IOracleRelayer(ORACLE_RELAYER_ADDRESS).collateralTypes(_collType);

        (uint stabilityFee,) = ITaxCollector(TAX_COLLECTOR_ADDRESS).collateralTypes(_collType);


        collInfo = CollInfo({
            debtCeiling: debtCeiling,
            currDebtAmount: debtAmount,
            currRate: accumulatedRates,
            dust: debtFloor,
            safetyPrice: safetyPrice,
            liqPrice: liquidationPrice,
            assetPrice: getPrice(_collType),
            liqRatio: liqRatio,
            stabilityFee: stabilityFee
        });
    }

    function getCollAndRaiInfo(bytes32 _collType)
        public
        returns (CollInfo memory collInfo, RaiInfo memory raiInfo) {
            collInfo = getCollateralTypeInfo(_collType);
            raiInfo = getRaiInfo();
        }

    function getPrice(bytes32 _collType) public returns (uint256) {
        (, uint256 safetyCRatio) =
            IOracleRelayer(ORACLE_RELAYER_ADDRESS).collateralTypes(_collType);
        (, , uint256 safetyPrice, , , ) =
            ISAFEEngine(SAFE_ENGINE_ADDRESS).collateralTypes(_collType);

        uint256 redemptionPrice = IOracleRelayer(ORACLE_RELAYER_ADDRESS).redemptionPrice();

        return rmul(rmul(safetyPrice, redemptionPrice), safetyCRatio);
    }

    function getRaiInfo() public returns (RaiInfo memory raiInfo) {
        raiInfo = RaiInfo({
            redemptionPrice: IOracleRelayer(ORACLE_RELAYER_ADDRESS).redemptionPrice(),
            currRaiPrice: IMedianOracle(MEDIAN_ORACLE_ADDRESS).read(),
            redemptionRate: IOracleRelayer(ORACLE_RELAYER_ADDRESS).redemptionRate()
        });
    }

    function getSafeInfo(uint256 _safeId) public view returns (SafeInfo memory safeInfo) {
        address safeAddr = ISAFEManager(MANAGER_ADDR).safes(_safeId);
        bytes32 collType = ISAFEManager(MANAGER_ADDR).collateralTypes(_safeId);

        (uint256 coll, uint256 debt) = ISAFEEngine(SAFE_ENGINE_ADDRESS).safes(collType, safeAddr);

        safeInfo = SafeInfo({
            safeId: _safeId,
            coll: coll,
            debt: debt,
            safeAddr: safeAddr,
            collType: collType
        });
    }

    function getUserSafes(address _user)
        public
        view
        returns (
            uint256[] memory ids,
            address[] memory safes,
            bytes32[] memory collateralTypes
        )
    {
        return IGetSafes(GET_SAFES_ADDR).getSafesAsc(MANAGER_ADDR, _user);
    }

    function getUserSafesFullInfo(address _user) public view returns (SafeInfo[] memory safeInfos) {
        (uint256[] memory ids, , ) = getUserSafes(_user);

        safeInfos = new SafeInfo[](ids.length);

        for (uint256 i = 0; i < ids.length; ++i) {
            safeInfos[i] = getSafeInfo(ids[i]);
        }
    }

    function getFullInfo(address _user, bytes32 _collType)
        public
        returns (
            CollInfo memory collInfo,
            RaiInfo memory raiInfo,
            SafeInfo[] memory safeInfos
        )
    {
        collInfo = getCollateralTypeInfo(_collType);
        raiInfo = getRaiInfo();
        safeInfos = getUserSafesFullInfo(_user);
    }
}
