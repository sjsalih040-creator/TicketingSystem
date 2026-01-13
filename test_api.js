const http = require('http');

const BASE_URL = 'http://localhost:5038/api/mobile';

async function testEndpoint(name, path, method = 'GET', body = null) {
    return new Promise((resolve) => {
        const options = {
            hostname: 'localhost',
            port: 5038,
            path: `/api/mobile${path}`,
            method: method,
            headers: {
                'Content-Type': 'application/json'
            }
        };

        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                console.log(`[${name}] Status: ${res.statusCode}`);
                try {
                    const parsed = JSON.parse(data);
                    console.log(`[${name}] Response received successfully.`);
                    resolve(parsed);
                } catch (e) {
                    console.log(`[${name}] Response is not JSON.`);
                    resolve(data);
                }
            });
        });

        req.on('error', (e) => {
            console.error(`[${name}] ERROR: ${e.message}`);
            resolve(null);
        });

        if (body) {
            req.write(JSON.stringify(body));
        }
        req.end();
    });
}

async function runTests() {
    console.log('--- STARTING FINAL SYSTEM VERIFICATION ---');

    // 1. Test Login
    const loginData = await testEndpoint('Login Test', '/login', 'POST', {
        username: 'admin@example.com',
        password: 'Admin123!'
    });

    if (!loginData || !loginData.success) {
        console.log('Login failed. Please ensure the admin user exists with correct password.');
        return;
    }
    const userId = loginData.user.id;

    // 2. Test Fetch Tickets
    await testEndpoint('Fetch Tickets', `/tickets?userId=${userId}`);

    // 3. Test Fetch Warehouses
    await testEndpoint('Fetch Warehouses', `/warehouses?userId=${userId}`);

    // 4. Test Ticket Detail Data
    // Find a ticket ID from a fetch or use #1
    await testEndpoint('Fetch Comments', `/tickets/1/comments`);
    await testEndpoint('Fetch Attachments', `/tickets/1/attachments`);

    console.log('--- VERIFICATION COMPLETE ---');
}

runTests();
