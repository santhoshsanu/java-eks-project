import React from 'react'
import styles from './ProductCard.module.css'

export default function ProductCard({ product, onEdit, onDelete }) {
  const { id, name, category, description, price, stock, imageUrl } = product

  return (
    <div className={styles.card}>
      <div className={styles.imageWrap}>
        <img
          src={imageUrl || `https://via.placeholder.com/300x200?text=${encodeURIComponent(name)}`}
          alt={name}
          className={styles.image}
          onError={e => { e.target.src = `https://via.placeholder.com/300x200?text=No+Image` }}
        />
        <span className={styles.category}>{category}</span>
      </div>

      <div className={styles.body}>
        <h3 className={styles.name} title={name}>{name}</h3>
        <p className={styles.description}>{description}</p>

        <div className={styles.footer}>
          <div className={styles.priceRow}>
            <span className={styles.price}>₹{price.toLocaleString('en-IN')}</span>
            <span className={stock > 0 ? styles.inStock : styles.outStock}>
              {stock > 0 ? `${stock} in stock` : 'Out of stock'}
            </span>
          </div>

          <div className={styles.actions}>
            <button
              className={styles.editBtn}
              onClick={() => onEdit(product)}
              aria-label={`Edit ${name}`}
            >
              ✏️ Edit
            </button>
            <button
              className={styles.deleteBtn}
              onClick={() => onDelete(id)}
              aria-label={`Delete ${name}`}
            >
              🗑️ Delete
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
