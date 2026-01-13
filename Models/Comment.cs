using System;
using System.ComponentModel.DataAnnotations;

using Backend.Data;

namespace Backend.Models
{
    public class Comment
    {
        public int Id { get; set; }

        [Required]
        public string Content { get; set; }

        public DateTime CreatedDate { get; set; } = TimeHelper.GetBaghdadTime();

        public int TicketId { get; set; }
        public Ticket Ticket { get; set; }

        public string AuthorId { get; set; }
        public ApplicationUser Author { get; set; }

        public ICollection<TicketAttachment> Attachments { get; set; }
    }
}
