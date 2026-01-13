# Role-Based Access Control (RBAC) Implementation

## Overview
The mobile app now mirrors the web app's permission system, ensuring users only see and interact with data they have access to.

## Features Implemented

### 1. Login System
- **Authentication**: Users log in with their web app credentials
- **Password Security**: Uses ASP.NET Identity's PBKDF2 password hashing
- **Session Persistence**: Login session saved locally (auto-login on app restart)
- **User Data**: Stores userId, username, roles, and warehouse assignments

### 2. Role-Based Permissions

#### Admin Role
- **Tickets**: See ALL tickets from ALL warehouses
- **Warehouses**: Can create tickets for ANY warehouse
- **Full Access**: No restrictions

#### User/Editor Roles
- **Tickets**: Only see tickets from THEIR assigned warehouses
- **Warehouses**: Can only create tickets for warehouses they have access to
- **Restricted Access**: Filtered by UserWarehouse table

### 3. API Endpoints Updated

#### GET /api/tickets?userId={userId}
- Admins: Returns all tickets
- Others: Returns only tickets from user's warehouses
- Query joins UserWarehouse table for filtering

#### GET /api/warehouses?userId={userId}
- Admins: Returns all warehouses
- Others: Returns only user's assigned warehouses

#### POST /api/tickets
- Validates warehouse access before creating ticket
- Rejects creation if user doesn't have access to selected warehouse
- Uses logged-in userId as ticket creator (not default user)

#### POST /api/login
- Authenticates against AspNetUsers table
- Returns user info with roles and warehouse assignments
- Verifies password using same algorithm as web app

### 4. Flutter App Updates

#### Login Flow
1. Splash screen checks for saved session
2. Auto-login if valid session exists
3. Otherwise, shows login screen
4. After login, saves session to SharedPreferences

#### Home Screen
- Displays logged-in username in app bar
- Shows only tickets user has access to
- Logout option in menu

#### Create Ticket
- Warehouse dropdown shows only accessible warehouses
- Server validates access before creating ticket
- Ticket created with logged-in user as creator

## Security Features

✅ **Password Matching**: Uses same hash algorithm as ASP.NET Identity
✅ **Warehouse Validation**: Server-side validation prevents unauthorized access
✅ **Session Management**: Secure local storage of user session
✅ **Role Checking**: Server queries AspNetUserRoles for each request
✅ **Creator Tracking**: Tickets created with actual userId, not default

## Database Tables Used

- **AspNetUsers**: User authentication
- **AspNetRoles**: Role definitions (Admin, Editor, User)
- **AspNetUserRoles**: User-to-role mapping
- **UserWarehouse**: User-to-warehouse assignments
- **Warehouse**: Warehouse list
- **Ticket**: Ticket data with CreatorId

## Testing

### Test as Admin
1. Login with admin credentials
2. Should see ALL tickets
3. Can create tickets for ANY warehouse

### Test as Regular User
1. Login with user credentials
2. Should see ONLY tickets from your warehouses
3. Can only create tickets for assigned warehouses
4. Attempting to create for unauthorized warehouse = ERROR

## Next Steps (Optional)

- [ ] Add Edit Ticket functionality (with permission checks)
- [ ] Add Assign Ticket feature (admin/editor only)
- [ ] Add Comment permissions (match web app's 24-hour edit rule)
- [ ] Add attachment viewing/downloading
- [ ] Add real-time notifications for assigned warehouses only
