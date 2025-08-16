import { AppBar, Box, Button, Container, Drawer, List, ListItem, ListItemButton, ListItemText, ListItemIcon, Toolbar, Typography } from '@mui/material'
import { Dashboard, Devices, ControlCamera, Videocam } from '@mui/icons-material'
import { Link as RouterLink, Outlet, useNavigate, useLocation } from 'react-router-dom'

export default function DashboardLayout() {
  const navigate = useNavigate()
  const location = useLocation()
  
  const logout = () => {
    localStorage.removeItem('access')
    localStorage.removeItem('refresh')
    navigate('/login')
  }

  const menuItems = [
    { path: '/', label: 'Overview', icon: <Dashboard /> },
    { path: '/devices', label: 'Devices', icon: <Devices /> },
    { path: '/control', label: 'Control', icon: <ControlCamera /> },
    { path: '/video', label: 'Live Video', icon: <Videocam /> },
  ]
  return (
    <Box sx={{ display: 'flex', minHeight: '100vh', flexDirection: 'column' }}>
      <AppBar position="static" color="inherit" elevation={1}>
        <Toolbar>
          <Typography variant="h6" sx={{ flexGrow: 1 }}>IoT Smart System</Typography>
          <Button onClick={logout} variant="outlined">Logout</Button>
        </Toolbar>
      </AppBar>
      <Box sx={{ display: 'flex', flexGrow: 1 }}>
        <Drawer variant="permanent" sx={{ width: 240, [`& .MuiDrawer-paper`]: { width: 240, position: 'relative' } }}>
          <List sx={{ pt: 2 }}>
            {menuItems.map((item) => (
              <ListItem key={item.path} disablePadding>
                <ListItemButton 
                  component={RouterLink} 
                  to={item.path}
                  selected={location.pathname === item.path}
                  sx={{
                    '&.Mui-selected': {
                      backgroundColor: 'primary.light',
                      color: 'primary.contrastText',
                      '&:hover': {
                        backgroundColor: 'primary.main',
                      },
                    },
                  }}
                >
                  <ListItemIcon sx={{ color: 'inherit' }}>
                    {item.icon}
                  </ListItemIcon>
                  <ListItemText primary={item.label} />
                </ListItemButton>
              </ListItem>
            ))}
          </List>
        </Drawer>
        <Container sx={{ py: 3, flexGrow: 1 }}>
          <Outlet />
        </Container>
      </Box>
    </Box>
  )
}


