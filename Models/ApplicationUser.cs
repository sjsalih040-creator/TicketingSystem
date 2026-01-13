using Microsoft.AspNetCore.Identity;

namespace Backend.Models
{
    public class ApplicationUser : IdentityUser
    {
        public string FirstName { get; set; }
        public string LastName { get; set; }

        public ICollection<UserWarehouse> UserWarehouses { get; set; }
    }

    public class UserWarehouse
    {
        public string UserId { get; set; }
        public ApplicationUser User { get; set; }

        public int WarehouseId { get; set; }
        public Warehouse Warehouse { get; set; }
    }
}
