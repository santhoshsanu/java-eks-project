package com.sample.app.controller;

import com.sample.app.model.Product;
import com.sample.app.service.ProductService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/products")
@CrossOrigin(origins = "*")   // allows React frontend to call this API
@RequiredArgsConstructor
public class ProductController {

    private final ProductService productService;

    // ── GET /api/products ─────────────────────────────────────────────────────
    // Optional: ?search=keyword  or  ?category=Electronics  or  ?inStock=true

    @GetMapping
    public ResponseEntity<List<Product>> getProducts(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String category,
            @RequestParam(required = false) Boolean inStock) {

        if (search != null && !search.isBlank()) {
            return ResponseEntity.ok(productService.searchProducts(search));
        }
        if (category != null && !category.isBlank()) {
            return ResponseEntity.ok(productService.getProductsByCategory(category));
        }
        if (Boolean.TRUE.equals(inStock)) {
            return ResponseEntity.ok(productService.getInStockProducts());
        }
        return ResponseEntity.ok(productService.getAllProducts());
    }

    // ── GET /api/products/{id} ────────────────────────────────────────────────

    @GetMapping("/{id}")
    public ResponseEntity<Product> getProductById(@PathVariable Long id) {
        return ResponseEntity.ok(productService.getProductById(id));
    }

    // ── POST /api/products ────────────────────────────────────────────────────

    @PostMapping
    public ResponseEntity<Product> createProduct(@Valid @RequestBody Product product) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(productService.createProduct(product));
    }

    // ── PUT /api/products/{id} ────────────────────────────────────────────────

    @PutMapping("/{id}")
    public ResponseEntity<Product> updateProduct(
            @PathVariable Long id,
            @Valid @RequestBody Product product) {
        return ResponseEntity.ok(productService.updateProduct(id, product));
    }

    // ── DELETE /api/products/{id} ─────────────────────────────────────────────

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, String>> deleteProduct(@PathVariable Long id) {
        productService.deleteProduct(id);
        return ResponseEntity.ok(Map.of("message", "Product deleted successfully"));
    }

    // ── GET /api/products/health ──────────────────────────────────────────────
    // Used by K8s liveness/readiness probes

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
                "status", "UP",
                "service", "product-catalog-backend"
        ));
    }
}
