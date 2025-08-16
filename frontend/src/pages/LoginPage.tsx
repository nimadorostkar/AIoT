import { Box, Button, Card, CardContent, Stack, TextField, Typography } from '@mui/material'
import axios from 'axios'
import { apiBase } from '../api/client'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

export default function LoginPage() {
  const [username, setUsername] = useState('admin')
  const [password, setPassword] = useState('admin123')
  const [error, setError] = useState('')
  const navigate = useNavigate()
  

  const handleLogin = async () => {
    try {
      const { data } = await axios.post(`${apiBase}/api/token/`, { username, password })
      localStorage.setItem('access', data.access)
      localStorage.setItem('refresh', data.refresh)
      navigate('/')
    } catch (e: any) {
      setError(e?.response?.data?.detail || 'Login failed')
    }
  }

  return (
    <Box sx={{ minHeight: '100vh', display: 'grid', placeItems: 'center' }}>
      <Card sx={{ width: 360 }}>
        <CardContent>
          <Stack spacing={2}>
            <Typography variant="h6">Login</Typography>
            <TextField label="Username" value={username} onChange={e => setUsername(e.target.value)} />
            <TextField label="Password" type="password" value={password} onChange={e => setPassword(e.target.value)} />
            {error && <Typography color="error">{error}</Typography>}
            <Button variant="contained" onClick={handleLogin}>Sign in</Button>
          </Stack>
        </CardContent>
      </Card>
    </Box>
  )
}


