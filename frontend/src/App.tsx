import { CssBaseline, ThemeProvider, createTheme } from '@mui/material'
import { Navigate, Route, Routes } from 'react-router-dom'
import { useState, useEffect } from 'react'
import LoginPage from './pages/LoginPage'
import RegisterPage from './pages/RegisterPage'
import DashboardLayout from './components/DashboardLayout'
import OverviewPage from './pages/OverviewPage'
import DevicesPage from './pages/DevicesPage'
import SensorHistoryPage from './pages/SensorHistoryPage'
import ControlPage from './pages/ControlPage'
import VideoPage from './pages/VideoPage'
import HomePage from './pages/HomePage'

const theme = createTheme({
  palette: { mode: 'light' },
  shape: { borderRadius: 12 }
})

export default function App() {
  const [isAuthed, setIsAuthed] = useState(Boolean(localStorage.getItem('access')))

  useEffect(() => {
    const checkAuth = () => setIsAuthed(Boolean(localStorage.getItem('access')))
    
    // Listen for storage changes (when token is added/removed)
    window.addEventListener('storage', checkAuth)
    
    // Also check periodically in case storage changed in same tab
    const interval = setInterval(checkAuth, 1000)
    
    return () => {
      window.removeEventListener('storage', checkAuth)
      clearInterval(interval)
    }
  }, [])

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Routes>
        <Route path="/home" element={<HomePage />} />
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
        <Route
          path="/"
          element={isAuthed ? <DashboardLayout /> : <Navigate to="/login" replace />}
        >
          <Route index element={<OverviewPage />} />
          <Route path="devices" element={<DevicesPage />} />
          <Route path="control" element={<ControlPage />} />
          <Route path="video" element={<VideoPage />} />
          <Route path="sensor-history/:deviceId" element={<SensorHistoryPage />} />
        </Route>
      </Routes>
    </ThemeProvider>
  )
}


