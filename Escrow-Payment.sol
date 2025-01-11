// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HalalEcommercePlatform {
    // Roles
    address public admin;
    mapping(address => bool) public approvedVendors;
    mapping(address => bool) public registeredCustomers;

    // Product Structure
    struct Product {
        uint256 productId;
        address vendor;
        string name;
        uint256 price; // in wei
        uint256 discount; // Discount percentage (e.g., 10 for 10%)
        bool isHalal;
        bool halalVerified;
        bool available;
        string category; // Product category
    }

    // Order Structure
    struct Order {
        uint256 orderId;
        address customer;
        address vendor;
        uint256 productId;
        uint256 amount;
        uint256 createdAt; // Order timestamp
        uint256 deliveryDeadline; // Delivery deadline
        bool fulfilled;
        bool disputed;
        bool refunded;
    }

    uint256 public commissionPercent; // Default admin commission percentage
    mapping(string => uint256) public categoryCommission; // Commission per category
    uint256 public productCount;
    uint256 public orderCount;
    mapping(uint256 => Product) public products;
    mapping(uint256 => Order) public orders;

    // Events
    event ProductAdded(uint256 indexed productId, address indexed vendor, string name, uint256 price, string category);
    event OrderPlaced(uint256 indexed orderId, address indexed customer, uint256 productId, uint256 amount);
    event OrderFulfilled(uint256 indexed orderId);
    event DisputeRaised(uint256 indexed orderId, address indexed customer);
    event DeliveryConfirmed(uint256 indexed orderId, address indexed customer);
    event MilestonePaid(uint256 indexed orderId, uint256 milestoneAmount);
    event RefundProcessed(uint256 indexed orderId, address indexed customer);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyVendor() {
        require(approvedVendors[msg.sender], "Only approved vendors can perform this action");
        _;
    }

    modifier onlyCustomer() {
        require(registeredCustomers[msg.sender], "Only registered customers can perform this action");
        _;
    }

    constructor(uint256 _commissionPercent) {
        require(_commissionPercent <= 100, "Commission cannot exceed 100%");
        admin = msg.sender;
        commissionPercent = _commissionPercent;
    }

    // -----------------
    // Product Management
    // -----------------

    function addProduct(
        string memory _name,
        uint256 _price,
        bool _isHalal,
        string memory _category,
        uint256 _discount
    ) external onlyVendor {
        require(_price > 0, "Price must be greater than zero");
        require(_discount <= 100, "Invalid discount percentage");

        products[productCount] = Product({
            productId: productCount,
            vendor: msg.sender,
            name: _name,
            price: _price,
            discount: _discount,
            isHalal: _isHalal,
            halalVerified: false,
            available: true,
            category: _category
        });

        emit ProductAdded(productCount, msg.sender, _name, _price, _category);
        productCount++;
    }

    function verifyProduct(uint256 _productId, bool _verified) external onlyAdmin {
        Product storage product = products[_productId];
        require(product.isHalal, "Product must be declared Halal by vendor");
        product.halalVerified = _verified;
    }

    // -----------------
    // Order Management
    // -----------------

    function placeOrder(uint256 _productId) external payable onlyCustomer {
        Product storage product = products[_productId];
        require(product.available, "Product is not available");
        uint256 discountedPrice = product.price - (product.price * product.discount) / 100;
        require(msg.value == discountedPrice, "Incorrect payment amount");

        uint256 deliveryDeadline = block.timestamp + 7 days; // Default delivery time is 7 days

        orders[orderCount] = Order({
            orderId: orderCount,
            customer: msg.sender,
            vendor: product.vendor,
            productId: _productId,
            amount: msg.value,
            createdAt: block.timestamp,
            deliveryDeadline: deliveryDeadline,
            fulfilled: false,
            disputed: false,
            refunded: false
        });

        emit OrderPlaced(orderCount, msg.sender, _productId, msg.value);
        orderCount++;
    }

    function confirmDelivery(uint256 _orderId) external onlyCustomer {
        Order storage order = orders[_orderId];
        require(order.customer == msg.sender, "You are not the customer");
        require(!order.fulfilled, "Order already fulfilled");
        require(block.timestamp <= order.deliveryDeadline, "Delivery deadline has passed");

        uint256 commission = (order.amount * commissionPercent) / 100;
        uint256 vendorPayment = order.amount - commission;

        payable(admin).transfer(commission);
        payable(order.vendor).transfer(vendorPayment);

        order.fulfilled = true;
        emit DeliveryConfirmed(_orderId, msg.sender);
    }

    function raiseDispute(uint256 _orderId) external onlyCustomer {
        Order storage order = orders[_orderId];
        require(order.customer == msg.sender, "You are not the customer");
        require(!order.fulfilled, "Order already fulfilled");

        order.disputed = true;
        emit DisputeRaised(_orderId, msg.sender);
    }

    function resolveDispute(uint256 _orderId, bool refundToCustomer) external onlyAdmin {
        Order storage order = orders[_orderId];
        require(order.disputed, "Order is not disputed");

        if (refundToCustomer) {
            payable(order.customer).transfer(order.amount);
            emit RefundProcessed(_orderId, order.customer);
        } else {
            uint256 commission = (order.amount * commissionPercent) / 100;
            uint256 vendorPayment = order.amount - commission;

            payable(admin).transfer(commission);
            payable(order.vendor).transfer(vendorPayment);
        }

        order.fulfilled = true;
    }

    // -----------------
    // Milestone Payments
    // -----------------

    function payMilestone(uint256 _orderId, uint256 _milestoneAmount) external onlyCustomer {
        Order storage order = orders[_orderId];
        require(order.customer == msg.sender, "You are not the customer");
        require(!order.fulfilled, "Order already fulfilled");
        require(order.amount >= _milestoneAmount, "Milestone exceeds order amount");

        uint256 commission = (_milestoneAmount * commissionPercent) / 100;
        uint256 vendorPayment = _milestoneAmount - commission;

        payable(admin).transfer(commission);
        payable(order.vendor).transfer(vendorPayment);

        order.amount -= _milestoneAmount;

        emit MilestonePaid(_orderId, _milestoneAmount);
    }
}
