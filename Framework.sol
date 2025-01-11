// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PlatformAgreement {
    // Roles
    address public admin;
    mapping(address => bool) public vendors;
    mapping(address => bool) public customers;

    // Order and payment management
    struct Order {
        address customer;
        address vendor;
        uint256 amount;
        bool fulfilled;
        bool disputed;
    }

    uint256 public commissionPercent; // Platform's commission percentage (e.g., 2 for 2%)
    uint256 public orderCount; // Tracks the total number of orders
    mapping(uint256 => Order) public orders;

    // Events
    event VendorApproved(address indexed vendor);
    event VendorRemoved(address indexed vendor);
    event CustomerRegistered(address indexed customer);
    event OrderPlaced(uint256 indexed orderId, address indexed customer, address indexed vendor, uint256 amount);
    event OrderFulfilled(uint256 indexed orderId);
    event DisputeRaised(uint256 indexed orderId, address indexed raiser);
    event DisputeResolved(uint256 indexed orderId, bool refundedToCustomer);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyVendor() {
        require(vendors[msg.sender], "Only approved vendors can perform this action");
        _;
    }

    modifier onlyCustomer() {
        require(customers[msg.sender], "Only registered customers can perform this action");
        _;
    }

    constructor(uint256 _commissionPercent) {
        require(_commissionPercent <= 100, "Commission cannot exceed 100%");
        admin = msg.sender;
        commissionPercent = _commissionPercent;
    }

    // ------------------
    // Role Management
    // ------------------

    /// @notice Approve a vendor
    function approveVendor(address _vendor) external onlyAdmin {
        require(!vendors[_vendor], "Vendor is already approved");
        vendors[_vendor] = true;
        emit VendorApproved(_vendor);
    }

    /// @notice Remove a vendor
    function removeVendor(address _vendor) external onlyAdmin {
        require(vendors[_vendor], "Vendor is not approved");
        vendors[_vendor] = false;
        emit VendorRemoved(_vendor);
    }

    /// @notice Register a customer
    function registerCustomer(address _customer) external onlyAdmin {
        require(!customers[_customer], "Customer is already registered");
        customers[_customer] = true;
        emit CustomerRegistered(_customer);
    }

    // ------------------
    // Orders and Payments
    // ------------------

    /// @notice Place an order (customer pays the contract)
    function placeOrder(address _vendor) external payable onlyCustomer {
        require(vendors[_vendor], "Vendor is not approved");
        require(msg.value > 0, "Order amount must be greater than zero");

        orders[orderCount] = Order({
            customer: msg.sender,
            vendor: _vendor,
            amount: msg.value,
            fulfilled: false,
            disputed: false
        });

        emit OrderPlaced(orderCount, msg.sender, _vendor, msg.value);
        orderCount++;
    }

    /// @notice Mark an order as fulfilled (called by vendor)
    function fulfillOrder(uint256 _orderId) external onlyVendor {
        Order storage order = orders[_orderId];
        require(order.vendor == msg.sender, "You are not the vendor for this order");
        require(!order.fulfilled, "Order already fulfilled");
        require(!order.disputed, "Order is disputed");

        uint256 commission = (order.amount * commissionPercent) / 100;
        uint256 payment = order.amount - commission;

        // Transfer funds
        payable(admin).transfer(commission);
        payable(order.vendor).transfer(payment);

        order.fulfilled = true;
        emit OrderFulfilled(_orderId);
    }

    /// @notice Raise a dispute (called by customer)
    function raiseDispute(uint256 _orderId) external onlyCustomer {
        Order storage order = orders[_orderId];
        require(order.customer == msg.sender, "You are not the customer for this order");
        require(!order.fulfilled, "Order is already fulfilled");
        require(!order.disputed, "Order is already disputed");

        order.disputed = true;
        emit DisputeRaised(_orderId, msg.sender);
    }

    /// @notice Resolve a dispute (admin action)
    /// @param _orderId The order ID
    /// @param refundToCustomer If true, refund the customer. If false, pay the vendor.
    function resolveDispute(uint256 _orderId, bool refundToCustomer) external onlyAdmin {
        Order storage order = orders[_orderId];
        require(order.disputed, "Order is not disputed");
        require(!order.fulfilled, "Order is already fulfilled");

        if (refundToCustomer) {
            payable(order.customer).transfer(order.amount);
        } else {
            uint256 commission = (order.amount * commissionPercent) / 100;
            uint256 payment = order.amount - commission;

            // Transfer funds
            payable(admin).transfer(commission);
            payable(order.vendor).transfer(payment);
        }

        order.fulfilled = true; // Mark as resolved
        emit DisputeResolved(_orderId, refundToCustomer);
    }

    // ------------------
    // View Functions
    // ------------------

    /// @notice Get the details of an order
    function getOrder(uint256 _orderId) external view returns (Order memory) {
        return orders[_orderId];
    }

    /// @notice Check if an address is a vendor
    function isVendor(address _address) external view returns (bool) {
        return vendors[_address];
    }

    /// @notice Check if an address is a customer
    function isCustomer(address _address) external view returns (bool) {
        return customers[_address];
    }
}

