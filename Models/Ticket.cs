using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

using Backend.Data;

namespace Backend.Models
{
    public class Ticket
    {
        public int Id { get; set; }

        [Required]
        [Display(Name = "نوع المشكلة")]
        public string ProblemType { get; set; }

        [Required]
        [Display(Name = "الوصف")]
        public string Description { get; set; }

        [Required]
        [Display(Name = "اسم العميل")]
        public string CustomerName { get; set; }

        [Required]
        [Display(Name = "رقم الفاتورة")]
        public string BillNumber { get; set; }

        [Required]
        [Display(Name = "تاريخ الفاتورة")]
        public DateTime BillDate { get; set; }

        [Required]
        [Display(Name = "المستودع")]
        public int WarehouseId { get; set; }
        public Warehouse? Warehouse { get; set; }

        [Display(Name = "الحالة")]
        public TicketStatus Status { get; set; }

        [Display(Name = "تاريخ الإنشاء")]
        public DateTime CreatedDate { get; set; } = TimeHelper.GetBaghdadTime();

        public string? CreatorId { get; set; }
        public ApplicationUser? Creator { get; set; }

        public string? AssignedToId { get; set; }
        public ApplicationUser? AssignedTo { get; set; }

        public ICollection<Comment>? Comments { get; set; }
        public ICollection<TicketAttachment>? Attachments { get; set; }
    }

    public enum TicketStatus
    {
        Open,
        InProgress,
        Resolved,
        Closed
    }
}
