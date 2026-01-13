using System;
using System.ComponentModel.DataAnnotations;

namespace Backend.Models
{
    public class TicketViewStatus
    {
        public int Id { get; set; }

        [Required]
        public string UserId { get; set; }
        public ApplicationUser? User { get; set; }

        [Required]
        public int TicketId { get; set; }
        public Ticket? Ticket { get; set; }

        public DateTime LastViewedDate { get; set; }
    }
}
