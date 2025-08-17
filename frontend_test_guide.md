# IoT Frontend Testing Guide

## 🌐 Accessing the Frontend

### ✅ Correct URLs:
- **Main Frontend**: http://localhost:5173/
- **Alternative**: http://127.0.0.1:5173/
- **NOT this**: ~~http://0.0.0.0:5173/~~ (This won't work)

### 🔐 Login Process:

1. **Go to**: http://localhost:5173/
2. **You'll be redirected to**: http://localhost:5173/login
3. **Login with test accounts**:
   - **Alice**: `alice` / `testpass123`
   - **Bob**: `bob` / `testpass123`

### 📱 After Login - Available Pages:

1. **Overview**: http://localhost:5173/ (dashboard)
2. **Devices**: http://localhost:5173/devices ← This is what you want!
3. **Control**: http://localhost:5173/control
4. **Live Video**: http://localhost:5173/video

## 🧪 Step-by-Step Testing:

### Test Alice's Devices:
```
1. Open: http://localhost:5173/
2. Login: alice / testpass123
3. Click "Devices" in sidebar OR go to: http://localhost:5173/devices
4. You should see:
   - ALICE-TEMP-001: Alice Living Room Temp (🟢 Online)
   - ALICE-LOCK-001: Alice Front Door Lock (🟢 Online)  
   - ALICE-LIGHT-001: Alice Bedroom Light (🟢 Online)
```

### Test Bob's Devices:
```
1. Logout from Alice
2. Login: bob / testpass123  
3. Go to: http://localhost:5173/devices
4. You should see:
   - BOB-AIR-001: Bob Office Air Monitor (🟢 Online)
   - BOB-CAM-001: Bob Office Security Cam (🟢 Online)
   - BOB-AC-001: Bob Office AC Unit (🟢 Online)
```

## 🛠️ Troubleshooting:

### If devices page doesn't load:
1. **Check browser console** (F12 → Console tab)
2. **Check if logged in**: Look for token in localStorage
3. **Try refresh**: Ctrl+F5 or Cmd+R
4. **Clear cache**: Clear browser data for localhost:5173

### If login doesn't work:
1. **Check API is running**: http://localhost:8000/admin/
2. **Check credentials**: alice/testpass123 or bob/testpass123
3. **Check network tab** for API calls

### Browser Console Check:
```javascript
// Open browser console (F12) and run:
localStorage.getItem('access')  // Should show JWT token if logged in
```

## 🔧 Backend Status Check:

Run this to verify everything is working:
```bash
# Check all containers
docker ps

# Check API
curl http://localhost:8000/admin/

# Check if users exist
docker exec -it iot_api python manage.py shell -c "
from django.contrib.auth.models import User
print('Users:', [u.username for u in User.objects.all()])
"
```

## 📊 Current Simulation Status:

- ✅ **Alice's devices**: Temperature, Smart Lock, Smart Lights
- ✅ **Bob's devices**: Air Quality, Security Camera, Smart AC
- ✅ **MQTT Simulator**: Running and sending data
- ✅ **Database**: Has sample telemetry data
- ⚠️ **Real-time updates**: Limited due to MQTT bridge issue

## 🎯 What You Should See:

When you access http://localhost:5173/devices after logging in:

1. **Device Cards**: Each device shows as a card with:
   - Device name and type
   - Online/Offline status  
   - Latest sensor readings
   - Control buttons (for controllable devices)

2. **User Isolation**: 
   - Alice sees only her 3 devices
   - Bob sees only his 3 devices
   - No crossover between users

3. **Real-time Data**: 
   - Latest telemetry values
   - Device status updates
   - Online/offline indicators
