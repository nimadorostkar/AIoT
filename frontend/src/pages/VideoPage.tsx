import React, { useState, useEffect } from 'react'
import {
  Box,
  Typography,
  Grid,
  Card,
  CardContent,
  Stack,
  Button,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Alert,
  Chip
} from '@mui/material'
import { Refresh, Videocam, LiveTv } from '@mui/icons-material'
import LiveVideoPlayer from '../components/LiveVideoPlayer'
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

export default function VideoPage() {
  const [gateways, setGateways] = useState<Gateway[]>([])
  const [devices, setDevices] = useState<Device[]>([])
  const [selectedGateway, setSelectedGateway] = useState<number | ''>('')
  const [cameras, setCameras] = useState<Device[]>([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    loadGateways()
    loadDevices()
  }, [])

  useEffect(() => {
    if (!Array.isArray(devices)) {
      setCameras([])
      return
    }
    
    if (selectedGateway) {
      const gatewayDevices = devices.filter(d => d.gateway.id === selectedGateway)
      const cameraDevices = gatewayDevices.filter(d => d.type === 'camera')
      setCameras(cameraDevices)
    } else {
      const allCameras = devices.filter(d => d.type === 'camera')
      setCameras(allCameras)
    }
  }, [selectedGateway, devices])

  const loadGateways = async () => {
    try {
      const response = await api.get('/devices/gateways/')
      setGateways(response.data.results || [])
    } catch (error) {
      console.error('Error loading gateways:', error)
      setGateways([]) // Set empty array on error
    }
  }

  const loadDevices = async () => {
    setLoading(true)
    try {
      const response = await api.get('/devices/devices/')
      setDevices(response.data.results || [])
    } catch (error) {
      console.error('Error loading devices:', error)
      setDevices([]) // Ensure devices is always an array
    } finally {
      setLoading(false)
    }
  }

  const handleRefresh = () => {
    loadGateways()
    loadDevices()
  }

  const onlineCameras = cameras.filter(c => c.is_online)
  const offlineCameras = cameras.filter(c => !c.is_online)

  return (
    <Stack spacing={3}>
      {/* Header */}
      <Stack direction="row" alignItems="center" justifyContent="space-between">
        <Typography variant="h4" sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <LiveTv />
          Live Video Streaming
        </Typography>
        <Stack direction="row" spacing={2}>
          <FormControl size="small" sx={{ minWidth: 200 }}>
            <InputLabel>Select Gateway</InputLabel>
            <Select
              value={selectedGateway}
              onChange={(e) => setSelectedGateway(e.target.value as number)}
              label="Select Gateway"
            >
              <MenuItem value="">All Gateways</MenuItem>
              {Array.isArray(gateways) && gateways.map(gateway => (
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
                {cameras.length}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Total Cameras
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={6} sm={3}>
          <Card>
            <CardContent sx={{ textAlign: 'center' }}>
              <Typography variant="h4" color="success.main">
                {onlineCameras.length}
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
                {offlineCameras.length}
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
                {onlineCameras.length}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Streaming
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Camera Grid */}
      {cameras.length === 0 ? (
        <Alert severity="info" sx={{ textAlign: 'center' }}>
          <Stack spacing={2} alignItems="center">
            <Videocam sx={{ fontSize: 48, opacity: 0.5 }} />
            <Typography variant="h6">
              No cameras found
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Please add cameras to your gateways first
            </Typography>
          </Stack>
        </Alert>
      ) : (
        <>
          {/* Online Cameras */}
          {onlineCameras.length > 0 && (
            <Box>
              <Typography variant="h6" sx={{ mb: 2, color: 'success.main', display: 'flex', alignItems: 'center', gap: 1 }}>
                <Chip color="success" label={onlineCameras.length} size="small" />
                Online Cameras
              </Typography>
              <Grid container spacing={3}>
                {onlineCameras.map(camera => (
                  <Grid item xs={12} sm={6} md={4} lg={3} key={camera.id}>
                    <LiveVideoPlayer 
                      device={camera}
                      autoPlay={false}
                    />
                  </Grid>
                ))}
              </Grid>
            </Box>
          )}

          {/* Offline Cameras */}
          {offlineCameras.length > 0 && (
            <Box>
              <Typography variant="h6" sx={{ mb: 2, color: 'text.secondary', display: 'flex', alignItems: 'center', gap: 1 }}>
                <Chip color="default" label={offlineCameras.length} size="small" />
                Offline Cameras
              </Typography>
              <Grid container spacing={3}>
                {offlineCameras.map(camera => (
                  <Grid item xs={12} sm={6} md={4} lg={3} key={camera.id}>
                    <LiveVideoPlayer 
                      device={camera}
                      autoPlay={false}
                    />
                  </Grid>
                ))}
              </Grid>
            </Box>
          )}
        </>
      )}

      {/* WebRTC Information */}
      <Card variant="outlined">
        <CardContent>
          <Typography variant="h6" gutterBottom>
            🔧 Technical Information
          </Typography>
          <Typography variant="body2" color="text.secondary" paragraph>
            For complete live video streaming implementation, the following components are needed:
          </Typography>
          <Stack spacing={1}>
            <Typography variant="body2">
              • <strong>WebRTC Signaling Server:</strong> For establishing connection between client and camera
            </Typography>
            <Typography variant="body2">
              • <strong>STUN/TURN Servers:</strong> For NAT traversal and firewall bypass
            </Typography>
            <Typography variant="body2">
              • <strong>Media Server:</strong> Such as Kurento, Janus, or mediasoup
            </Typography>
            <Typography variant="body2">
              • <strong>RTSP to WebRTC Bridge:</strong> For converting IP camera streams
            </Typography>
          </Stack>
        </CardContent>
      </Card>
    </Stack>
  )
}
