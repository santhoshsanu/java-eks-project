package com.sample.app.service;

import com.sample.app.model.Product;
import com.sample.app.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ProductService {

    private final ProductRepository productRepository;

    // ── Get All ──────────────────────────────────────────────────────────────

    public List<Product> getAllProducts() {
        return productRepository.findAll();
    }

    // ── Get by ID ─────────────────────────────────────────────────────────────

    public Product getProductById(Long id) {
        return productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Product not found with id: " + id));
    }

    // ── Create ────────────────────────────────────────────────────────────────

    public Product createProduct(Product product) {
        return productRepository.save(product);
    }

    // ── Update ────────────────────────────────────────────────────────────────

    public Product updateProduct(Long id, Product updatedProduct) {
        Product existing = getProductById(id);
        existing.setName(updatedProduct.getName());
        existing.setCategory(updatedProduct.getCategory());
        existing.setDescription(updatedProduct.getDescription());
        existing.setPrice(updatedProduct.getPrice());
        existing.setStock(updatedProduct.getStock());
        existing.setImageUrl(updatedProduct.getImageUrl());
        return productRepository.save(existing);
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    public void deleteProduct(Long id) {
        if (!productRepository.existsById(id)) {
            throw new RuntimeException("Product not found with id: " + id);
        }
        productRepository.deleteById(id);
    }

    // ── Search ────────────────────────────────────────────────────────────────

    public List<Product> searchProducts(String keyword) {
        return productRepository.searchProducts(keyword);
    }

    // ── By Category ───────────────────────────────────────────────────────────

    public List<Product> getProductsByCategory(String category) {
        return productRepository.findByCategoryIgnoreCase(category);
    }

    // ── In Stock ──────────────────────────────────────────────────────────────

    public List<Product> getInStockProducts() {
        return productRepository.findByStockGreaterThan(0);
    }
}
