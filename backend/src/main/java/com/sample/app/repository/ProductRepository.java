package com.sample.app.repository;

import com.sample.app.model.Product;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {

    // Find by category (case-insensitive)
    List<Product> findByCategoryIgnoreCase(String category);

    // Search by name containing keyword (case-insensitive)
    List<Product> findByNameContainingIgnoreCase(String keyword);

    // Search across name, category and description
    @Query("SELECT p FROM Product p WHERE " +
           "LOWER(p.name) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
           "LOWER(p.category) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
           "LOWER(p.description) LIKE LOWER(CONCAT('%', :keyword, '%'))")
    List<Product> searchProducts(@Param("keyword") String keyword);

    // Find products with stock > 0 (in-stock only)
    List<Product> findByStockGreaterThan(Integer stock);
}
