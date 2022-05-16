// SPDX-License-Identifier: MIT

// COPIED FROM https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol
// Copyright 2020 Compound Labs, Inc.
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Ctrl+f for XXX to see all the modifications.

// XXX: pragma solidity ^0.5.16;
pragma solidity 0.6.12;

// XXX: import "./SafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract CustomMasterChefJoeV2Timelock {
    using SafeMath for uint256;

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MINIMUM_DELAY = 12 hours;
    uint256 public constant MAXIMUM_DELAY = 30 days;

    string private constant SET_DEV_PERCENT_SIG = "setDevPercent(uint256)";
    string private constant SET_TREASURY_PERCENT_SIG = "setTreasuryPercent(uint256)";
    string private constant SET_INVESTOR_PERCENT_SIG = "setInvestorPercent(uint256)";
    string private constant UPDATE_EMISSION_RATE_SIG = "updateEmissionRate(uint256)";

    address public admin;
    address public pendingAdmin;
    uint256 public delay;
    uint256 public devPercentLimit;
    uint256 public investorPercentLimit;
    uint256 public treasuryPercentLimit;
    uint256 public joePerSecLimit;
    bool public admin_initialized;

    mapping(bytes32 => bool) public queuedTransactions;

    modifier withinLimits(string memory signature, bytes memory data) {
        if (keccak256(bytes(signature)) == keccak256(bytes(SET_DEV_PERCENT_SIG))) {
            uint256 devPercent = abi.decode(data, (uint256));
            require(
                devPercent <= devPercentLimit,
                "CustomMasterChefJoeV2Timelock::withinLimits: devPercent must not exceed limit."
            );
        } else if (keccak256(bytes(signature)) == keccak256(bytes(SET_TREASURY_PERCENT_SIG))) {
            uint256 treasuryPercent = abi.decode(data, (uint256));
            require(
                treasuryPercent <= treasuryPercentLimit,
                "CustomMasterChefJoeV2Timelock::withinLimits: treasuryPercent must not exceed limit."
            );
        } else if (keccak256(bytes(signature)) == keccak256(bytes(SET_INVESTOR_PERCENT_SIG))) {
            uint256 investorPercent = abi.decode(data, (uint256));
            require(
                investorPercent <= investorPercentLimit,
                "CustomMasterChefJoeV2Timelock::withinLimits: investorPercent must not exceed limit."
            );
        } else if (keccak256(bytes(signature)) == keccak256(bytes(UPDATE_EMISSION_RATE_SIG))) {
            uint256 joePerSec = abi.decode(data, (uint256));
            require(
                joePerSec <= joePerSecLimit,
                "CustomMasterChefJoeV2Timelock::withinLimits: joePerSec must not exceed limit."
            );
        }
        _;
    }

    constructor(
        address admin_,
        uint256 delay_,
        uint256 devPercentLimit_,
        uint256 treasuryPercentLimit_,
        uint256 investorPercentLimit_,
        uint256 joePerSecLimit_
    ) public {
        require(
            delay_ >= MINIMUM_DELAY,
            "CustomMasterChefJoeV2Timelock::constructor: Delay must exceed minimum delay."
        );
        require(
            delay_ <= MAXIMUM_DELAY,
            "CustomMasterChefJoeV2Timelock::constructor: Delay must not exceed maximum delay."
        );

        admin = admin_;
        delay = delay_;
        admin_initialized = false;
        devPercentLimit = devPercentLimit_;
        treasuryPercentLimit = treasuryPercentLimit_;
        investorPercentLimit = investorPercentLimit_;
        joePerSecLimit = joePerSecLimit_;
    }

    // XXX: function() external payable { }
    receive() external payable {}

    function setDelay(uint256 delay_) public {
        require(
            msg.sender == address(this),
            "CustomMasterChefJoeV2Timelock::setDelay: Call must come from CustomMasterChefJoeV2Timelock."
        );
        require(delay_ >= MINIMUM_DELAY, "CustomMasterChefJoeV2Timelock::setDelay: Delay must exceed minimum delay.");
        require(
            delay_ <= MAXIMUM_DELAY,
            "CustomMasterChefJoeV2Timelock::setDelay: Delay must not exceed maximum delay."
        );
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptAdmin() public {
        require(
            msg.sender == pendingAdmin,
            "CustomMasterChefJoeV2Timelock::acceptAdmin: Call must come from pendingAdmin."
        );
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    function setPendingAdmin(address pendingAdmin_) public {
        // allows one time setting of admin for deployment purposes
        if (admin_initialized) {
            require(
                msg.sender == address(this),
                "CustomMasterChefJoeV2Timelock::setPendingAdmin: Call must come from CustomMasterChefJoeV2Timelock."
            );
        } else {
            require(
                msg.sender == admin,
                "CustomMasterChefJoeV2Timelock::setPendingAdmin: First call must come from admin."
            );
            admin_initialized = true;
        }
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public withinLimits(signature, data) returns (bytes32) {
        require(msg.sender == admin, "CustomMasterChefJoeV2Timelock::queueTransaction: Call must come from admin.");
        require(
            eta >= getBlockTimestamp().add(delay),
            "CustomMasterChefJoeV2Timelock::queueTransaction: Estimated execution block must satisfy delay."
        );

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public {
        require(msg.sender == admin, "CustomMasterChefJoeV2Timelock::cancelTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public payable returns (bytes memory) {
        require(msg.sender == admin, "CustomMasterChefJoeV2Timelock::executeTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(
            queuedTransactions[txHash],
            "CustomMasterChefJoeV2Timelock::executeTransaction: Transaction hasn't been queued."
        );
        require(
            getBlockTimestamp() >= eta,
            "CustomMasterChefJoeV2Timelock::executeTransaction: Transaction hasn't surpassed time lock."
        );
        require(
            getBlockTimestamp() <= eta.add(GRACE_PERIOD),
            "CustomMasterChefJoeV2Timelock::executeTransaction: Transaction is stale."
        );

        queuedTransactions[txHash] = false;

        bytes memory callData;

        callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call.value(value)(callData);
        require(success, "CustomMasterChefJoeV2Timelock::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}
