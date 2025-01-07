import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import HalalEcommerceABI from './HalalEcommerceABI.json';

const contractAddress = "YOUR_CONTRACT_ADDRESS";

function App() {
  const [provider, setProvider] = useState(null);
  const [contract, setContract] = useState(null);
  const [products, setProducts] = useState([]);
  const [newProduct, setNewProduct] = useState({
    name: '',
    description: '',
    price: '',
    halalCertified: false,
  });

  useEffect(() => {
    const init = async () => {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner();
      const contract = new ethers.Contract(contractAddress, HalalEcommerceABI, signer);
      setProvider(provider);
      setContract(contract);
    };
    init();
  }, []);

  const fetchProducts = async () => {
    const productCount = await contract.productCounter();
    const productsArray = [];
    for (let i = 1; i <= productCount; i++) {
      const product = await contract.products(i);
      productsArray.push(product);
    }
    setProducts(productsArray);
  };

  const addProduct = async () => {
    const tx = await contract.addProduct(
      newProduct.name,
      newProduct.description,
      ethers.utils.parseEther(newProduct.price),
      newProduct.halalCertified
    );
    await tx.wait();
    fetchProducts();
  };

  return (
    <div>
      <h1>Halal Multivendor E-Commerce</h1>
      
      <div>
        <h2>Add Product</h2>
        <input
          type="text"
          placeholder="Name"
          value={newProduct.name}
          onChange={(e) => setNewProduct({ ...newProduct, name: e.target.value })}
        />
        <input
          type="text"
          placeholder="Description"
          value={newProduct.description}
          onChange={(e) => setNewProduct({ ...newProduct, description: e.target.value })}
        />
        <input
          type="text"
          placeholder="Price in ETH"
          value={newProduct.price}
          onChange={(e) => setNewProduct({ ...newProduct, price: e.target.value })}
        />
        <label>
          Halal Certified:
          <input
            type="checkbox"
            checked={newProduct.halalCertified}
            onChange={(e) => setNewProduct({ ...newProduct, halalCertified: e.target.checked })}
          />
        </label>
        <button onClick={addProduct}>Add Product</button>
      </div>

      <div>
        <h2>Product List</h2>
        <button onClick={fetchProducts}>Fetch Products</button>
        {products.map((product, index) => (
          <div key={index}>
            <h3>{product.name}</h3>
            <p>{product.description}</p>
            <p>Price: {ethers.utils.formatEther(product.price)} ETH</p>
            <p>Halal Certified: {product.isHalalCertified ? "Yes" : "No"}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

export default App;
