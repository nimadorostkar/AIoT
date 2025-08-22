/**
 * API Client for AIoT Smart System Frontend
 * 
 * This module provides a configured axios instance with authentication,
 * error handling, and type-safe API interactions for the IoT platform.
 */

import axios, { AxiosError, AxiosResponse, InternalAxiosRequestConfig } from 'axios'

// API Configuration
export const apiBase = import.meta.env.VITE_API_BASE || 'http://localhost:8000'

// Create axios instance with base configuration
export const api = axios.create({
  baseURL: `${apiBase}/api`,
  timeout: 30000, // 30 seconds timeout
  headers: {
    'Content-Type': 'application/json',
  },
})

// Types for API responses
export interface ApiError {
  message: string
  status: number
  code?: string
  details?: Record<string, any>
}

export interface ApiResponse<T = any> {
  data: T
  status: number
  message?: string
}

// Request interceptor for authentication
api.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = localStorage.getItem('access')
    if (token) {
      config.headers = config.headers || {}
      config.headers.Authorization = `Bearer ${token}`
    }
    
    // Log API requests in development
    if (import.meta.env.DEV) {
      console.log(`[API Request] ${config.method?.toUpperCase()} ${config.url}`)
    }
    
    return config
  },
  (error) => {
    console.error('[API Request Error]', error)
    return Promise.reject(error)
  }
)

// Response interceptor for error handling and token refresh
api.interceptors.response.use(
  (response: AxiosResponse) => {
    // Log API responses in development
    if (import.meta.env.DEV) {
      console.log(`[API Response] ${response.status} ${response.config.url}`)
    }
    
    return response
  },
  async (error: AxiosError) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean }
    
    // Handle different error scenarios
    if (error.response) {
      const status = error.response.status
      
      // Handle unauthorized errors
      if (status === 401 && !originalRequest._retry) {
        originalRequest._retry = true
        
        // Try to refresh token
        const refreshToken = localStorage.getItem('refresh')
        if (refreshToken) {
          try {
            const response = await axios.post(`${apiBase}/api/token/refresh/`, {
              refresh: refreshToken
            })
            
            const { access } = response.data
            localStorage.setItem('access', access)
            
            // Retry original request with new token
            if (originalRequest.headers) {
              originalRequest.headers.Authorization = `Bearer ${access}`
            }
            
            return api(originalRequest)
          } catch (refreshError) {
            // Refresh failed, redirect to login
            console.error('[Token Refresh Error]', refreshError)
            localStorage.removeItem('access')
            localStorage.removeItem('refresh')
            window.location.href = '/login'
            return Promise.reject(refreshError)
          }
        } else {
          // No refresh token, redirect to login
          localStorage.removeItem('access')
          window.location.href = '/login'
        }
      }
      
      // Handle forbidden errors
      if (status === 403) {
        console.error('[API Error] Forbidden access')
      }
      
      // Handle server errors
      if (status >= 500) {
        console.error('[API Error] Server error:', error.response.data)
      }
      
      // Create standardized error object
      const apiError: ApiError = {
        message: error.response.data?.error || error.response.data?.detail || 'An error occurred',
        status: status,
        code: error.response.data?.code,
        details: error.response.data
      }
      
      return Promise.reject(apiError)
    } else if (error.request) {
      // Network error
      const apiError: ApiError = {
        message: 'Network error - please check your internet connection',
        status: 0,
        code: 'NETWORK_ERROR'
      }
      
      console.error('[API Network Error]', error.request)
      return Promise.reject(apiError)
    } else {
      // Request setup error
      const apiError: ApiError = {
        message: error.message || 'Request configuration error',
        status: 0,
        code: 'REQUEST_ERROR'
      }
      
      console.error('[API Request Setup Error]', error.message)
      return Promise.reject(apiError)
    }
  }
)

// Helper functions for common API operations
export const apiHelpers = {
  /**
   * Handle API errors consistently across the application
   */
  handleError: (error: ApiError): string => {
    if (error.status === 0) {
      return 'Unable to connect to the server. Please check your internet connection.'
    }
    
    if (error.status >= 500) {
      return 'Server error. Please try again later.'
    }
    
    return error.message || 'An unexpected error occurred'
  },
  
  /**
   * Check if user is authenticated
   */
  isAuthenticated: (): boolean => {
    return !!localStorage.getItem('access')
  },
  
  /**
   * Get current user token
   */
  getToken: (): string | null => {
    return localStorage.getItem('access')
  },
  
  /**
   * Clear authentication tokens
   */
  clearAuth: (): void => {
    localStorage.removeItem('access')
    localStorage.removeItem('refresh')
  },
  
  /**
   * Set authentication tokens
   */
  setAuth: (accessToken: string, refreshToken?: string): void => {
    localStorage.setItem('access', accessToken)
    if (refreshToken) {
      localStorage.setItem('refresh', refreshToken)
    }
  }
}

export default api


