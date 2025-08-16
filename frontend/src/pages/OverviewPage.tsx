import { Button, Card, CardContent, Stack, TextField, Typography, Dialog, DialogTitle, DialogContent, DialogActions, List, ListItem, ListItemText, Chip } from '@mui/material'
import Grid from '@mui/material/Grid'
import { useEffect, useState } from 'react'
import axios from 'axios'
import { api } from '../api/client'

type Gateway = { id: number; gateway_id: string; name: string | null; last_seen: string | null }
type Device = { id: number; device_id: string; type: string; name: string; is_online: boolean; model: string }
type Telemetry = { id: number; device: number; timestamp: string; payload: any }

export default function OverviewPage() {
  const [gateways, setGateways] = useState<Gateway[]>([])
  const [gatewayId, setGatewayId] = useState('')
  const [gatewayName, setGatewayName] = useState('')
  const [lastEvent, setLastEvent] = useState<string>('')
  const [selectedGateway, setSelectedGateway] = useState<Gateway | null>(null)
  const [gatewayDevices, setGatewayDevices] = useState<Device[]>([])
  const [telemetryData, setTelemetryData] = useState<Telemetry[]>([])
  const apiBase = import.meta.env.VITE_API_BASE || 'http://localhost:8000'
  const wsBase = import.meta.env.VITE_WS_BASE || 'ws://localhost:8000'

  useEffect(() => {
    const access = localStorage.getItem('access')
    if (!access) return
    api.get(`/devices/gateways/`)
      .then(res => setGateways(res.data))
      .catch(err => {
        if (err.response?.status === 401) {
          localStorage.removeItem('access')
          window.location.href = '/login'
        }
      })
  }, [])

  useEffect(() => {
    const access = localStorage.getItem('access')
    if (!access) return
    const ws = new WebSocket(`${wsBase}/ws/telemetry/?token=${access}`)
    ws.onmessage = (ev) => {
      setLastEvent(ev.data)
    }
    return () => ws.close()
  }, [])

  // Load gateway devices and telemetry when gateway is selected
  useEffect(() => {
    if (!selectedGateway) return
    const access = localStorage.getItem('access')
    if (!access) return
    
    // Load devices for this gateway
    api.get(`/devices/devices/?gateway=${selectedGateway.id}`)
      .then(res => setGatewayDevices(res.data))
      .catch(() => setGatewayDevices([]))
    
    // Load recent telemetry
    api.get(`/devices/telemetry/?limit=10`)
      .then(res => setTelemetryData(res.data))
      .catch(() => setTelemetryData([]))
  }, [selectedGateway])

  return (
    <Stack spacing={3}>
      <Typography variant="h5">Gateways</Typography>
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
        <TextField label="Gateway ID" value={gatewayId} onChange={e => setGatewayId(e.target.value)} />
        <TextField label="Name" value={gatewayName} onChange={e => setGatewayName(e.target.value)} />
        <Button variant="contained" onClick={async () => {
          const access = localStorage.getItem('access')
          if (!access || !gatewayId) return
          await api.post(`/devices/gateways/claim/`, { gateway_id: gatewayId, name: gatewayName })
          const { data } = await api.get(`/devices/gateways/`)
          setGateways(data)
          setGatewayId(''); setGatewayName('')
        }}>Add Gateway</Button>
        <Button variant="outlined" onClick={async () => {
          const access = localStorage.getItem('access')
          if (!access) return
          // trigger discovery for all gateways
          await Promise.all(gateways.map(g => api.post(`/devices/gateways/${g.id}/discover/`)))
        }}>Discover Devices</Button>
      </Stack>
      <Typography variant="subtitle2" color="text.secondary">Last event: {lastEvent || '—'}</Typography>
      <Grid container spacing={2}>
        {gateways.map(g => (
          <Grid key={g.id} item xs={12} md={6} lg={4}>
            <Card sx={{ cursor: 'pointer' }} onClick={() => {
              // Navigate to gateway details (we'll implement this)
              console.log('Gateway clicked:', g.id)
            }}>
              <CardContent>
                <Stack spacing={1}>
                  <Typography variant="subtitle1">{g.name || g.gateway_id}</Typography>
                  <Typography variant="body2" color="text.secondary">ID: {g.gateway_id}</Typography>
                  <Typography variant="caption" color="text.secondary">
                    Last seen: {g.last_seen ? new Date(g.last_seen).toLocaleString() : 'Never'}
                  </Typography>
                  <Button 
                    size="small" 
                    variant="outlined" 
                    onClick={(e) => {
                      e.stopPropagation()
                      // Show gateway details modal
                      setSelectedGateway(g)
                    }}
                  >
                    View Details
                  </Button>
                </Stack>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      {/* Gateway Details Modal */}
      <Dialog open={!!selectedGateway} onClose={() => setSelectedGateway(null)} maxWidth="md" fullWidth>
        <DialogTitle>
          Gateway Details: {selectedGateway?.name || selectedGateway?.gateway_id}
        </DialogTitle>
        <DialogContent>
          <Stack spacing={3}>
            <Card>
              <CardContent>
                <Typography variant="h6">Gateway Information</Typography>
                <Typography>ID: {selectedGateway?.gateway_id}</Typography>
                <Typography>Name: {selectedGateway?.name || 'Unnamed'}</Typography>
                <Typography>Last Seen: {selectedGateway?.last_seen ? new Date(selectedGateway.last_seen).toLocaleString() : 'Never'}</Typography>
              </CardContent>
            </Card>

            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>Connected Devices ({gatewayDevices.length})</Typography>
                {gatewayDevices.length === 0 ? (
                  <Typography color="text.secondary">No devices found</Typography>
                ) : (
                  <List dense>
                    {gatewayDevices.map(device => (
                      <ListItem key={device.id}>
                        <ListItemText 
                          primary={device.name || device.device_id}
                          secondary={`Type: ${device.type} | Model: ${device.model}`}
                        />
                        <Chip 
                          size="small" 
                          color={device.is_online ? 'success' : 'default'} 
                          label={device.is_online ? 'online' : 'offline'} 
                        />
                      </ListItem>
                    ))}
                  </List>
                )}
              </CardContent>
            </Card>

            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>Recent Telemetry</Typography>
                {telemetryData.length === 0 ? (
                  <Typography color="text.secondary">No telemetry data</Typography>
                ) : (
                  <List dense>
                    {telemetryData.slice(0, 5).map(item => {
                      const device = gatewayDevices.find(d => d.id === item.device)
                      return (
                        <ListItem key={item.id}>
                          <ListItemText 
                            primary={`${device?.name || device?.device_id || 'Unknown Device'}`}
                            secondary={
                              <Stack>
                                <Typography variant="body2">
                                  {Object.entries(item.payload).map(([key, value]) => 
                                    key !== 'gateway_id' ? `${key}: ${value}` : null
                                  ).filter(Boolean).join(', ')}
                                </Typography>
                                <Typography variant="caption">
                                  {new Date(item.timestamp).toLocaleString()}
                                </Typography>
                              </Stack>
                            }
                          />
                        </ListItem>
                      )
                    })}
                  </List>
                )}
              </CardContent>
            </Card>
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setSelectedGateway(null)}>Close</Button>
        </DialogActions>
      </Dialog>
    </Stack>
  )
}


