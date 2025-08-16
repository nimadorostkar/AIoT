import React, { useRef, useEffect, useState } from 'react'
import {
  Card,
  CardContent,
  CardActions,
  Typography,
  Button,
  Box,
  Stack,
  IconButton,
  Chip,
  Alert,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  CircularProgress
} from '@mui/material'
import {
  PlayArrow,
  Stop,
  Fullscreen,
  VolumeUp,
  VolumeOff,
  Refresh,
  Download,
  Close
} from '@mui/icons-material'

type LiveVideoPlayerProps = {
  device: {
    id: number
    device_id: string
    name: string
    is_online: boolean
    gateway: { gateway_id: string }
  }
  streamUrl?: string
  autoPlay?: boolean
}

export default function LiveVideoPlayer({ device, streamUrl, autoPlay = false }: LiveVideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const [isPlaying, setIsPlaying] = useState(false)
  const [isMuted, setIsMuted] = useState(true)
  const [isFullscreen, setIsFullscreen] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [showFullscreenDialog, setShowFullscreenDialog] = useState(false)

  // Simulate WebRTC/RTSP stream URL
  const defaultStreamUrl = streamUrl || `rtsp://gateway-${device.gateway.gateway_id}/live/${device.device_id}`

  useEffect(() => {
    if (autoPlay && device.is_online) {
      handlePlay()
    }
  }, [autoPlay, device.is_online])

  const handlePlay = async () => {
    if (!videoRef.current) return
    
    setLoading(true)
    setError('')
    
    try {
      // In a real implementation, you would establish WebRTC connection
      // For demo purposes, we'll simulate with a placeholder
      videoRef.current.src = '/api/video-placeholder'
      await videoRef.current.play()
      setIsPlaying(true)
    } catch (err) {
      setError('خطا در اتصال به جریان ویدیو')
      console.error('Video play error:', err)
    } finally {
      setLoading(false)
    }
  }

  const handleStop = () => {
    if (!videoRef.current) return
    
    videoRef.current.pause()
    videoRef.current.src = ''
    setIsPlaying(false)
  }

  const handleMuteToggle = () => {
    if (!videoRef.current) return
    
    videoRef.current.muted = !videoRef.current.muted
    setIsMuted(videoRef.current.muted)
  }

  const handleFullscreen = () => {
    setShowFullscreenDialog(true)
  }

  const handleTakeSnapshot = () => {
    if (!videoRef.current) return
    
    // Create canvas and capture frame
    const canvas = document.createElement('canvas')
    const context = canvas.getContext('2d')
    if (!context) return
    
    canvas.width = videoRef.current.videoWidth
    canvas.height = videoRef.current.videoHeight
    context.drawImage(videoRef.current, 0, 0, canvas.width, canvas.height)
    
    // Download as image
    const link = document.createElement('a')
    link.download = `snapshot-${device.device_id}-${new Date().getTime()}.png`
    link.href = canvas.toDataURL()
    link.click()
  }

  const simulateWebRTCConnection = () => {
    // In a real implementation, this would:
    // 1. Connect to WebRTC signaling server
    // 2. Establish peer connection with camera
    // 3. Handle ICE candidates and SDP exchange
    // 4. Stream video through WebRTC
    
    setLoading(true)
    setTimeout(() => {
      setLoading(false)
      setIsPlaying(true)
      // Simulate video stream with a color-changing background
      if (videoRef.current) {
        videoRef.current.style.background = 'linear-gradient(45deg, #1976d2, #42a5f5)'
      }
    }, 2000)
  }

  return (
    <>
      <Card sx={{ width: '100%', maxWidth: 400 }}>
        <CardContent>
          <Stack spacing={2}>
            <Stack direction="row" alignItems="center" justifyContent="space-between">
              <Typography variant="h6" noWrap>
                {device.name}
              </Typography>
              <Chip 
                size="small"
                color={device.is_online ? 'success' : 'default'}
                label={device.is_online ? 'آنلاین' : 'آفلاین'}
              />
            </Stack>

            <Box
              sx={{
                position: 'relative',
                width: '100%',
                height: 200,
                backgroundColor: '#000',
                borderRadius: 1,
                overflow: 'hidden',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center'
              }}
            >
              {loading && (
                <Box sx={{ textAlign: 'center', color: 'white' }}>
                  <CircularProgress size={40} sx={{ color: 'white', mb: 1 }} />
                  <Typography variant="body2">Connecting...</Typography>
                </Box>
              )}

              {!loading && !isPlaying && (
                <Box sx={{ textAlign: 'center', color: 'white' }}>
                  <Typography variant="body2">
                    {device.is_online ? 'Ready to stream' : 'Camera offline'}
                  </Typography>
                </Box>
              )}

              <video
                ref={videoRef}
                style={{
                  width: '100%',
                  height: '100%',
                  objectFit: 'cover',
                  display: isPlaying ? 'block' : 'none'
                }}
                muted={isMuted}
                onError={() => setError('خطا در پخش ویدیو')}
              />

              {/* Video Controls Overlay */}
              {isPlaying && (
                <Box
                  sx={{
                    position: 'absolute',
                    bottom: 8,
                    right: 8,
                    display: 'flex',
                    gap: 1
                  }}
                >
                  <IconButton
                    size="small"
                    onClick={handleMuteToggle}
                    sx={{ backgroundColor: 'rgba(0,0,0,0.5)', color: 'white' }}
                  >
                    {isMuted ? <VolumeOff /> : <VolumeUp />}
                  </IconButton>
                  
                  <IconButton
                    size="small"
                    onClick={handleFullscreen}
                    sx={{ backgroundColor: 'rgba(0,0,0,0.5)', color: 'white' }}
                  >
                    <Fullscreen />
                  </IconButton>
                </Box>
              )}
            </Box>

            {error && (
              <Alert severity="error" size="small">
                {error}
              </Alert>
            )}
          </Stack>
        </CardContent>

        <CardActions>
          <Stack direction="row" spacing={1} sx={{ width: '100%' }}>
            {!isPlaying ? (
              <Button
                variant="contained"
                startIcon={<PlayArrow />}
                onClick={simulateWebRTCConnection}
                disabled={!device.is_online || loading}
                fullWidth
              >
                Start Stream
              </Button>
            ) : (
              <Button
                variant="outlined"
                startIcon={<Stop />}
                onClick={handleStop}
                fullWidth
              >
                Stop
              </Button>
            )}

            {isPlaying && (
              <Button
                variant="outlined"
                startIcon={<Download />}
                onClick={handleTakeSnapshot}
                size="small"
              >
                Snapshot
              </Button>
            )}

            <IconButton
              onClick={() => window.location.reload()}
              size="small"
              title="Refresh"
            >
              <Refresh />
            </IconButton>
          </Stack>
        </CardActions>
      </Card>

      {/* Fullscreen Dialog */}
      <Dialog
        open={showFullscreenDialog}
        onClose={() => setShowFullscreenDialog(false)}
        maxWidth={false}
        PaperProps={{
          sx: {
            width: '90vw',
            height: '90vh',
            backgroundColor: '#000'
          }
        }}
      >
        <DialogTitle sx={{ color: 'white', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Typography variant="h6">{device.name} - Fullscreen</Typography>
          <IconButton onClick={() => setShowFullscreenDialog(false)} sx={{ color: 'white' }}>
            <Close />
          </IconButton>
        </DialogTitle>
        
        <DialogContent sx={{ p: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <video
            style={{
              width: '100%',
              height: '100%',
              objectFit: 'contain'
            }}
            src={defaultStreamUrl}
            autoPlay
            muted={isMuted}
            controls
          />
        </DialogContent>
      </Dialog>
    </>
  )
}
