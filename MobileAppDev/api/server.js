const express = require('express');
const sql = require('mssql');
const cors = require('cors');
const http = require('http');
const { Server } = require("socket.io");
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

// Configure Multer for file uploads
const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir);
}

const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, uploadDir);
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({ storage: storage }).array('attachments', 10); // Allow up to 10 files
app.use('/uploads', express.static(uploadDir));

app.use(cors());
app.use(express.json());

// Database Configuration
const config = {
    user: 'db_ac2b67_db1_admin',
    password: 'database1',
    server: 'SQL5110.site4now.net',
    database: 'db_ac2b67_db1',
    options: {
        encrypt: false,
        trustServerCertificate: true
    }
};

// Connect to Database
let defaultUserId = null;

sql.connect(config).then(async pool => {
    if (pool.connected) {
        console.log('Connected to SQL Server');

        // Fetch a default user ID for mobile actions (needed for Foreign Keys)
        try {
            const userResult = await pool.request().query("SELECT TOP 1 Id FROM AspNetUsers");
            if (userResult.recordset.length > 0) {
                defaultUserId = userResult.recordset[0].Id;
                console.log('Default User ID fetched:', defaultUserId);
            } else {
                console.warn('WARNING: No users found in AspNetUsers. Write operations might fail.');
            }
        } catch (e) {
            console.error('Error fetching default user:', e);
        }
    }
    return pool;
}).catch(err => {
    console.error('Database Connection Failed! Bad Config: ', err);
});

// Helper function to verify ASP.NET Identity Password Hash
function verifyPasswordHash(password, hashedPassword) {
    // ASP.NET Identity uses PBKDF2 with the format:
    // 0x01 (version) + salt (16 bytes) + hash (32 bytes)
    const buffer = Buffer.from(hashedPassword, 'base64');

    if (buffer[0] !== 0x01) {
        return false; // Unknown version
    }

    const salt = buffer.slice(1, 17);
    const storedHash = buffer.slice(17, 49);

    // Generate hash with same parameters as ASP.NET Identity
    const hash = crypto.pbkdf2Sync(password, salt, 10000, 32, 'sha256');

    return hash.equals(storedHash);
}

// POST: Login
app.post('/api/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ success: false, message: 'Username and password required' });
        }

        const pool = await sql.connect(config);

        // Get user from database
        const userResult = await pool.request()
            .input('UserName', sql.NVarChar, username)
            .query('SELECT Id, UserName, PasswordHash FROM AspNetUsers WHERE UserName = @UserName');

        if (userResult.recordset.length === 0) {
            return res.status(401).json({ success: false, message: 'Invalid credentials' });
        }

        const user = userResult.recordset[0];

        // Verify password
        if (!verifyPasswordHash(password, user.PasswordHash)) {
            return res.status(401).json({ success: false, message: 'Invalid credentials' });
        }

        // Get user roles
        const rolesResult = await pool.request()
            .input('UserId', sql.NVarChar, user.Id)
            .query(`
                SELECT r.Name 
                FROM AspNetUserRoles ur
                JOIN AspNetRoles r ON ur.RoleId = r.Id
                WHERE ur.UserId = @UserId
            `);

        const roles = rolesResult.recordset.map(r => r.Name);

        // Get user warehouses
        const warehousesResult = await pool.request()
            .input('UserId', sql.NVarChar, user.Id)
            .query(`
                SELECT w.Id, w.Name 
                FROM UserWarehouse uw
                JOIN Warehouse w ON uw.WarehouseId = w.Id
                WHERE uw.UserId = @UserId
            `);

        const warehouses = warehousesResult.recordset;

        res.json({
            success: true,
            user: {
                id: user.Id,
                username: user.UserName,
                roles: roles,
                warehouses: warehouses,
                isAdmin: roles.includes('Admin')
            }
        });

    } catch (err) {
        console.error('Login error:', err);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// GET Requests to fetch tickets (with role-based filtering)
app.get('/api/tickets', async (req, res) => {
    try {
        const { userId } = req.query;

        if (!userId) {
            return res.status(400).json({ error: 'userId required' });
        }

        const pool = await sql.connect(config);

        // Check if user is Admin
        const rolesResult = await pool.request()
            .input('UserId', sql.NVarChar, userId)
            .query(`
                SELECT r.Name 
                FROM AspNetUserRoles ur
                JOIN AspNetRoles r ON ur.RoleId = r.Id
                WHERE ur.UserId = @UserId
            `);

        const roles = rolesResult.recordset.map(r => r.Name);
        const isAdmin = roles.includes('Admin');

        let query = `
            SELECT t.*, w.Name as WarehouseName 
            FROM Ticket t
            LEFT JOIN Warehouse w ON t.WarehouseId = w.Id
        `;

        // If not admin, filter by user's warehouses
        if (!isAdmin) {
            query += `
                WHERE t.WarehouseId IN (
                    SELECT WarehouseId FROM UserWarehouse WHERE UserId = @UserId
                )
            `;
        }

        query += ' ORDER BY t.CreatedDate DESC';

        const request = pool.request();
        if (!isAdmin) {
            request.input('UserId', sql.NVarChar, userId);
        }

        const result = await request.query(query);
        res.json(result.recordset);

    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// GET Requests to fetch comments for a ticket
app.get('/api/tickets/:id/comments', async (req, res) => {
    try {
        const { id } = req.params;
        const pool = await sql.connect(config);
        const result = await pool.request()
            .input('TicketId', sql.Int, id)
            .query(`
                SELECT c.*, u.UserName as AuthorName 
                FROM Comment c
                LEFT JOIN AspNetUsers u ON c.AuthorId = u.Id
                WHERE TicketId = @TicketId 
                ORDER BY CreatedDate ASC
            `);
        res.json(result.recordset);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// GET: Fetch Warehouses (filtered by user access)
app.get('/api/warehouses', async (req, res) => {
    try {
        const { userId } = req.query;

        if (!userId) {
            return res.status(400).json({ error: 'userId required' });
        }

        const pool = await sql.connect(config);

        // Check if user is Admin
        const rolesResult = await pool.request()
            .input('UserId', sql.NVarChar, userId)
            .query(`
                SELECT r.Name 
                FROM AspNetUserRoles ur
                JOIN AspNetRoles r ON ur.RoleId = r.Id
                WHERE ur.UserId = @UserId
            `);

        const roles = rolesResult.recordset.map(r => r.Name);
        const isAdmin = roles.includes('Admin');

        let query = 'SELECT Id, Name FROM Warehouse';

        // If not admin, filter by user's warehouses
        if (!isAdmin) {
            query += ' WHERE Id IN (SELECT WarehouseId FROM UserWarehouse WHERE UserId = @UserId)';
        }

        const request = pool.request();
        if (!isAdmin) {
            request.input('UserId', sql.NVarChar, userId);
        }

        const result = await request.query(query);
        res.json(result.recordset);

    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// POST: Create a new Ticket (Modified for Multipart)
app.post('/api/tickets', upload, async (req, res) => {
    try {
        // Expected body keys are now strings in req.body
        const { ProblemType, Description, CustomerName, BillNumber, BillDate, WarehouseId, userId } = req.body;

        if (!userId) return res.status(400).json({ error: 'userId required' });

        const pool = await sql.connect(config);

        // Check if user has access to this warehouse
        const rolesResult = await pool.request()
            .input('UserId', sql.NVarChar, userId)
            .query(`
                SELECT r.Name 
                FROM AspNetUserRoles ur
                JOIN AspNetRoles r ON ur.RoleId = r.Id
                WHERE ur.UserId = @UserId
            `);

        const roles = rolesResult.recordset.map(r => r.Name);
        const isAdmin = roles.includes('Admin');

        // If not admin, validate warehouse access
        if (!isAdmin) {
            const accessCheck = await pool.request()
                .input('UserId', sql.NVarChar, userId)
                .input('WarehouseId', sql.Int, parseInt(WarehouseId))
                .query('SELECT 1 FROM UserWarehouse WHERE UserId = @UserId AND WarehouseId = @WarehouseId');

            if (accessCheck.recordset.length === 0) {
                return res.status(403).json({ error: 'You do not have access to this warehouse' });
            }
        }

        const transaction = new sql.Transaction(pool);

        await transaction.begin();

        try {
            const request = new sql.Request(transaction);

            // 1. Insert Ticket
            const result = await request
                .input('ProblemType', sql.NVarChar, ProblemType)
                .input('Description', sql.NVarChar, Description)
                .input('CustomerName', sql.NVarChar, CustomerName)
                .input('BillNumber', sql.NVarChar, BillNumber)
                .input('BillDate', sql.DateTime, BillDate ? new Date(BillDate) : new Date())
                .input('WarehouseId', sql.Int, parseInt(WarehouseId) || 1)
                .input('Status', sql.Int, 0)
                .input('CreatedDate', sql.DateTime, new Date())
                .input('CreatorId', sql.NVarChar, userId)
                .query(`
                    INSERT INTO Ticket (ProblemType, Description, CustomerName, BillNumber, BillDate, WarehouseId, Status, CreatedDate, CreatorId)
                    OUTPUT INSERTED.Id
                    VALUES (@ProblemType, @Description, @CustomerName, @BillNumber, @BillDate, @WarehouseId, @Status, @CreatedDate, @CreatorId)
                `);

            const newTicketId = result.recordset[0].Id;

            // 2. Insert Attachments if any
            if (req.files && req.files.length > 0) {
                for (const file of req.files) {
                    const attachRequest = new sql.Request(transaction);
                    await attachRequest
                        .input('FileName', sql.NVarChar, file.originalname)
                        .input('FilePath', sql.NVarChar, '/uploads/' + file.filename) // Assuming this relative path works for your system logic
                        .input('TicketId', sql.Int, newTicketId)
                        .input('UploadedDate', sql.DateTime, new Date())
                        .query(`
                            INSERT INTO TicketAttachment (FileName, FilePath, TicketId, UploadedDate)
                            VALUES (@FileName, @FilePath, @TicketId, @UploadedDate)
                        `);
                }
            }

            await transaction.commit();

            io.emit('ticket_created', { id: newTicketId, ProblemType, Description });
            res.json({ success: true, id: newTicketId, message: 'Ticket Created' });

        } catch (err) {
            await transaction.rollback();
            throw err;
        }

    } catch (err) {
        console.error('Error creating ticket:', err);
        res.status(500).send('Server Error');
    }
});

// PUT: Update Ticket Status
app.put('/api/tickets/:id/status', async (req, res) => {
    try {
        const { id } = req.params;
        const { status } = req.body; // Integer: 0=Open, 1=InProgress, 2=Resolved, 3=Closed

        const pool = await sql.connect(config);
        await pool.request()
            .input('Id', sql.Int, id)
            .input('Status', sql.Int, status)
            .query('UPDATE Ticket SET Status = @Status WHERE Id = @Id');

        res.json({ success: true });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// POST: Add Comment
app.post('/api/tickets/:id/comments', async (req, res) => {
    try {
        const { id } = req.params;
        const { content } = req.body;

        if (!defaultUserId) return res.status(500).json({ error: 'No default user available' });

        const pool = await sql.connect(config);
        await pool.request()
            .input('Content', sql.NVarChar, content)
            .input('TicketId', sql.Int, id)
            .input('AuthorId', sql.NVarChar, defaultUserId)
            .input('CreatedDate', sql.DateTime, new Date())
            .query(`
                INSERT INTO Comment (Content, TicketId, AuthorId, CreatedDate)
                VALUES (@Content, @TicketId, @AuthorId, @CreatedDate)
            `);

        // Emit event (optional, for real-time chat feel)
        io.emit('comment_added', { ticketId: id, content });

        res.json({ success: true });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// Simulate Endpoint to Trigger Ringtone
app.post('/api/simulate', async (req, res) => {
    // Determine if we are simulating a new ticket or a new comment
    const type = req.body.type || 'ticket'; // 'ticket' or 'comment'
    const data = req.body.data || { message: 'New Item Created' };

    console.log(`Simulating ${type} event`, data);

    if (type === 'ticket') {
        io.emit('ticket_created', data);
    } else if (type === 'comment') {
        io.emit('comment_added', data);
    }

    res.json({ success: true, message: `Event ${type} emitted` });
});

// Socket.IO Connection
io.on('connection', (socket) => {
    console.log('a user connected');
    socket.on('disconnect', () => {
        console.log('user disconnected');
    });
});

const PORT = 5000;
server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
