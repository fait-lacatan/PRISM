// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
import "./EnumerableSet.sol";
interface IRegistry {
    function isBannedDevice(address) external view returns (bool);
    function enodeToKiosk(bytes32) external view returns (address);
}
contract Permissions {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    address public admin;
    address public pendingAdmin;
    address public registryAddress;
    EnumerableSet.Bytes32Set private _authorizedNodes;
    mapping(bytes32 => bool) public isBannedNode;
    mapping(address => bool) public isManager;
    event NodeAdded(bytes32 indexed enodeHash, string enode);
    event NodeRemoved(bytes32 indexed enodeHash);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event NodeBanned(bytes32 indexed enodeHash, address indexed admin);
    modifier onlyAdmin() {
        require(msg.sender == admin, "Permissions: Not admin");
        _;
    }
    modifier onlyManager() {
        require(msg.sender == admin || isManager[msg.sender], "Permissions: Not manager");
        if (msg.sender != admin && registryAddress != address(0)) {
            require(!IRegistry(registryAddress).isBannedDevice(msg.sender), "Permissions: Manager is banned in Registry");
        }
        _;
    }
    constructor() {
        admin = msg.sender;
    }
    function addNode(string calldata enode) external onlyManager {
        require(registryAddress != address(0), "System not linked");
        bytes32 enodeHash = keccak256(bytes(enode));
        require(!isBannedNode[enodeHash], "Node permanently banned");
        require(!_authorizedNodes.contains(enodeHash), "Permissions: Node already authorized");
        _authorizedNodes.add(enodeHash);
        emit NodeAdded(enodeHash, enode);
    }
    function banNode(string calldata enode) external onlyManager {
        bytes32 enodeHash = keccak256(bytes(enode));
        _authorizedNodes.remove(enodeHash);
        isBannedNode[enodeHash] = true;
        emit NodeBanned(enodeHash, msg.sender);
    }
    function removeNode(string calldata enode) external onlyManager {
        bytes32 enodeHash = keccak256(bytes(enode));
        require(_authorizedNodes.contains(enodeHash), "Permissions: Node not authorized");
        _authorizedNodes.remove(enodeHash);
        emit NodeRemoved(enodeHash);
    }
    function isNodeAuthorized(string calldata enode) external view returns (bool) {
        return _authorizedNodes.contains(keccak256(bytes(enode)));
    }
    function isNodeAuthorized(bytes32 enodeHash) external view returns (bool) {
        return _authorizedNodes.contains(enodeHash);
    }
    function getNodeCount() external view returns (uint256) {
        return _authorizedNodes.length();
    }
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Permissions: Invalid address");
        pendingAdmin = newAdmin;
    }
    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Permissions: Not pending admin");
        emit AdminChanged(admin, pendingAdmin);
        admin = pendingAdmin;
        pendingAdmin = address(0);
    }
    function setRegistryAddress(address _registry) external onlyAdmin {
        require(_registry != address(0), "Permissions: Invalid address");
        registryAddress = _registry;
    }
    function setManager(address _manager, bool _status) external onlyAdmin {
        require(_manager != address(0), "Permissions: Invalid address");
        require(_manager != admin, "Permissions: Cannot modify Admin");
        isManager[_manager] = _status;
    }
    function connectionAllowed(
        string calldata sourceEnode,
        string calldata destEnode,
        bytes4,
        bytes4
    ) external view returns (bool) {
        bytes32 srcHash = keccak256(bytes(sourceEnode));
        bytes32 destHash = keccak256(bytes(destEnode));
        if (!_authorizedNodes.contains(srcHash) || isBannedNode[srcHash]) return false;
        if (!_authorizedNodes.contains(destHash) || isBannedNode[destHash]) return false;
        if (registryAddress != address(0)) {
            IRegistry reg = IRegistry(registryAddress);
            address srcKiosk = reg.enodeToKiosk(srcHash);
            if (srcKiosk != address(0) && reg.isBannedDevice(srcKiosk)) return false;
            address destKiosk = reg.enodeToKiosk(destHash);
            if (destKiosk != address(0) && reg.isBannedDevice(destKiosk)) return false;
        }
        return true;
    }
}
