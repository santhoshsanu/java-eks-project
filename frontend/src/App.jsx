import React, { useState, useEffect, useCallback } from 'react'
import { productApi } from './api/productApi'
import ProductCard from './components/ProductCard'
import ProductModal from './components/ProductModal'
import SearchBar from './components/SearchBar'
import styles from './App.module.css'

const CATEGORIES = ['All', 'Electronics', 'Footwear', 'Clothing', 'Books', 'Kitchen', 'Home Appliances', 'Sports']

export default function App() {
  const [products, setProducts]       = useState([])
  const [loading, setLoading]         = useState(false)
  const [error, setError]             = useState(null)
  const [search, setSearch]           = useState('')
  const [category, setCategory]       = useState('All')
  const [modalOpen, setModalOpen]     = useState(false)
  const [editProduct, setEditProduct] = useState(null)
  const [toast, setToast]             = useState(null)

  const showToast = (message, type = 'success') => {
    setToast({ message, type })
    setTimeout(() => setToast(null), 3000)
  }

  const fetchProducts = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      let res
      if (search.trim())          res = await productApi.search(search)
      else if (category !== 'All') res = await productApi.getByCategory(category)
      else                         res = await productApi.getAll()
      setProducts(res.data)
    } catch (err) {
      setError('Failed to load products. Is the backend running?')
    } finally {
      setLoading(false)
    }
  }, [search, category])

  useEffect(() => { fetchProducts() }, [fetchProducts])

  const handleSave = async (formData) => {
    try {
      if (editProduct) {
        await productApi.update(editProduct.id, formData)
        showToast('Product updated successfully')
      } else {
        await productApi.create(formData)
        showToast('Product added successfully')
      }
      setModalOpen(false)
      setEditProduct(null)
      fetchProducts()
    } catch (err) {
      showToast('Failed to save product', 'error')
    }
  }

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this product?')) return
    try {
      await productApi.delete(id)
      showToast('Product deleted')
      fetchProducts()
    } catch {
      showToast('Failed to delete product', 'error')
    }
  }

  const handleEdit = (product) => {
    setEditProduct(product)
    setModalOpen(true)
  }

  const handleAdd = () => {
    setEditProduct(null)
    setModalOpen(true)
  }

  return (
    <div className={styles.app}>
      {/* ── Header ── */}
      <header className={styles.header}>
        <div className={styles.headerContent}>
          <div className={styles.logo}>
            <span className={styles.logoIcon}>🛍️</span>
            <h1>Product Catalog</h1>
            <span className={styles.versionBadge}>v2.0</span>
          </div>
          <button className={styles.addBtn} onClick={handleAdd}>
            + Add Product
          </button>
        </div>
      </header>

      {/* ── Filters ── */}
      <div className={styles.filterBar}>
        <SearchBar value={search} onChange={setSearch} />
        <div className={styles.categories}>
          {CATEGORIES.map(cat => (
            <button
              key={cat}
              className={`${styles.catBtn} ${category === cat ? styles.active : ''}`}
              onClick={() => { setCategory(cat); setSearch('') }}
            >
              {cat}
            </button>
          ))}
        </div>
      </div>

      {/* ── Content ── */}
      <main className={styles.main}>
        {loading && <div className={styles.loading}>Loading products...</div>}
        {error   && <div className={styles.error}>{error}</div>}
        {!loading && !error && products.length === 0 && (
          <div className={styles.empty}>No products found.</div>
        )}
        <div className={styles.grid}>
          {products.map(product => (
            <ProductCard
              key={product.id}
              product={product}
              onEdit={handleEdit}
              onDelete={handleDelete}
            />
          ))}
        </div>
      </main>

      {/* ── Modal ── */}
      {modalOpen && (
        <ProductModal
          product={editProduct}
          onSave={handleSave}
          onClose={() => { setModalOpen(false); setEditProduct(null) }}
        />
      )}

      {/* ── Toast ── */}
      {toast && (
        <div className={`${styles.toast} ${styles[toast.type]}`}>
          {toast.message}
        </div>
      )}
    </div>
  )
}
