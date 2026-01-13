const io = require('socket.io-client');
const http = require('http');

const socket = io('http://localhost:5000');

socket.on('connect', () => {
    console.log('Test Client Connected');

    // Trigger simulation after connection
    setTimeout(() => {
        console.log('Sending simulation request...');
        triggerSimulation();
    }, 1000);
});

socket.on('ticket_created', (data) => {
    console.log('SUCCESS: Event ticket_created RECEIVED', data);
    process.exit(0);
});

socket.on('disconnect', () => {
    console.log('Disconnected');
});

function triggerSimulation() {
    const data = JSON.stringify({
        type: 'ticket',
        data: { id: 999, ProblemType: 'Simulated Ticket' }
    });

    const options = {
        hostname: 'localhost',
        port: 5000,
        path: '/api/simulate',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': data.length
        }
    };

    const req = http.request(options, (res) => {
        console.log(`Simulation Request Status: ${res.statusCode}`);
        res.on('data', d => process.stdout.write(d));
    });

    req.on('error', (error) => {
        console.error('Error triggering simulation:', error);
    });

    req.write(data);
    req.end();
}
