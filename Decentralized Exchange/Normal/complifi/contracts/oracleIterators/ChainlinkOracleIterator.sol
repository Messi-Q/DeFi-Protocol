// "SPDX-License-Identifier: GPL-3.0-or-later"

pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./IOracleIterator.sol";

contract ChainlinkOracleIterator is IOracleIterator {
    using SafeMath for uint256;

    uint256 private constant PHASE_OFFSET = 64;
    int256 public constant NEGATIVE_INFINITY = type(int256).min;
    uint256 private constant MAX_ITERATION = 24;

    function isOracleIterator() external pure override returns (bool) {
        return true;
    }

    function symbol() external pure override returns (string memory) {
        return "ChainlinkIterator";
    }

    function getUnderlyingValue(
        address _oracle,
        uint256 _timestamp,
        uint256[] calldata _roundHints
    ) external view override returns (int256) {
        require(_timestamp > 0, "Zero timestamp");
        require(_oracle != address(0), "Zero oracle");
        require(_roundHints.length == 1, "Wrong number of hints");
        AggregatorV3Interface oracle = AggregatorV3Interface(_oracle);

        uint80 latestRoundId;
        (latestRoundId, , , , ) = oracle.latestRoundData();

        uint80 roundHint = uint80(_roundHints[0]);
        if (roundHint == 0) {
            return getIteratedAnswer(oracle, _timestamp, latestRoundId);
        }

        uint256 phaseId;
        (phaseId, ) = parseIds(latestRoundId);

        if (checkSamePhase(roundHint, phaseId)) {
            return
                getHintedAnswer(oracle, _timestamp, roundHint, latestRoundId);
        }

        int256 answer = getIteratedAnswer(oracle, _timestamp, latestRoundId);
        if (answer == NEGATIVE_INFINITY) {
            return
                getHintedAnswer(oracle, _timestamp, roundHint, latestRoundId);
        }
        return answer;
    }

    function getHintedAnswer(
        AggregatorV3Interface _oracle,
        uint256 _timestamp,
        uint80 _roundHint,
        uint256 _latestRoundId
    ) internal view returns (int256) {
        int256 hintAnswer;
        uint256 hintTimestamp;
        (, hintAnswer, , hintTimestamp, ) = _oracle.getRoundData(_roundHint);

        require(
            hintTimestamp > 0 && hintTimestamp <= _timestamp,
            "Incorrect hint"
        );

        if (_roundHint + 1 > _latestRoundId) {
            return hintAnswer;
        }

        uint256 timestampNext;
        (, , , timestampNext, ) = _oracle.getRoundData(_roundHint + 1);
        if (timestampNext == 0 || timestampNext > _timestamp) {
            return hintAnswer;
        }

        return NEGATIVE_INFINITY;
    }

    function getIteratedAnswer(
        AggregatorV3Interface _oracle,
        uint256 _timestamp,
        uint80 _latestRoundId
    ) internal view returns (int256) {
        uint256 roundTimestamp = 0;
        int256 roundAnswer = 0;
        uint80 roundId = _latestRoundId;

        for (uint256 i = 0; i < MAX_ITERATION; i++) {
            (, roundAnswer, , roundTimestamp, ) = _oracle.getRoundData(roundId);
            roundId = roundId - 1;
            if (roundTimestamp <= _timestamp) {
                return roundAnswer;
            }
            if (roundId == 0) {
                return NEGATIVE_INFINITY;
            }
        }

        return NEGATIVE_INFINITY;
    }

    function checkSamePhase(uint80 _roundHint, uint256 _phase)
        internal
        pure
        returns (bool)
    {
        uint256 currentPhaseId;
        (currentPhaseId, ) = parseIds(_roundHint);
        return currentPhaseId == _phase;
    }

    function parseIds(uint256 _roundId) internal pure returns (uint16, uint64) {
        uint16 phaseId = uint16(_roundId >> PHASE_OFFSET);
        uint64 aggregatorRoundId = uint64(_roundId);

        return (phaseId, aggregatorRoundId);
    }
}
