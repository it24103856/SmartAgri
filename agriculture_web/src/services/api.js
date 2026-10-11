// Central Axios HTTP client configuration with base URL and JWT authentication interceptor.
import axios from 'axios';

// Create an Axios instance with the environment-configured API base endpoint
const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'https://smartagri-api-5mkz.onrender.com/api',
});

// Request interceptor to automatically attach JWT authorization tokens from localStorage
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');

  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }

  return config;
});

export default api;
