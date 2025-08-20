/**
 * Main App Component for AIoT Smart System
 * 
 * This is the root component that sets up routing, theming, error boundaries,
 * and authentication state management for the entire application.
 */

import React, { useState, useEffect, useCallback, useMemo } from 'react'
import { 
  CssBaseline, 
  ThemeProvider, 
  createTheme, 
  Box, 
  CircularProgress,
  Typography,
  Backdrop
} from '@mui/material'
import { Navigate, Route, Routes, useLocation } from 'react-router-dom'

// Components
import ErrorBoundary from './components/ErrorBoundary'
import LoginPage from './pages/LoginPage'
import RegisterPage from './pages/RegisterPage'
import DashboardLayout from './components/DashboardLayout'
import OverviewPage from './pages/OverviewPage'
import DevicesPage from './pages/DevicesPage'
import SensorHistoryPage from './pages/SensorHistoryPage'
import ControlPage from './pages/ControlPage'
import VideoPage from './pages/VideoPage'
import HomePage from './pages/HomePage'

// API utilities
import { apiHelpers } from './api/client'

// Enhanced theme configuration
const theme = createTheme({
  palette: { 
    mode: 'light',
    primary: {
      main: '#1976d2',
      light: '#42a5f5',
      dark: '#1565c0',
    },
    secondary: {
      main: '#dc004e',
    },
    background: {
      default: '#f5f5f5',
      paper: '#ffffff',
    },
  },
  shape: { 
    borderRadius: 12 
  },
  typography: {
    h1: {
      fontWeight: 600,
    },
    h2: {
      fontWeight: 600,
    },
    h3: {
      fontWeight: 600,
    },
  },
  components: {
    MuiButton: {
      styleOverrides: {
        root: {
          textTransform: 'none',
          fontWeight: 500,
        },
      },
    },
    MuiCard: {
      styleOverrides: {
        root: {
          boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
        },
      },
    },
  },
})

// Loading component
const AppLoading: React.FC = () => (
  <Backdrop open={true} sx={{ color: '#fff', zIndex: (theme) => theme.zIndex.drawer + 1 }}>
    <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
      <CircularProgress color="inherit" />
      <Typography variant="h6">Loading AIoT System...</Typography>
    </Box>
  </Backdrop>
)

// Authentication context type
interface AuthState {
  isAuthenticated: boolean
  isLoading: boolean
  token: string | null
}

export default function App() {
  const location = useLocation()
  
  // Authentication state
  const [authState, setAuthState] = useState<AuthState>({
    isAuthenticated: false,
    isLoading: true,
    token: null
  })

  // Initialize authentication state
  useEffect(() => {
    const initializeAuth = () => {
      try {
        const token = apiHelpers.getToken()
        const isAuthenticated = apiHelpers.isAuthenticated()
        
        setAuthState({
          isAuthenticated,
          isLoading: false,
          token
        })
      } catch (error) {
        console.error('Error initializing auth state:', error)
        setAuthState({
          isAuthenticated: false,
          isLoading: false,
          token: null
        })
      }
    }

    initializeAuth()
  }, [])

  // Handle authentication changes
  const handleAuthChange = useCallback(() => {
    const token = apiHelpers.getToken()
    const isAuthenticated = apiHelpers.isAuthenticated()
    
    setAuthState(prev => ({
      ...prev,
      isAuthenticated,
      token
    }))
  }, [])

  // Listen for storage changes (cross-tab authentication)
  useEffect(() => {
    window.addEventListener('storage', handleAuthChange)
    
    // Also check periodically in case storage changed in same tab
    const interval = setInterval(handleAuthChange, 5000) // Check every 5 seconds
    
    return () => {
      window.removeEventListener('storage', handleAuthChange)
      clearInterval(interval)
    }
  }, [handleAuthChange])

  // Token validation effect
  useEffect(() => {
    if (authState.token && !authState.isLoading) {
      // Validate token by making a simple API call
      // This could be expanded to check token expiry
      try {
        // You could add a token validation API call here
        console.log('Token validated')
      } catch (error) {
        console.error('Token validation failed:', error)
        apiHelpers.clearAuth()
        handleAuthChange()
      }
    }
  }, [authState.token, authState.isLoading, handleAuthChange])

  // Error handler for the error boundary
  const handleError = useCallback((error: Error, errorInfo: React.ErrorInfo) => {
    // Log to console in development
    if (import.meta.env.DEV) {
      console.error('App Error Boundary:', error, errorInfo)
    }
    
    // In production, you might want to send this to an error tracking service
    // Example: sendErrorToService(error, errorInfo)
  }, [])

  // Memoized route guards
  const ProtectedRoute: React.FC<{ children: React.ReactNode }> = useMemo(() => 
    ({ children }) => {
      if (authState.isLoading) {
        return <AppLoading />
      }
      
      return authState.isAuthenticated ? 
        <>{children}</> : 
        <Navigate to="/login" replace state={{ from: location }} />
    }, [authState.isAuthenticated, authState.isLoading, location]
  )

  const PublicRoute: React.FC<{ children: React.ReactNode }> = useMemo(() =>
    ({ children }) => {
      if (authState.isLoading) {
        return <AppLoading />
      }
      
      return !authState.isAuthenticated ? 
        <>{children}</> : 
        <Navigate to="/" replace />
    }, [authState.isAuthenticated, authState.isLoading]
  )

  // Show loading screen during initialization
  if (authState.isLoading) {
    return (
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <AppLoading />
      </ThemeProvider>
    )
  }

  return (
    <ErrorBoundary onError={handleError}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <Routes>
          {/* Public routes */}
          <Route 
            path="/home" 
            element={<HomePage />} 
          />
          <Route 
            path="/login" 
            element={
              <PublicRoute>
                <LoginPage onLoginSuccess={handleAuthChange} />
              </PublicRoute>
            } 
          />
          <Route 
            path="/register" 
            element={
              <PublicRoute>
                <RegisterPage />
              </PublicRoute>
            } 
          />
          
          {/* Protected routes */}
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <DashboardLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<OverviewPage />} />
            <Route path="devices" element={<DevicesPage />} />
            <Route path="control" element={<ControlPage />} />
            <Route path="video" element={<VideoPage />} />
            <Route path="sensor-history/:deviceId" element={<SensorHistoryPage />} />
          </Route>
          
          {/* Catch-all route */}
          <Route 
            path="*" 
            element={
              authState.isAuthenticated ? 
                <Navigate to="/" replace /> : 
                <Navigate to="/login" replace />
            } 
          />
        </Routes>
      </ThemeProvider>
    </ErrorBoundary>
  )
}


