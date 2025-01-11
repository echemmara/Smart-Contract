// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract HalalPlatformRoles is AccessControl, ReentrancyGuard {
    // --- Role Definitions ---
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");           // Admin for platform management
    bytes32 public constant CERTIFIER_ROLE = keccak256("CERTIFIER_ROLE");   // Halal certifier for product approvals
    bytes32 public constant VENDOR_ROLE = keccak256("VENDOR_ROLE");         // Vendor to list and sell products
    bytes32 public constant BUYER_ROLE = keccak256("BUYER_ROLE");           // Buyer to purchase products

    // --- State Variables ---
    mapping(address => bool) public approvedCertifiers;  // To track verified halal certifiers

    // --- Events ---
    event VendorRegistered(address indexed vendor, string vendorName);
    event CertifierAdded(address indexed certifier);
    event CertifierRemoved(address indexed certifier);
    event BuyerAdded(address indexed buyer);
    event RoleRevoked(address indexed account, bytes32 role);

    // --- Constructor ---
    constructor(address admin) {
        // Setup initial admin role
        _setupRole(ADMIN_ROLE, admin);

        // Admins manage all other roles
        _setRoleAdmin(CERTIFIER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(VENDOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(BUYER_ROLE, ADMIN_ROLE);
    }

    // --- Admin Functions ---

    // Add a halal certifier
    function addCertifier(address certifier) external onlyRole(ADMIN_ROLE) {
        require(certifier != address(0), "Invalid certifier address");
        require(!approvedCertifiers[certifier], "Certifier already exists");
        approvedCertifiers[certifier] = true;
        _grantRole(CERTIFIER_ROLE, certifier);
        emit CertifierAdded(certifier);
    }

    // Remove a halal certifier
    function removeCertifier(address certifier) external onlyRole(ADMIN_ROLE) {
        require(approvedCertifiers[certifier], "Certifier does not exist");
        approvedCertifiers[certifier] = false;
        _revokeRole(CERTIFIER_ROLE, certifier);
        emit CertifierRemoved(certifier);
    }

    // Revoke any role
    function revokeRoleFromUser(address account, bytes32 role) external onlyRole(ADMIN_ROLE) {
        require(hasRole(role, account), "Account does not have the specified role");
        _revokeRole(role, account);
        emit RoleRevoked(account, role);
    }

    // --- Vendor Functions ---

    // Register as a vendor
    function registerVendor(string memory vendorName) external {
        require(!hasRole(VENDOR_ROLE, msg.sender), "Already registered as a vendor");
        _grantRole(VENDOR_ROLE, msg.sender);
        emit VendorRegistered(msg.sender, vendorName);
    }

    // --- Buyer Functions ---

    // Register as a buyer
    function registerBuyer() external {
        require(!hasRole(BUYER_ROLE, msg.sender), "Already registered as a buyer");
        _grantRole(BUYER_ROLE, msg.sender);
        emit BuyerAdded(msg.sender);
    }

    // --- Utility Functions ---

    // Check if an address is a certifier
    function isCertifier(address account) external view returns (bool) {
        return hasRole(CERTIFIER_ROLE, account);
    }

    // Check if an address is a vendor
    function isVendor(address account) external view returns (bool) {
        return hasRole(VENDOR_ROLE, account);
    }

    // Check if an address is a buyer
    function isBuyer(address account) external view returns (bool) {
        return hasRole(BUYER_ROLE, account);
    }

    // Modifier for certifier verification
    modifier onlyCertifier() {
        require(hasRole(CERTIFIER_ROLE, msg.sender), "Caller is not a certifier");
        _;
    }

    // Modifier for vendor verification
    modifier onlyVendor() {
        require(hasRole(VENDOR_ROLE, msg.sender), "Caller is not a vendor");
        _;
    }

    // --- Fallback Functions ---
    fallback() external payable {
        revert("Invalid operation");
    }

    receive() external payable {
        revert("ETH not accepted directly");
    }
}
