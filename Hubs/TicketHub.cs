using Microsoft.AspNetCore.SignalR;

namespace Backend.Hubs
{
    public class TicketHub : Hub
    {
        // Hub methods for clients to call (not strictly needed for just notifications)
        public async Task SendMessage(string user, string message)
        {
            await Clients.All.SendAsync("ReceiveMessage", user, message);
        }

        public async Task JoinWarehouseGroup(int warehouseId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"Warehouse_{warehouseId}");
        }

        public async Task LeaveWarehouseGroup(int warehouseId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"Warehouse_{warehouseId}");
        }
    }
}
