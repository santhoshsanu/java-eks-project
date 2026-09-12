import React, { useState, useEffect } from 'react'
import styles from './ProductModal.module.css'

const CATEGORIES = ['Electronics', 'Footwear', 'Clothing', 'Books', 'Kitchen', 'Home Appliances', 'Sports']

const EMPTY_FORM = {
  name: '', category: 'Electronics', description: '',
  price: '', stock: '', imageUrl: ''
}

export default function ProductModal({ product, onSave, onClose }) {
  const [form, setForm]     = useState(EMPTY_FORM)
  const [errors, setErrors] = useState({})

  // Pre-fill form when editing
  useEffect(() => {
    if (product) {
      setForm({
        name:        product.name        || '',
        category:    product.category    || 'Electronics',
        description: product.description || '',
        price:       product.price       || '',
        stock:       product.stock       || '',
        imageUrl:    product.imageUrl    || '',
      })
    }
  }, [product])

  const validate = () => {
    const e = {}
    if (!form.name.trim())        e.name        = 'Name is required'
    if (!form.category)           e.category    = 'Category is required'
    if (!form.description.trim()) e.description = 'Description is required'
    if (!form.price || isNaN(form.price) || Number(form.price) <= 0)
                                  e.price       = 'Enter a valid price > 0'
    if (form.stock === '' || isNaN(form.stock) || Number(form.stock) < 0)
                                  e.stock       = 'Stock must be 0 or more'
    setErrors(e)
    return Object.keys(e).length === 0
  }

  const handleChange = e => {
    const { name, value } = e.target
    setForm(prev => ({ ...prev, [name]: value }))
    setErrors(prev => ({ ...prev, [name]: undefined }))
  }

  const handleSubmit = e => {
    e.preventDefault()
    if (!validate()) return
    onSave({
      ...form,
      price: parseFloat(form.price),
      stock: parseInt(form.stock, 10),
    })
  }

  return (
    <div className={styles.overlay} onClick={e => e.target === e.currentTarget && onClose()}>
      <div className={styles.modal} role="dialog" aria-modal="true" aria-label={product ? 'Edit Product' : 'Add Product'}>
        <div className={styles.modalHeader}>
          <h2>{product ? '✏️ Edit Product' : '➕ Add Product'}</h2>
          <button className={styles.closeBtn} onClick={onClose} aria-label="Close modal">✕</button>
        </div>

        <form onSubmit={handleSubmit} className={styles.form} noValidate>
          {/* Name */}
          <div className={styles.field}>
            <label htmlFor="name">Product Name *</label>
            <input id="name" name="name" value={form.name} onChange={handleChange}
              placeholder="e.g. iPhone 15 Pro" />
            {errors.name && <span className={styles.err}>{errors.name}</span>}
          </div>

          {/* Category */}
          <div className={styles.field}>
            <label htmlFor="category">Category *</label>
            <select id="category" name="category" value={form.category} onChange={handleChange}>
              {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
            </select>
            {errors.category && <span className={styles.err}>{errors.category}</span>}
          </div>

          {/* Description */}
          <div className={styles.field}>
            <label htmlFor="description">Description *</label>
            <textarea id="description" name="description" value={form.description}
              onChange={handleChange} rows={3} placeholder="Brief product description..." />
            {errors.description && <span className={styles.err}>{errors.description}</span>}
          </div>

          {/* Price + Stock side by side */}
          <div className={styles.row}>
            <div className={styles.field}>
              <label htmlFor="price">Price (₹) *</label>
              <input id="price" name="price" type="number" min="0.01" step="0.01"
                value={form.price} onChange={handleChange} placeholder="e.g. 29999" />
              {errors.price && <span className={styles.err}>{errors.price}</span>}
            </div>
            <div className={styles.field}>
              <label htmlFor="stock">Stock *</label>
              <input id="stock" name="stock" type="number" min="0"
                value={form.stock} onChange={handleChange} placeholder="e.g. 50" />
              {errors.stock && <span className={styles.err}>{errors.stock}</span>}
            </div>
          </div>

          {/* Image URL */}
          <div className={styles.field}>
            <label htmlFor="imageUrl">Image URL (optional)</label>
            <input id="imageUrl" name="imageUrl" value={form.imageUrl}
              onChange={handleChange} placeholder="https://..." />
          </div>

          {/* Actions */}
          <div className={styles.btnRow}>
            <button type="button" className={styles.cancelBtn} onClick={onClose}>Cancel</button>
            <button type="submit" className={styles.saveBtn}>
              {product ? 'Update Product' : 'Add Product'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
