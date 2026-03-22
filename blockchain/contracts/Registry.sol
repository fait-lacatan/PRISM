// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
interface IPermissions {
    function isBannedNode(bytes32) external view returns (bool);
    function isNodeAuthorized(bytes32) external view returns (bool);
}
contract Registry {
    struct Profile {
        string did;
        bytes infoCID;
        bool isValid;
    }
    address public owner;
    address public pendingOwner;
    address public permissionsAddress;
    bool public systemPaused;
    mapping(address => Profile) public profiles;
    mapping(address => bool) public isBannedUser;
    mapping(address => bool) public isBannedDevice;
    mapping(address => bytes32) public kioskEnodes;
    mapping(bytes32 => address) public enodeToKiosk;
    mapping(address => bool) public kioskRegistered;
    mapping(address => bool) public isRemoteDevice;
    mapping(address => bool) public isManager;
    mapping(address => bool) private _canEnroll;
    mapping(address => bool) private _canRecord;
    mapping(address => bool) public canRevoke;
    mapping(address => bool) public canReissue;
    mapping(address => bool) public deviceSuspended;
    mapping(address => bool) public userSuspended;
    mapping(address => uint256) public userNonce;
    mapping(address => bool) public revocationPending;
    mapping(address => uint256) public revocationTimestamp;
    uint256 public constant REVOCATION_GRACE_PERIOD = 3 days;
    event UserEnrolled(address indexed user, string did, bytes infoCID);
    event StatusChanged(address indexed user, bool active);
    event RoleChanged(address indexed actor, string role, bool status);
    event EmergencyStop(bool status);
    event DeviceSuspended(address indexed device, uint256 reason);
    event DeviceReinstated(address indexed device);
    event UserBanned(address indexed user, address indexed admin);
    event DeviceBanned(address indexed device, address indexed admin);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event UserReissued(address indexed user, address indexed reissuer, string did, bytes infoCID);
    event UserSuspended(address indexed user, address indexed suspender, uint256 reason);
    event UserReinstated(address indexed user, address indexed reinstater);
    event RevocationRequested(address indexed user, address indexed requester);
    event RevocationFinalized(address indexed user, address indexed finalizer);
    event RevocationCancelled(address indexed user, address indexed canceller);
    event KioskEnodeRevoked(address indexed device, bytes32 enodeHash, address indexed revoker);
    modifier onlyOwner() {
        require(msg.sender == owner, "Registry: Not owner");
        _;
    }
    modifier onlyManager() {
        require((msg.sender == owner || isManager[msg.sender]) && !isBannedDevice[msg.sender], "Registry: Unauthorized or Banned Manager");
        _;
    }
    modifier whenNotPaused() {
        require(!systemPaused, "Registry: System paused");
        _;
    }
    constructor() {
        owner = msg.sender;
        _canEnroll[msg.sender] = true;
        _canRecord[msg.sender] = true;
        isRemoteDevice[msg.sender] = true;
        canRevoke[msg.sender] = true;
        canReissue[msg.sender] = true;
    }
    function canEnroll(address device) public view returns (bool) {
        if (!_canEnroll[device]) return false;
        if (isBannedDevice[device]) return false;
        if (deviceSuspended[device]) return false;
        bytes32 enode = kioskEnodes[device];
        if (enode != bytes32(0) && permissionsAddress != address(0)) {
            if (IPermissions(permissionsAddress).isBannedNode(enode)) return false;
        }
        return true;
    }
    function canRecord(address device) public view returns (bool) {
        if (!_canRecord[device]) return false;
        if (isBannedDevice[device]) return false;
        if (deviceSuspended[device]) return false;
        bytes32 enode = kioskEnodes[device];
        if (enode == bytes32(0)) {
            require(isRemoteDevice[device], "Unlinked Kiosk detected");
        } else if (permissionsAddress != address(0)) {
            if (IPermissions(permissionsAddress).isBannedNode(enode)) return false;
        }
        return true;
    }
    function enroll(address user, string calldata did, bytes calldata infoCID) external whenNotPaused {
        require(canEnroll(msg.sender), "Registry: Unauthorized Enroller");
        require(user != address(0), "Registry: Invalid user");
        require(bytes(did).length > 0, "Registry: DID required");
        require(bytes(profiles[user].did).length == 0, "Registry: User exists. Use reissueUser.");
        require(!isBannedUser[user], "Address permanently banned");
        profiles[user] = Profile(did, infoCID, true);
        emit UserEnrolled(user, did, infoCID);
    }
    function requestRevocation(address _user) external {
        require(canRevoke[msg.sender], "Registry: Unauthorized Revoker");
        require(!isBannedDevice[msg.sender], "Registry: Revoker is banned");
        require(profiles[_user].isValid, "Registry: User not active");
        require(!revocationPending[_user], "Registry: Already pending");
        revocationPending[_user] = true;
        revocationTimestamp[_user] = block.timestamp;
        emit RevocationRequested(_user, msg.sender);
    }
    function consentRevocation(address _user, bytes memory _userSignature) external {
        require(revocationPending[_user], "Registry: No pending revocation");
        uint256 nonce = userNonce[_user];
        bytes32 msgHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked("REVOKE_CONSENT", _user, nonce, address(this)))
        ));
        require(_recoverSigner(msgHash, _userSignature) == _user, "Registry: Invalid consent");
        userNonce[_user] = nonce + 1;
        _finalizeRevocation(_user);
        emit RevocationFinalized(_user, msg.sender);
    }
    function finalizeRevocation(address _user) external onlyManager {
        require(revocationPending[_user], "Registry: No pending revocation");
        require(block.timestamp >= revocationTimestamp[_user] + REVOCATION_GRACE_PERIOD, "Registry: Grace period active");
        _finalizeRevocation(_user);
        emit RevocationFinalized(_user, msg.sender);
    }
    function cancelRevocation(address _user) external onlyManager {
        require(revocationPending[_user], "Registry: No pending revocation");
        revocationPending[_user] = false;
        revocationTimestamp[_user] = 0;
        emit RevocationCancelled(_user, msg.sender);
    }
    function _finalizeRevocation(address _user) internal {
        profiles[_user].isValid = false;
        revocationPending[_user] = false;
        revocationTimestamp[_user] = 0;
        emit StatusChanged(_user, false);
    }
    function reissueUser(address _user, string memory _did, bytes memory _cid, bytes memory _userSignature) external whenNotPaused {
        require(canReissue[msg.sender], "Registry: Unauthorized Reissuer");
        require(!isBannedDevice[msg.sender], "Registry: Reissuer is banned");
        require(!isBannedUser[_user], "Address permanently banned");
        require(!userSuspended[_user], "Registry: User suspended");
        require(!revocationPending[_user], "Registry: Revocation pending");
        require(bytes(profiles[_user].did).length > 0, "Registry: User not found. Use enroll.");
        uint256 nonce = userNonce[_user];
        bytes32 msgHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked("REISSUE_CONSENT", _user, nonce, address(this)))
        ));
        require(_recoverSigner(msgHash, _userSignature) == _user, "Registry: Invalid consent voucher");
        userNonce[_user] = nonce + 1;
        profiles[_user] = Profile(_did, _cid, true);
        emit UserReissued(_user, msg.sender, _did, _cid);
    }
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Registry: Invalid address");
        pendingOwner = newOwner;
    }
    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Registry: Not pending owner");
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }
    function setPermissionsAddress(address _permissions) external onlyOwner {
        require(_permissions != address(0), "Registry: Invalid address");
        permissionsAddress = _permissions;
    }
    function setManager(address _manager, bool _status) external onlyOwner {
        require(_manager != address(0), "Registry: Invalid address");
        require(_manager != owner, "Registry: Cannot modify Owner");
        isManager[_manager] = _status;
        emit RoleChanged(_manager, "MANAGER", _status);
    }
    function setEnrollAuth(address _actor, bool _status) external onlyManager {
        require(permissionsAddress != address(0), "System not linked");
        require(!isBannedDevice[_actor], "Device permanently banned");
        require(_actor != address(0), "Registry: Invalid address");
        if (_status) {
            require(kioskRegistered[_actor], "Registry: Kiosk must be linked to enode first");
        }
        if (_actor == owner) {
            require(_status, "Registry: Cannot revoke Owner privileges");
        }
        _canEnroll[_actor] = _status;
        emit RoleChanged(_actor, "ENROLL", _status);
    }
    function setKioskRecordAuth(address _actor, bool _status) external onlyManager {
        require(permissionsAddress != address(0), "System not linked");
        require(!isBannedDevice[_actor], "Device permanently banned");
        require(_actor != address(0), "Registry: Invalid address");
        if (_status) {
            require(kioskRegistered[_actor], "Registry: Kiosk must be linked to enode first");
        }
        if (_actor == owner) {
            require(_status, "Registry: Cannot revoke Owner privileges");
        }
        _canRecord[_actor] = _status;
        emit RoleChanged(_actor, "RECORD", _status);
    }
    function setRemoteRecordAuth(address _actor, bool _status) external onlyManager {
        require(permissionsAddress != address(0), "System not linked");
        require(!isBannedDevice[_actor], "Device permanently banned");
        require(_actor != address(0), "Registry: Invalid address");
        if (_actor == owner) {
            require(_status, "Registry: Cannot revoke Owner privileges");
        }
        _canRecord[_actor] = _status;
        isRemoteDevice[_actor] = _status;
        emit RoleChanged(_actor, "RECORD_REMOTE", _status);
    }
    function setRevokeAuth(address _actor, bool _status) external onlyManager {
        require(permissionsAddress != address(0), "System not linked");
        require(!isBannedDevice[_actor], "Device permanently banned");
        require(_actor != address(0), "Registry: Invalid address");
        if (_actor == owner) {
            require(_status, "Registry: Cannot revoke Owner privileges");
        }
        canRevoke[_actor] = _status;
        emit RoleChanged(_actor, "REVOKE", _status);
    }
    function setReissueAuth(address _actor, bool _status) external onlyManager {
        require(permissionsAddress != address(0), "System not linked");
        require(!isBannedDevice[_actor], "Device permanently banned");
        require(_actor != address(0), "Registry: Invalid address");
        if (_actor == owner) {
            require(_status, "Registry: Cannot revoke Owner privileges");
        }
        canReissue[_actor] = _status;
        emit RoleChanged(_actor, "REISSUE", _status);
    }
    function registerKioskEnode(address device, bytes32 enodeHash) external onlyManager {
        require(permissionsAddress != address(0), "System not linked");
        require(!isBannedDevice[device], "Device permanently banned");
        require(kioskEnodes[device] == bytes32(0), "Registry: Device already mapped");
        require(enodeToKiosk[enodeHash] == address(0), "Registry: Enode already mapped");
        require(IPermissions(permissionsAddress).isNodeAuthorized(enodeHash), "Enode not authorized in Consensus");
        kioskEnodes[device] = enodeHash;
        enodeToKiosk[enodeHash] = device;
        kioskRegistered[device] = true;
    }
    function revokeKioskEnode(address _kiosk) external onlyManager {
        require(_kiosk != address(0), "Registry: Invalid address");
        require(_kiosk != owner, "Registry: Cannot revoke owner kiosk");
        bytes32 eHash = kioskEnodes[_kiosk];
        require(eHash != bytes32(0), "Registry: Kiosk not mapped");
        delete enodeToKiosk[eHash];
        delete kioskEnodes[_kiosk];
        kioskRegistered[_kiosk] = false;
        _canEnroll[_kiosk] = false;
        _canRecord[_kiosk] = false;
        canRevoke[_kiosk] = false;
        canReissue[_kiosk] = false;
        isRemoteDevice[_kiosk] = false;
        emit KioskEnodeRevoked(_kiosk, eHash, msg.sender);
    }
    function banUser(address user) external onlyManager {
        require(user != address(0), "Registry: Invalid address");
        isBannedUser[user] = true;
        profiles[user].isValid = false;
        emit UserBanned(user, msg.sender);
    }
    function banDevice(address device) external onlyManager {
        require(device != address(0), "Registry: Invalid address");
        require(device != owner, "Registry: Cannot ban the contract owner");
        require(device != pendingOwner, "Registry: Cannot ban the pending owner");
        isBannedDevice[device] = true;
        _canEnroll[device] = false;
        _canRecord[device] = false;
        isManager[device] = false;
        canRevoke[device] = false;
        canReissue[device] = false;
        emit DeviceBanned(device, msg.sender);
    }
    function togglePause() external onlyOwner {
        systemPaused = !systemPaused;
        emit EmergencyStop(systemPaused);
    }
    function suspendDevice(address _device, uint256 _reason) external onlyManager {
        require(_device != address(0), "Registry: Invalid device");
        require(!deviceSuspended[_device], "Registry: Already suspended");
        deviceSuspended[_device] = true;
        emit DeviceSuspended(_device, _reason);
    }
    function reinstateDevice(address _device) external onlyManager {
        require(_device != address(0), "Registry: Invalid device");
        require(deviceSuspended[_device], "Registry: Not suspended");
        deviceSuspended[_device] = false;
        emit DeviceReinstated(_device);
    }
    function isDeviceSuspended(address _device) external view returns (bool) {
        return deviceSuspended[_device];
    }
    function suspendUser(address _user, uint256 _reason) external onlyManager {
        require(_user != address(0), "Registry: Invalid address");
        require(profiles[_user].isValid, "Registry: User not active");
        require(!userSuspended[_user], "Registry: Already suspended");
        userSuspended[_user] = true;
        emit UserSuspended(_user, msg.sender, _reason);
    }
    function reinstateUser(address _user) external onlyManager {
        require(_user != address(0), "Registry: Invalid address");
        require(userSuspended[_user], "Registry: Not suspended");
        userSuspended[_user] = false;
        emit UserReinstated(_user, msg.sender);
    }
    function isUserSuspended(address _user) external view returns (bool) {
        return userSuspended[_user];
    }
    function _recoverSigner(bytes32 _hash, bytes memory _sig) internal pure returns (address) {
        require(_sig.length == 65, "Registry: Invalid signature length");
        bytes32 r; bytes32 s; uint8 v;
        assembly {
            r := mload(add(_sig, 32))
            s := mload(add(_sig, 64))
            v := byte(0, mload(add(_sig, 96)))
        }
        if (v < 27) v += 27;
        require(v == 27 || v == 28, "Registry: Invalid signature v");
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "Registry: Invalid signature s");
        return ecrecover(_hash, v, r, s);
    }
}
