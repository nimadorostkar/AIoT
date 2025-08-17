import { Button, Card, CardContent, Chip, Grid, Stack, TextField, Typography, Box, LinearProgress } from '@mui/material'
import { useNavigate } from 'react-router-dom'
import axios from 'axios'
import { api } from '../api/client'
import { useEffect, useState } from 'react'

type Device = {
  id: number
  device_id: string
  type: string
  model: string
  name: string
  is_online: boolean
  model_definition?: { model_id: string, name: string }
  model_schema?: any
}

type Telemetry = { id: number; device: number; timestamp: string; payload: any }

export default function DevicesPage() {
  const navigate = useNavigate()
  const [devices, setDevices] = useState<Device[]>([])
  const [gatewayId, setGatewayId] = useState('')
  const [deviceId, setDeviceId] = useState('')
  const [deviceName, setDeviceName] = useState('')
  const [deviceType, setDeviceType] = useState('sensor')
  const [deviceModel, setDeviceModel] = useState('')
  const [latestTelemetry, setLatestTelemetry] = useState<{ [deviceId: number]: Telemetry }>({})
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const apiBase = import.meta.env.VITE_API_BASE || 'http://localhost:8000'

  useEffect(() => {
    const access = localStorage.getItem('access')
    if (!access) {
      setError('Not authenticated')
      setLoading(false)
      return
    }
    
    const loadData = async () => {
      try {
        setLoading(true)
        setError(null)
        
        // Load devices
        const devicesResponse = await api.get(`/devices/devices/`)
        setDevices(devicesResponse.data || [])
        
        // Load latest telemetry for each device
        const telemetryResponse = await api.get(`/devices/telemetry/`)
        const telemetryByDevice: { [deviceId: number]: Telemetry } = {}
        
        if (telemetryResponse.data && Array.isArray(telemetryResponse.data)) {
          telemetryResponse.data.forEach((item: Telemetry) => {
            if (item && item.device && (!telemetryByDevice[item.device] || 
                new Date(item.timestamp) > new Date(telemetryByDevice[item.device].timestamp))) {
              telemetryByDevice[item.device] = item
            }
          })
        }
        
        setLatestTelemetry(telemetryByDevice)
      } catch (error) {
        console.error('Error loading devices:', error)
        setError('Failed to load devices. Please try refreshing the page.')
      } finally {
        setLoading(false)
      }
    }
    
    loadData()
  }, [])
  
  if (loading) {
    return (
      <Stack spacing={3} alignItems="center" sx={{ mt: 4 }}>
        <Typography variant="h5">Loading Devices...</Typography>
        <LinearProgress sx={{ width: '100%' }} />
      </Stack>
    )
  }
  
  if (error) {
    return (
      <Stack spacing={3} alignItems="center" sx={{ mt: 4 }}>
        <Typography variant="h5" color="error">Error</Typography>
        <Typography variant="body1">{error}</Typography>
        <Button variant="contained" onClick={() => window.location.reload()}>
          Refresh Page
        </Button>
      </Stack>
    )
  }

  return (
    <Stack spacing={3}>
      <Typography variant="h5">Devices</Typography>
      <Stack direction={{ xs: 'column', md: 'row' }} spacing={2}>
        <TextField label="Gateway ID" value={gatewayId} onChange={e => setGatewayId(e.target.value)} />
        <TextField label="Device ID" value={deviceId} onChange={e => setDeviceId(e.target.value)} />
        <TextField label="Name" value={deviceName} onChange={e => setDeviceName(e.target.value)} />
        <TextField label="Type" value={deviceType} onChange={e => setDeviceType(e.target.value)} />
        <TextField label="Model" value={deviceModel} onChange={e => setDeviceModel(e.target.value)} />
        <Button variant="contained" onClick={async () => {
          const access = localStorage.getItem('access')
          if (!access || !deviceId) return
          await api.post(`/devices/devices/`, {
            gateway_id: gatewayId,
            device_id: deviceId,
            name: deviceName,
            type: deviceType,
            model: deviceModel
          })
          const { data } = await api.get(`/devices/devices/`)
          setDevices(data)
          setDeviceId(''); setDeviceName(''); setDeviceModel('')
        }}>Add Device</Button>
      </Stack>
      <Grid container spacing={2}>
        {devices.map(d => {
          const telemetry = latestTelemetry[d.id]
          return (
            <Grid key={d.id} item xs={12} md={6} lg={4}>
              <Card>
                <CardContent>
                  <Stack spacing={2}>
                    <Box>
                      <Typography variant="subtitle1">{d.name || d.device_id}</Typography>
                      <Typography variant="body2" color="text.secondary">Type: {d.type} | Model: {d.model}</Typography>
                    </Box>
                    
                    <Stack direction="row" spacing={1} alignItems="center">
                      <Chip size="small" color={d.is_online ? 'success' : 'default'} label={d.is_online ? 'online' : 'offline'} />
                      {d.model_definition && <Chip size="small" label={d.model_definition.name} />}
                    </Stack>

                    {/* Real-time sensor data */}
                    {telemetry && telemetry.payload && (
                      <Box>
                        <Typography variant="body2" fontWeight="medium">Latest Readings:</Typography>
                        <Stack spacing={1} sx={{ mt: 1 }}>
                          {Object.entries(telemetry.payload || {}).map(([key, value]) => {
                            if (key === 'gateway_id' || key === 'timestamp') return null
                            
                            try {
                              return (
                                <Box key={key}>
                                  <Stack direction="row" justifyContent="space-between" alignItems="center">
                                    <Typography variant="body2" sx={{ textTransform: 'capitalize' }}>
                                      {key.replace('_', ' ')}:
                                    </Typography>
                                    <Typography variant="body2" fontWeight="medium">
                                      {typeof value === 'number' ? value.toFixed(1) : String(value)}
                                      {key === 'temperature' && '°C'}
                                      {key === 'humidity' && '%'}
                                      {key === 'battery' && '%'}
                                      {key === 'brightness' && '%'}
                                    </Typography>
                                  </Stack>
                                  {/* Progress bar for percentage values */}
                                  {(key === 'humidity' || key === 'battery' || key === 'brightness') && typeof value === 'number' && (
                                    <LinearProgress 
                                      variant="determinate" 
                                      value={Math.min(Math.max(value, 0), 100)} 
                                      sx={{ mt: 0.5, height: 4 }}
                                    />
                                  )}
                                </Box>
                              )
                            } catch (error) {
                              console.error('Error rendering telemetry data:', error, key, value)
                              return null
                            }
                          })}
                          <Typography variant="caption" color="text.secondary">
                            Updated: {telemetry.timestamp ? new Date(telemetry.timestamp).toLocaleString() : 'Unknown'}
                          </Typography>
                        </Stack>
                      </Box>
                    )}

                    {!telemetry && d.type === 'sensor' && (
                      <Typography variant="body2" color="text.secondary" sx={{ fontStyle: 'italic' }}>
                        No data received yet
                      </Typography>
                    )}

                    {d.model_schema && (
                      <Typography variant="body2" color="text.secondary">
                        Schema: {d.model_schema?.capabilities ? Object.keys(d.model_schema.capabilities).join(', ') : '—'}
                      </Typography>
                    )}

                    {/* Action Buttons */}
                    <Stack direction="row" spacing={1} sx={{ mt: 2 }}>
                      <Button 
                        size="small" 
                        variant="outlined"
                        onClick={() => navigate(`/sensor-history/${d.id}`)}
                      >
                        View History
                      </Button>
                      {d.type === 'sensor' && telemetry && (
                        <Button 
                          size="small" 
                          variant="text"
                          onClick={() => {
                            // Refresh this device's data
                            const access = localStorage.getItem('access')
                            if (access) {
                              api.get(`/devices/telemetry/?device=${d.id}&limit=1`)
                                .then(res => {
                                  if (res.data.length > 0) {
                                    setLatestTelemetry(prev => ({
                                      ...prev,
                                      [d.id]: res.data[0]
                                    }))
                                  }
                                })
                            }
                          }}
                        >
                          🔄 Refresh
                        </Button>
                      )}
                    </Stack>
                  </Stack>
                </CardContent>
              </Card>
            </Grid>
          )
        })}
      </Grid>
    </Stack>
  )
}


