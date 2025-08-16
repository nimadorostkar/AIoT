import React, { useState, useEffect } from 'react'
import {
  Box,
  Typography,
  Grid,
  Card,
  CardContent,
  Tabs,
  Tab,
  Stack,
  Button,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Chip,
  Alert
} from '@mui/material'
import { Refresh, VideoCall, Dashboard, Devices } from '@mui/icons-material'
import DeviceControlPanel from '../components/DeviceControlPanel'
import { api } from '../api/client'

type Gateway = { 
  id: number
  gateway_id: string
  name: string | null
  last_seen: string | null 
}

type Device = {
  id: number
  device_id: string
  type: string
  model: string
  name: string
  is_online: boolean
  gateway: { id: number; gateway_id: string; name: string }
}

export default function ControlPage() {
  const [selectedTab, setSelectedTab] = useState(0)
  const [gateways, setGateways] = useState<Gateway[]>([])
  const [devices, setDevices] = useState<Device[]>([])
  const [selectedGateway, setSelectedGateway] = useState<number | ''>('')
  const [controllableDevices, setControllableDevices] = useState<Device[]>([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    loadGateways()
    loadDevices()
  }, [])

  useEffect(() => {
    if (selectedGateway) {
      const gatewayDevices = devices.filter(d => d.gateway.id === selectedGateway)
      const controllable = gatewayDevices.filter(d => 
        ['relay', 'switch', 'dimmer', 'light', 'camera', 'fan', 'thermostat'].includes(d.type)
      )
      setControllableDevices(controllable)
    } else {
      const controllable = devices.filter(d => 
        ['relay', 'switch', 'dimmer', 'light', 'camera', 'fan', 'thermostat'].includes(d.type)
      )
      setControllableDevices(controllable)
    }
  }, [selectedGateway, devices])

  const loadGateways = async () => {
    try {
      const response = await api.get('/devices/gateways/')
      setGateways(response.data)
    } catch (error) {
      console.error('Error loading gateways:', error)
    }
  }

  const loadDevices = async () => {
    setLoading(true)
    try {
      const response = await api.get('/devices/devices/')
      setDevices(response.data)
    } catch (error) {
      console.error('Error loading devices:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleRefresh = () => {
    loadGateways()
    loadDevices()
  }

  const getDevicesByType = (type: string) => {
    return controllableDevices.filter(d => d.type === type)
  }

  const renderDeviceGrid = (devices: Device[], title: string) => {
    if (devices.length === 0) return null

    return (
      <Box sx={{ mb: 4 }}>
        <Typography variant="h6" sx={{ mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
          <Devices />
          {title} ({devices.length})
        </Typography>
        <Grid container spacing={2}>
          {devices.map(device => (
            <Grid item xs={12} sm={6} md={4} lg={3} key={device.id}>
              <DeviceControlPanel 
                device={device} 
                onRefresh={loadDevices}
              />
            </Grid>
          ))}
        </Grid>
      </Box>
    )
  }

  const TabPanel = ({ children, value, index }: any) => (
    <div hidden={value !== index}>
      {value === index && <Box sx={{ pt: 3 }}>{children}</Box>}
    </div>
  )

  return (
    <Stack spacing={3}>
      {/* Header */}
      <Stack direction="row" alignItems="center" justifyContent="space-between">
        <Typography variant="h4">Device Control</Typography>
        <Stack direction="row" spacing={2}>
          <FormControl size="small" sx={{ minWidth: 200 }}>
            <InputLabel>Select Gateway</InputLabel>
            <Select
              value={selectedGateway}
              onChange={(e) => setSelectedGateway(e.target.value as number)}
              label="Select Gateway"
            >
              <MenuItem value="">All Gateways</MenuItem>
              {gateways.map(gateway => (
                <MenuItem key={gateway.id} value={gateway.id}>
                  {gateway.name || gateway.gateway_id}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          
                      <Button 
            variant="outlined"
            startIcon={<Refresh />}
            onClick={handleRefresh}
            disabled={loading}
          >
            Refresh
          </Button>
        </Stack>
      </Stack>

      {/* Stats */}
      <Grid container spacing={2}>
        <Grid item xs={6} sm={3}>
          <Card>
            <CardContent sx={{ textAlign: 'center' }}>
              <Typography variant="h4" color="primary">
                {controllableDevices.length}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Total Controllable Devices
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={6} sm={3}>
          <Card>
            <CardContent sx={{ textAlign: 'center' }}>
              <Typography variant="h4" color="success.main">
                {controllableDevices.filter(d => d.is_online).length}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Online
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={6} sm={3}>
          <Card>
            <CardContent sx={{ textAlign: 'center' }}>
              <Typography variant="h4" color="error.main">
                {controllableDevices.filter(d => !d.is_online).length}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Offline
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={6} sm={3}>
          <Card>
            <CardContent sx={{ textAlign: 'center' }}>
              <Typography variant="h4" color="info.main">
                {getDevicesByType('camera').length}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Cameras
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Tabs */}
      <Card>
        <CardContent sx={{ p: 0 }}>
          <Tabs value={selectedTab} onChange={(_, value) => setSelectedTab(value)}>
            <Tab label="All Devices" />
            <Tab label="Lights & Relays" />
            <Tab label="Cameras" />
            <Tab label="Other Devices" />
          </Tabs>
        </CardContent>
      </Card>

      {/* Tab Panels */}
      <TabPanel value={selectedTab} index={0}>
        {controllableDevices.length === 0 ? (
          <Alert severity="info">
            No controllable devices found. Please add your gateways and devices first.
          </Alert>
        ) : (
          <Grid container spacing={2}>
            {controllableDevices.map(device => (
              <Grid item xs={12} sm={6} md={4} lg={3} key={device.id}>
                <DeviceControlPanel 
                  device={device} 
                  onRefresh={loadDevices}
                />
              </Grid>
            ))}
          </Grid>
        )}
      </TabPanel>

      <TabPanel value={selectedTab} index={1}>
        {renderDeviceGrid(
          [...getDevicesByType('relay'), ...getDevicesByType('switch'), ...getDevicesByType('dimmer'), ...getDevicesByType('light')],
          'Lights & Relays'
        )}
      </TabPanel>

      <TabPanel value={selectedTab} index={2}>
        {renderDeviceGrid(getDevicesByType('camera'), 'Cameras')}
      </TabPanel>

      <TabPanel value={selectedTab} index={3}>
        {renderDeviceGrid(
          [...getDevicesByType('fan'), ...getDevicesByType('thermostat')],
          'Other Devices'
        )}
      </TabPanel>
    </Stack>
  )
}
