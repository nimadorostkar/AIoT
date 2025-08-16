import { Box, Button, Card, CardContent, Stack, TextField, Typography } from '@mui/material'
import axios from 'axios'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

export default function RegisterPage() {
  const [username, setUsername] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const navigate = useNavigate()
  const apiBase = import.meta.env.VITE_API_BASE || 'http://localhost:8000'

  const handleRegister = async () => {
    try {
      await axios.post(`${apiBase}/api/accounts/register/`, { username, email, password })
      navigate('/login')
    } catch (e: any) {
      setError(e?.response?.data?.detail || 'Register failed')
    }
  }

  return (
    <Box sx={{ minHeight: '100vh', display: 'grid', placeItems: 'center' }}>
      <Card sx={{ width: 360 }}>
        <CardContent>
          <Stack spacing={2}>
            <Typography variant="h6">Register</Typography>
            <TextField label="Username" value={username} onChange={e => setUsername(e.target.value)} />
            <TextField label="Email" value={email} onChange={e => setEmail(e.target.value)} />
            <TextField label="Password" type="password" value={password} onChange={e => setPassword(e.target.value)} />
            {error && <Typography color="error">{error}</Typography>}
            <Button variant="contained" onClick={handleRegister}>Create account</Button>
          </Stack>
        </CardContent>
      </Card>
    </Box>
  )
}


