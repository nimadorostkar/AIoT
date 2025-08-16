import React, { useState } from 'react'
import {
  Card,
  CardContent,
  Typography,
  Switch,
  Slider,
  Button,
  Box,
  Stack,
  IconButton,
  Chip,
  Alert,
  CircularProgress
} from '@mui/material'
import {
  Power,
  Lightbulb,
  Videocam,
  Thermostat,
  Air,
  Security,
  Settings
} from '@mui/icons-material'
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

type DeviceControlPanelProps = {
  device: Device
  onRefresh?: () => void
}

export default function DeviceControlPanel({ device, onRefresh }: DeviceControlPanelProps) {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [switchState, setSwitchState] = useState(false)
  const [dimmerValue, setDimmerValue] = useState(50)
  const [cameraRecording, setCameraRecording] = useState(false)

  const getDeviceIcon = () => {
    switch (device.type) {
      case 'relay':
      case 'switch':
        return <Power />
      case 'dimmer':
      case 'light':
        return <Lightbulb />
      case 'camera':
        return <Videocam />
      case 'thermostat':
        return <Thermostat />
      case 'fan':
        return <Air />
      default:
        return <Settings />
    }
  }

  const sendCommand = async (command: any) => {
    setLoading(true)
    setError('')
    
    try {
      await api.post(`/devices/devices/${device.id}/command/`, command)
      onRefresh?.()
    } catch (err: any) {
      setError(err.response?.data?.detail || 'خطا در ارسال دستور')
    } finally {
      setLoading(false)
    }
  }

  const handleSwitchToggle = async () => {
    const newState = !switchState
    setSwitchState(newState)
    await sendCommand({
      action: 'toggle',
      state: newState ? 'on' : 'off',
      timestamp: new Date().toISOString()
    })
  }

  const handleDimmerChange = async (value: number) => {
    setDimmerValue(value)
    await sendCommand({
      action: 'set_brightness',
      brightness: value,
      timestamp: new Date().toISOString()
    })
  }

  const handleCameraCommand = async (action: 'start_recording' | 'stop_recording' | 'take_snapshot') => {
    if (action === 'start_recording') {
      setCameraRecording(true)
    } else if (action === 'stop_recording') {
      setCameraRecording(false)
    }
    
    await sendCommand({
      action,
      timestamp: new Date().toISOString()
    })
  }

  const renderControlInterface = () => {
    switch (device.type) {
      case 'relay':
      case 'switch':
        return (
          <Stack direction="row" alignItems="center" spacing={2}>
            <Typography variant="body2">Status:</Typography>
            <Switch
              checked={switchState}
              onChange={handleSwitchToggle}
              disabled={loading || !device.is_online}
              color="primary"
            />
            <Chip 
              size="small"
              label={switchState ? 'On' : 'Off'}
              color={switchState ? 'success' : 'default'}
            />
          </Stack>
        )

      case 'dimmer':
      case 'light':
        return (
          <Stack spacing={2}>
            <Stack direction="row" alignItems="center" spacing={2}>
              <Typography variant="body2">On/Off:</Typography>
              <Switch
                checked={switchState}
                onChange={handleSwitchToggle}
                disabled={loading || !device.is_online}
              />
            </Stack>
            {switchState && (
              <Stack spacing={1}>
                <Typography variant="body2">Brightness: {dimmerValue}%</Typography>
                <Slider
                  value={dimmerValue}
                  onChange={(_, value) => setDimmerValue(value as number)}
                  onChangeCommitted={(_, value) => handleDimmerChange(value as number)}
                  disabled={loading || !device.is_online}
                  min={0}
                  max={100}
                  step={5}
                  marks={[
                    { value: 0, label: '0%' },
                    { value: 50, label: '50%' },
                    { value: 100, label: '100%' }
                  ]}
                />
              </Stack>
            )}
          </Stack>
        )

      case 'camera':
        return (
          <Stack spacing={2}>
            <Stack direction="row" spacing={1}>
              <Button
                variant={cameraRecording ? 'contained' : 'outlined'}
                color={cameraRecording ? 'error' : 'primary'}
                size="small"
                onClick={() => handleCameraCommand(cameraRecording ? 'stop_recording' : 'start_recording')}
                disabled={loading || !device.is_online}
                startIcon={<Videocam />}
              >
                {cameraRecording ? 'Stop Recording' : 'Start Recording'}
              </Button>
              
              <Button
                variant="outlined"
                size="small"
                onClick={() => handleCameraCommand('take_snapshot')}
                disabled={loading || !device.is_online}
              >
                Snapshot
              </Button>
            </Stack>
            
            {cameraRecording && (
              <Chip 
                size="small"
                color="error"
                label="Recording..."
                variant="filled"
              />
            )}
          </Stack>
        )

      case 'fan':
        return (
          <Stack spacing={2}>
            <Stack direction="row" alignItems="center" spacing={2}>
              <Typography variant="body2">On/Off:</Typography>
              <Switch
                checked={switchState}
                onChange={handleSwitchToggle}
                disabled={loading || !device.is_online}
              />
            </Stack>
            {switchState && (
              <Stack spacing={1}>
                <Typography variant="body2">Speed: {dimmerValue}%</Typography>
                <Slider
                  value={dimmerValue}
                  onChange={(_, value) => setDimmerValue(value as number)}
                  onChangeCommitted={(_, value) => handleDimmerChange(value as number)}
                  disabled={loading || !device.is_online}
                  min={0}
                  max={100}
                  step={10}
                />
              </Stack>
            )}
          </Stack>
        )

      default:
        return (
          <Typography variant="body2" color="text.secondary">
            Control not available for this device type
          </Typography>
        )
    }
  }

  return (
    <Card 
      variant="outlined" 
      sx={{ 
        width: '100%',
        opacity: device.is_online ? 1 : 0.6,
        transition: 'opacity 0.3s'
      }}
    >
      <CardContent>
        <Stack spacing={2}>
          {/* Header */}
          <Stack direction="row" alignItems="center" spacing={2}>
            <Box sx={{ color: device.is_online ? 'primary.main' : 'text.disabled' }}>
              {getDeviceIcon()}
            </Box>
            <Box sx={{ flexGrow: 1 }}>
              <Typography variant="subtitle2">
                {device.name || device.device_id}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {device.type} - {device.model}
              </Typography>
            </Box>
            <Chip 
              size="small"
              color={device.is_online ? 'success' : 'default'}
              label={device.is_online ? 'Online' : 'Offline'}
            />
          </Stack>

          {/* Error Display */}
          {error && (
            <Alert severity="error" size="small">
              {error}
            </Alert>
          )}

          {/* Control Interface */}
          <Box sx={{ position: 'relative' }}>
            {loading && (
              <Box 
                sx={{ 
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  backgroundColor: 'rgba(255, 255, 255, 0.8)',
                  zIndex: 1
                }}
              >
                <CircularProgress size={20} />
              </Box>
            )}
            
            {renderControlInterface()}
          </Box>
        </Stack>
      </CardContent>
    </Card>
  )
}
