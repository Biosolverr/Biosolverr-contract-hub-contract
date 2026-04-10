// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockImplementation {
    address public owner;
    uint256 public value;
    bool    private _initialized;

    error AlreadyInitialized();
    error NotOwner();

    function initialize(address _owner) external {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;
        owner = _owner;
    }

    function setValue(uint256 _value) external {
        if (msg.sender != owner) revert NotOwner();
        value = _value;
    }

    function ping() external pure returns (bool) { return true; }
}
