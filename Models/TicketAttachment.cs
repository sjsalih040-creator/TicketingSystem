using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

using Backend.Data;

namespace Backend.Models
{
    public class TicketAttachment
    {
        public int Id { get; set; }
        public string FilePath { get; set; }
        public string FileName { get; set; }
        public DateTime UploadedDate { get; set; } = TimeHelper.GetBaghdadTime();

        public int? TicketId { get; set; }
        public Ticket? Ticket { get; set; }

        public int? CommentId { get; set; }
        public Comment? Comment { get; set; }
    }
}
