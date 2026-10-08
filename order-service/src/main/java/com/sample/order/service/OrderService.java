package com.sample.order.service;

import com.sample.order.model.Order;
import com.sample.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;

    // ── Place Order ───────────────────────────────────────────────────────────
    public Order placeOrder(Order order) {
        order.setStatus("PLACED");
        order.setCreatedAt(LocalDateTime.now().toString());
        return orderRepository.save(order);
    }

    // ── Get All Orders ────────────────────────────────────────────────────────
    public List<Order> getAllOrders() {
        return orderRepository.findAll();
    }

    // ── Get by ID ─────────────────────────────────────────────────────────────
    public Order getOrderById(Long id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Order not found with id: " + id));
    }

    // ── Get Orders by User ────────────────────────────────────────────────────
    public List<Order> getOrdersByUser(Long userId) {
        return orderRepository.findByUserId(userId);
    }

    // ── Get Orders by Status ──────────────────────────────────────────────────
    public List<Order> getOrdersByStatus(String status) {
        return orderRepository.findByStatus(status);
    }

    // ── Update Order Status ───────────────────────────────────────────────────
    public Order updateOrderStatus(Long id, String status) {
        Order order = getOrderById(id);
        order.setStatus(status);
        return orderRepository.save(order);
    }

    // ── Cancel Order ──────────────────────────────────────────────────────────
    public Order cancelOrder(Long id) {
        Order order = getOrderById(id);
        if (order.getStatus().equals("DELIVERED")) {
            throw new RuntimeException("Cannot cancel a delivered order");
        }
        order.setStatus("CANCELLED");
        return orderRepository.save(order);
    }
}
