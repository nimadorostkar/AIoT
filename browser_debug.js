// Frontend Debug Script - Copy and paste this into browser console (F12)

console.log('🚀 AIoT Frontend Debug Script Started');

// Check localStorage
const access = localStorage.getItem('access');
const refresh = localStorage.getItem('refresh');

console.log('📱 LocalStorage Check:');
console.log('- Access Token:', access ? '✅ Present' : '❌ Missing');
console.log('- Refresh Token:', refresh ? '✅ Present' : '❌ Missing');

if (access) {
    try {
        const payload = JSON.parse(atob(access.split('.')[1]));
        const exp = new Date(payload.exp * 1000);
        const now = new Date();
        console.log('- Token expires:', exp.toLocaleString());
        console.log('- Token valid:', exp > now ? '✅ Yes' : '❌ Expired');
    } catch (e) {
        console.log('- Token format: ❌ Invalid');
    }
}

// Test API endpoints
async function testAPI() {
    const API_BASE = 'http://localhost:8000';
    
    console.log('\n🔧 Testing API Endpoints:');
    
    // Test login
    try {
        const loginResponse = await fetch(`${API_BASE}/api/token/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username: 'admin', password: 'admin123' })
        });
        
        if (loginResponse.ok) {
            const tokens = await loginResponse.json();
            localStorage.setItem('access', tokens.access);
            localStorage.setItem('refresh', tokens.refresh);
            console.log('✅ Login successful - tokens saved');
        } else {
            console.log('❌ Login failed:', loginResponse.status);
        }
    } catch (error) {
        console.log('❌ Login error:', error.message);
    }
    
    // Test gateways
    try {
        const token = localStorage.getItem('access');
        const gatewaysResponse = await fetch(`${API_BASE}/api/devices/gateways/`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        
        if (gatewaysResponse.ok) {
            const gateways = await gatewaysResponse.json();
            console.log('✅ Gateways loaded:', gateways.count, 'total');
            console.log('📋 Gateway data:', gateways);
        } else {
            console.log('❌ Gateways failed:', gatewaysResponse.status);
        }
    } catch (error) {
        console.log('❌ Gateways error:', error.message);
    }
    
    // Test devices
    try {
        const token = localStorage.getItem('access');
        const devicesResponse = await fetch(`${API_BASE}/api/devices/devices/`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        
        if (devicesResponse.ok) {
            const devices = await devicesResponse.json();
            console.log('✅ Devices loaded:', devices.count, 'total');
            console.log('📋 Device data:', devices);
        } else {
            console.log('❌ Devices failed:', devicesResponse.status);
        }
    } catch (error) {
        console.log('❌ Devices error:', error.message);
    }
}

// Auto-run tests
testAPI().then(() => {
    console.log('\n🏁 Debug tests completed. Check above for results.');
    console.log('💡 Try refreshing the page (Ctrl+Shift+R) if data still not showing.');
});

// Helper function to force refresh page data
window.forceRefreshData = async () => {
    console.log('🔄 Force refreshing page data...');
    await testAPI();
    window.location.reload();
};

console.log('💡 Run forceRefreshData() to refresh page data');
