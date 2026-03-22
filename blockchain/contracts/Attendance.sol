// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
interface IRegistry {
    function profiles(address _user) external view returns (string memory, bytes memory, bool);
    function canRecord(address _kiosk) external view returns (bool);
    function systemPaused() external view returns (bool);
    function isUserSuspended(address _user) external view returns (bool);
}
contract Attendance {
    address public regAddr;
    event Logged(address indexed user, string did, string infoCID, uint256 time, bool onSite, string status);
    constructor(address _regAddr) {
        require(_regAddr != address(0), "Attendance: Invalid registry");
        regAddr = _regAddr;
    }
    function record(address _user, string memory _attendanceCID, string memory _status) external {
        IRegistry registry = IRegistry(regAddr);
        require(!registry.systemPaused(), "Attendance: System paused");
        (string memory userDid, bytes memory infoCID, bool active) = registry.profiles(_user);
        require(active, "Attendance: User inactive");
        require(!registry.isUserSuspended(_user), "Attendance: User suspended");
        bool onSite = registry.canRecord(msg.sender);
        require(onSite, "Attendance: Kiosk not authorized");
        emit Logged(_user, userDid, _attendanceCID, block.timestamp, onSite, _status);
    }
}
