import axios from 'axios'

// In production (EKS), VITE_API_URL is injected via K8s ConfigMap env var
// In local dev, Vite proxy handles /api → localhost:8080
const BASE_URL = import.meta.env.VITE_API_URL || ''

const api = axios.create({
  baseURL: `${BASE_URL}/api/products`,
  headers: { 'Content-Type': 'application/json' },
})

export const productApi = {
  getAll: ()                   => api.get('/'),
  getById: (id)                => api.get(`/${id}`),
  search: (keyword)            => api.get('/', { params: { search: keyword } }),
  getByCategory: (category)    => api.get('/', { params: { category } }),
  getInStock: ()               => api.get('/', { params: { inStock: true } }),
  create: (product)            => api.post('/', product),
  update: (id, product)        => api.put(`/${id}`, product),
  delete: (id)                 => api.delete(`/${id}`),
}
