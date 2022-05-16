// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.5.0;

import "./interfaces/IAssimilator.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";

library Assimilators {

    using ABDKMath64x64 for int128;
    IAssimilator constant iAsmltr = IAssimilator(address(0));

    function delegate(address _callee, bytes memory _data) internal returns (bytes memory) {

        (bool _success, bytes memory returnData_) = _callee.delegatecall(_data);

        assembly { if eq(_success, 0) { revert(add(returnData_, 0x20), returndatasize()) } }

        return returnData_;

    }

    function viewRawAmount (address _assim, int128 _amt) internal view returns (uint256 amount_) {

        amount_ = IAssimilator(_assim).viewRawAmount(_amt);

    }

    function viewNumeraireAmount (address _assim, uint256 _amt) internal view returns (int128 amt_) {

        amt_ = IAssimilator(_assim).viewNumeraireAmount(_amt);

    }

    function viewNumeraireAmountAndBalance (address _assim, uint256 _amt) internal view returns (int128 amt_, int128 bal_) {

        ( amt_, bal_ ) = IAssimilator(_assim).viewNumeraireAmountAndBalance(address(this), _amt);

    }

    function viewNumeraireBalance (address _assim) internal view returns (int128 bal_) {

        bal_ = IAssimilator(_assim).viewNumeraireBalance(address(this));

    }

    function intakeRaw (address _assim, uint256 _amt) internal returns (int128 amt_) {

        bytes memory data = abi.encodeWithSelector(iAsmltr.intakeRaw.selector, _amt);

        amt_ = abi.decode(delegate(_assim, data), (int128));

    }

    function intakeRawAndGetBalance (address _assim, uint256 _amt) internal returns (int128 amt_, int128 bal_) {

        bytes memory data = abi.encodeWithSelector(iAsmltr.intakeRawAndGetBalance.selector, _amt);

        ( amt_, bal_ ) = abi.decode(delegate(_assim, data), (int128,int128));

    }

    function intakeNumeraire (address _assim, int128 _amt) internal returns (uint256 amt_) {

        bytes memory data = abi.encodeWithSelector(iAsmltr.intakeNumeraire.selector, _amt);

        amt_ = abi.decode(delegate(_assim, data), (uint256));

    }

    function outputRaw (address _assim, address _dst, uint256 _amt) internal returns (int128 amt_ ) {

        bytes memory data = abi.encodeWithSelector(iAsmltr.outputRaw.selector, _dst, _amt);

        amt_ = abi.decode(delegate(_assim, data), (int128));

        amt_ = amt_.neg();

    }

    function outputRawAndGetBalance (address _assim, address _dst, uint256 _amt) internal returns (int128 amt_, int128 bal_) {

        bytes memory data = abi.encodeWithSelector(iAsmltr.outputRawAndGetBalance.selector, _dst, _amt);

        ( amt_, bal_ ) = abi.decode(delegate(_assim, data), (int128,int128));

        amt_ = amt_.neg();

    }

    function outputNumeraire (address _assim, address _dst, int128 _amt) internal returns (uint256 amt_) {

        bytes memory data = abi.encodeWithSelector(iAsmltr.outputNumeraire.selector, _dst, _amt.abs());

        amt_ = abi.decode(delegate(_assim, data), (uint256));

    }

}