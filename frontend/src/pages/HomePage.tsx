import { Box, Button, Stack, Typography } from '@mui/material'
import { useNavigate } from 'react-router-dom'

export default function HomePage() {
  const navigate = useNavigate()

  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <Box sx={{ flexGrow: 1, display: 'grid', placeItems: 'center' }}>
        <Stack spacing={2} alignItems="center">
          <Typography variant="h2">IoT Smart System</Typography>
          <Typography color="text.secondary">Real‑time sensing, control, and live video</Typography>
          <Stack direction="row" spacing={2}>
            <Button variant="contained" onClick={() => navigate('/login')}>Login</Button>
            <Button variant="outlined" onClick={() => navigate('/register')}>Register</Button>
          </Stack>
        </Stack>
      </Box>
      <Typography variant="caption" color="text.secondary" sx={{ textAlign: 'center', px: 4, pb: 4, fontSize: 12 }}>
        The Artificial Intelligence of Things (AIoT) is a powerful fusion of AI and IoT technologies, enabling devices to learn, adapt, and make decisions without human input. By integrating machine learning and analytics into IoT systems, AIoT enhances automation, operational efficiency, and real-time decision-making across industries.
      </Typography>
    </Box>
  )
}


