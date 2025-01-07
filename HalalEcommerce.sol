// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HalalEcommerce {
    struct Product {
        uint256 id;
        address payable seller;
        string name;
        string description;
        uint256 price;
        bool isHalalCertified;
        bool isAvailable;
    }

    struct Order {
        uint256 productId;
        address payable buyer;
        uint256 amountPaid;
        bool isCompleted;
    }

    uint256 public productCounter;
    uint256 public orderCounter;

    mapping(uint256 => Product) public products;
    mapping(uint256 => Order) public orders;

    event ProductAdded(uint256 productId, address seller, string name, uint256 price);
    event OrderPlaced(uint256 orderId, uint256 productId, address buyer, uint256 amountPaid);
    event OrderCompleted(uint256 orderId);

    modifier onlySeller(uint256 productId) {
        require(products[productId].seller == msg.sender, "Not the seller");
        _;
    }

    modifier onlyBuyer(uint256 orderId) {
        require(orders[orderId].buyer == msg.sender, "Not the buyer");
        _;
    }

    // Add a new product
    function addProduct(string memory _name, string memory _description, uint256 _price, bool _isHalalCertified) public {
        productCounter++;
        products[productCounter] = Product(
            productCounter,
            payable(msg.sender),
            _name,
            _description,
            _price,
            _isHalalCertified,
            true
        );
        emit ProductAdded(productCounter, msg.sender, _name, _price);
    }

    // Place an order
    function placeOrder(uint256 _productId) public payable {
        Product memory product = products[_productId];
        require(product.isAvailable, "Product not available");
        require(msg.value >= product.price, "Insufficient payment");

        // Lock payment in escrow
        orderCounter++;
        orders[orderCounter] = Order(_productId, payable(msg.sender), msg.value, false);

        emit OrderPlaced(orderCounter, _productId, msg.sender, msg.value);
    }

    // Complete the order
    function completeOrder(uint256 _orderId) public onlyBuyer(_orderId) {
        Order memory order = orders[_orderId];
        Product storage product = products[order.productId];

        require(!order.isCompleted, "Order already completed");

        // Transfer funds to the seller
        product.seller.transfer(order.amountPaid);
        orders[_orderId].isCompleted = true;

        // Mark product as sold out
        product.isAvailable = false;

        emit OrderCompleted(_orderId);
    }
}
