/**
 * Error Boundary Component for AIoT Smart System
 * 
 * This component catches JavaScript errors anywhere in the child component tree,
 * logs those errors, and displays a fallback UI instead of crashing the app.
 */

import React, { Component, ErrorInfo, ReactNode } from 'react'
import { Box, Typography, Button, Alert, AlertTitle } from '@mui/material'
import { Refresh as RefreshIcon, BugReport as BugIcon } from '@mui/icons-material'

interface Props {
  children: ReactNode
  fallback?: ReactNode
  onError?: (error: Error, errorInfo: ErrorInfo) => void
}

interface State {
  hasError: boolean
  error: Error | null
  errorInfo: ErrorInfo | null
}

class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props)
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null
    }
  }

  static getDerivedStateFromError(error: Error): State {
    // Update state so the next render will show the fallback UI
    return {
      hasError: true,
      error,
      errorInfo: null
    }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    // Log error details
    console.error('ErrorBoundary caught an error:', error, errorInfo)
    
    this.setState({
      error,
      errorInfo
    })

    // Call custom error handler if provided
    if (this.props.onError) {
      this.props.onError(error, errorInfo)
    }

    // In production, you might want to log this to an error reporting service
    if (import.meta.env.PROD) {
      // Example: logErrorToService(error, errorInfo)
    }
  }

  handleReload = () => {
    // Reset error state and reload the page
    this.setState({
      hasError: false,
      error: null,
      errorInfo: null
    })
    
    // Optionally reload the entire page
    window.location.reload()
  }

  handleReset = () => {
    // Just reset the error state without reloading
    this.setState({
      hasError: false,
      error: null,
      errorInfo: null
    })
  }

  render() {
    if (this.state.hasError) {
      // Custom fallback UI
      if (this.props.fallback) {
        return this.props.fallback
      }

      // Default error UI
      return (
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            minHeight: '100vh',
            padding: 3,
            backgroundColor: '#f5f5f5'
          }}
        >
          <Alert 
            severity="error" 
            sx={{ 
              maxWidth: 600, 
              width: '100%',
              mb: 3
            }}
          >
            <AlertTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <BugIcon />
              Something went wrong
            </AlertTitle>
            <Typography variant="body2" sx={{ mt: 1 }}>
              An unexpected error occurred in the application. This has been logged and will be investigated.
            </Typography>
          </Alert>

          <Box sx={{ textAlign: 'center', mb: 3 }}>
            <Typography variant="h6" gutterBottom>
              Error Details
            </Typography>
            <Typography 
              variant="body2" 
              sx={{ 
                fontFamily: 'monospace',
                backgroundColor: '#fff',
                padding: 2,
                borderRadius: 1,
                border: '1px solid #ddd',
                maxWidth: 600,
                wordBreak: 'break-word'
              }}
            >
              {this.state.error?.message || 'Unknown error'}
            </Typography>
          </Box>

          <Box sx={{ display: 'flex', gap: 2 }}>
            <Button
              variant="contained"
              startIcon={<RefreshIcon />}
              onClick={this.handleReload}
              color="primary"
            >
              Reload Page
            </Button>
            <Button
              variant="outlined"
              onClick={this.handleReset}
              color="secondary"
            >
              Try Again
            </Button>
          </Box>

          {import.meta.env.DEV && this.state.errorInfo && (
            <Box sx={{ mt: 4, maxWidth: 800, width: '100%' }}>
              <Typography variant="h6" gutterBottom>
                Error Stack (Development Only)
              </Typography>
              <Box
                sx={{
                  fontFamily: 'monospace',
                  fontSize: '0.75rem',
                  backgroundColor: '#fff',
                  padding: 2,
                  borderRadius: 1,
                  border: '1px solid #ddd',
                  overflow: 'auto',
                  maxHeight: 300,
                  whiteSpace: 'pre-wrap'
                }}
              >
                {this.state.errorInfo.componentStack}
              </Box>
            </Box>
          )}
        </Box>
      )
    }

    return this.props.children
  }
}

export default ErrorBoundary
