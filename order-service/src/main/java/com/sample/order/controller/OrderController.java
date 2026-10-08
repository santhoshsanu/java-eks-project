package com.sample.order.controller;

import com.sample.order.model.Order;
import com.sample.order.service.OrderService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/orders")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    // ── POST /api/orders ──────────────────────────────────────────────────────
    @PostMapping
    public ResponseEntity<Order> placeOrder(@Valid @RequestBody Order order) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(orderService.placeOrder(order));
    }

    // ── GET /api/orders ───────────────────────────────────────────────────────
    // Optional: ?userId=1  or  ?status=PLACED
    @GetMapping
    public ResponseEntity<List<Order>> getOrders(
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) String status) {

        if (userId != null) {
            return ResponseEntity.ok(orderService.getOrdersByUser(userId));
        }
        if (status != null && !status.isBlank()) {
            return ResponseEntity.ok(orderService.getOrdersByStatus(status));
        }
        return ResponseEntity.ok(orderService.getAllOrders());
    }

    // ── GET /api/orders/{id} ──────────────────────────────────────────────────
    @GetMapping("/{id}")
    public ResponseEntity<Order> getOrderById(@PathVariable Long id) {
        return ResponseEntity.ok(orderService.getOrderById(id));
    }

    // ── PATCH /api/orders/{id}/status ─────────────────────────────────────────
    @PatchMapping("/{id}/status")
    public ResponseEntity<Order> updateStatus(
            @PathVariable Long id,
            @RequestBody Map<String, String> body) {
        return ResponseEntity.ok(orderService.updateOrderStatus(id, body.get("status")));
    }

    // ── DELETE /api/orders/{id} ───────────────────────────────────────────────
    @DeleteMapping("/{id}")
    public ResponseEntity<Order> cancelOrder(@PathVariable Long id) {
        return ResponseEntity.ok(orderService.cancelOrder(id));
    }

    // ── GET /api/orders/health ────────────────────────────────────────────────
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
                "status", "UP",
                "service", "order-service"
        ));
    }
}
