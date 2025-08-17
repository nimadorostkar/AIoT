import { Box, Card, CardContent, Grid, Stack, Typography, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Chip, LinearProgress, Button, IconButton } from '@mui/material'
import { ArrowBack } from '@mui/icons-material'
import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { api } from '../api/client'

type Device = {
  id: number
  device_id: string
  type: string
  model: string
  name: string
  is_online: boolean
  gateway: { id: number; gateway_id: string; name: string }
}

type Telemetry = { 
  id: number
  device: number
  timestamp: string
  payload: any 
}

export default function SensorHistoryPage() {
  const { deviceId } = useParams<{ deviceId: string }>()
  const navigate = useNavigate()
  const [device, setDevice] = useState<Device | null>(null)
  const [telemetryHistory, setTelemetryHistory] = useState<Telemetry[]>([])
  const [latestReading, setLatestReading] = useState<Telemetry | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const loadDeviceData = async () => {
      try {
        setLoading(true)
        setError(null)
        
        const access = localStorage.getItem('access')
        if (!access) {
          setError('Not authenticated')
          setLoading(false)
          return
        }
        
        if (!deviceId) {
          setError('No device ID provided')
          setLoading(false)
          return
        }

        console.log('Loading device data for ID:', deviceId)

        // Load device details
        const deviceResponse = await api.get(`/devices/devices/${deviceId}/`)
        console.log('Device response:', deviceResponse.data)
        setDevice(deviceResponse.data)

        // Load telemetry history (last 50 records)
        const telemetryResponse = await api.get(`/devices/telemetry/?device=${deviceId}&limit=50`)
        console.log('Telemetry response:', telemetryResponse.data)
        
        const telemetryData = Array.isArray(telemetryResponse.data) ? 
          telemetryResponse.data.sort((a: Telemetry, b: Telemetry) => 
            new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
          ) : []
        
        setTelemetryHistory(telemetryData)
        setLatestReading(telemetryData[0] || null)
      } catch (error: any) {
        console.error('Error loading device data:', error)
        setError(error.response?.data?.detail || error.message || 'Failed to load device data')
      } finally {
        setLoading(false)
      }
    }

    loadDeviceData()
  }, [deviceId])

  if (loading) {
    return (
      <Stack spacing={2} alignItems="center" sx={{ mt: 4 }}>
        <Typography variant="h6">Loading sensor data...</Typography>
        <LinearProgress sx={{ width: '50%' }} />
      </Stack>
    )
  }

  if (error) {
    return (
      <Stack spacing={2} alignItems="center" sx={{ mt: 4 }}>
        <Typography variant="h6" color="error">Error</Typography>
        <Typography>{error}</Typography>
        <Typography variant="body2">Device ID: {deviceId}</Typography>
      </Stack>
    )
  }

  if (!device) {
    return (
      <Stack spacing={2} alignItems="center" sx={{ mt: 4 }}>
        <Typography variant="h6">Device not found</Typography>
        <Typography>Device ID: {deviceId}</Typography>
      </Stack>
    )
  }

  const renderPayloadValue = (key: string, value: any) => {
    if (key === 'gateway_id') return null
    
    let displayValue = value
    let unit = ''
    
    // Add appropriate units and formatting
    if (key === 'temperature') {
      unit = '°C'
      displayValue = typeof value === 'number' ? value.toFixed(1) : value
    } else if (key === 'humidity') {
      unit = '%'
    } else if (key === 'light_level' || key === 'lux') {
      unit = key === 'lux' ? ' lux' : ''
    } else if (key === 'co2_ppm') {
      unit = ' ppm'
    } else if (key === 'storage_used_mb') {
      unit = ' MB'
    } else if (key === 'voc_ppb') {
      unit = ' ppb'
    } else if (typeof value === 'boolean') {
      displayValue = value ? 'Yes' : 'No'
    }
    
    return (
      <Box key={key} sx={{ mb: 1 }}>
        <Typography variant="body2" sx={{ textTransform: 'capitalize', fontWeight: 'medium' }}>
          {key.replace(/_/g, ' ')}: <strong>{displayValue}{unit}</strong>
        </Typography>
        {/* Progress bar for percentage values */}
        {key === 'humidity' && typeof value === 'number' && (
          <LinearProgress 
            variant="determinate" 
            value={value} 
            sx={{ mt: 0.5, height: 4, borderRadius: 2 }}
          />
        )}
        {key === 'air_quality_index' && typeof value === 'number' && (
          <LinearProgress 
            variant="determinate" 
            value={Math.min(value, 200) / 2} 
            sx={{ mt: 0.5, height: 4, borderRadius: 2 }}
            color={value < 100 ? 'success' : value < 150 ? 'warning' : 'error'}
          />
        )}
      </Box>
    )
  }

  return (
    <Stack spacing={3}>
      {/* Back Button and Device Header */}
      <Stack direction="row" spacing={2} alignItems="center">
        <IconButton 
          onClick={() => navigate('/devices')}
          sx={{ border: 1, borderColor: 'divider' }}
        >
          <ArrowBack />
        </IconButton>
        <Typography variant="h4">Device History</Typography>
      </Stack>
      
      {/* Device Header */}
      <Card>
        <CardContent>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} md={8}>
              <Typography variant="h5" gutterBottom>
                {device.name || device.device_id}
              </Typography>
              <Typography variant="body1" color="text.secondary">
                Type: {device.type} | Model: {device.model}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Gateway: {device.gateway?.name || device.gateway?.gateway_id || 'Unknown'} ({device.gateway?.gateway_id || 'N/A'})
              </Typography>
            </Grid>
            <Grid item xs={12} md={4} sx={{ textAlign: { md: 'right' } }}>
              <Chip 
                size="medium"
                color={device.is_online ? 'success' : 'default'} 
                label={device.is_online ? 'Online' : 'Offline'} 
              />
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Latest Reading */}
      {latestReading && (
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>Latest Reading</Typography>
            <Grid container spacing={2}>
              <Grid item xs={12} md={8}>
                <Stack spacing={1}>
                  {latestReading.payload ? Object.entries(latestReading.payload).map(([key, value]) => 
                    renderPayloadValue(key, value)
                  ).filter(Boolean) : <Typography variant="body2" color="text.secondary">No data available</Typography>}
                </Stack>
              </Grid>
              <Grid item xs={12} md={4}>
                <Typography variant="body2" color="text.secondary">
                  <strong>Last Updated:</strong><br />
                  {new Date(latestReading.timestamp).toLocaleString()}
                </Typography>
              </Grid>
            </Grid>
          </CardContent>
        </Card>
      )}

      {/* History Table */}
      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>Historical Data (Last 50 readings)</Typography>
          <TableContainer component={Paper} sx={{ maxHeight: 600 }}>
            <Table stickyHeader size="small">
              <TableHead>
                <TableRow>
                  <TableCell><strong>Timestamp</strong></TableCell>
                  {latestReading && latestReading.payload && Object.keys(latestReading.payload)
                    .filter(key => key !== 'gateway_id')
                    .map(key => (
                      <TableCell key={key}>
                        <strong>{key.replace(/_/g, ' ').toUpperCase()}</strong>
                      </TableCell>
                    ))
                  }
                </TableRow>
              </TableHead>
              <TableBody>
                {telemetryHistory.map((record) => (
                  <TableRow key={record.id} hover>
                    <TableCell>
                      <Typography variant="body2">
                        {new Date(record.timestamp).toLocaleString()}
                      </Typography>
                    </TableCell>
                    {record.payload ? Object.entries(record.payload)
                      .filter(([key]) => key !== 'gateway_id')
                      .map(([key, value]) => (
                        <TableCell key={key}>
                          {typeof value === 'boolean' 
                            ? (value ? '✅' : '❌')
                            : typeof value === 'number' 
                              ? value.toFixed(1)
                              : value || 'N/A'
                          }
                        </TableCell>
                      )) : <TableCell>No data</TableCell>
                    }
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
          
          {telemetryHistory.length === 0 && (
            <Box sx={{ textAlign: 'center', py: 4 }}>
              <Typography color="text.secondary">
                No historical data available for this sensor
              </Typography>
            </Box>
          )}
        </CardContent>
      </Card>
    </Stack>
  )
}
