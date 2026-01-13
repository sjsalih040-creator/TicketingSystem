using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using Backend.Data;
using Backend.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;

using ClosedXML.Excel;
using Microsoft.AspNetCore.SignalR;
using Backend.Hubs;

namespace Backend.Controllers
{
    [Authorize]
    public class TicketsController : Controller
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IHubContext<TicketHub> _hubContext;

        public TicketsController(ApplicationDbContext context, UserManager<ApplicationUser> userManager, IHubContext<TicketHub> hubContext)
        {
            _context = context;
            _userManager = userManager;
            _hubContext = hubContext;
        }

        public async Task<IActionResult> ExportToExcel()
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null) return Challenge();

            IQueryable<Ticket> tickets = _context.Tickets
                .Include(t => t.Creator)
                .Include(t => t.AssignedTo)
                .Include(t => t.Warehouse);

            if (!await _userManager.IsInRoleAsync(user, "Admin"))
            {
                var userWarehouseIds = await _context.UserWarehouses
                    .Where(uw => uw.UserId == user.Id)
                    .Select(uw => uw.WarehouseId)
                    .ToListAsync();

                tickets = tickets.Where(t => userWarehouseIds.Contains(t.WarehouseId));
            }

            var ticketList = await tickets.ToListAsync();

            using (var workbook = new XLWorkbook())
            {
                var worksheet = workbook.Worksheets.Add("Tickets");
                worksheet.RightToLeft = true;

                // Header Title
                var titleRange = worksheet.Range("A1:H2");
                titleRange.Merge();
                titleRange.Value = "مشاكل المخازن";
                titleRange.Style.Fill.BackgroundColor = XLColor.Yellow;
                titleRange.Style.Font.FontSize = 20;
                titleRange.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
                titleRange.Style.Alignment.Vertical = XLAlignmentVerticalValues.Center;

                // Columns
                var headerRow = 3;
                worksheet.Cell(headerRow, 1).Value = "#";
                worksheet.Cell(headerRow, 2).Value = "نوع المشكلة";
                worksheet.Cell(headerRow, 3).Value = "اسم الزبون";
                worksheet.Cell(headerRow, 4).Value = "رقم القائمة";
                worksheet.Cell(headerRow, 5).Value = "تاريخ القائمة";
                worksheet.Cell(headerRow, 6).Value = "حالة التكت";
                worksheet.Cell(headerRow, 7).Value = "التفاصيل";
                worksheet.Cell(headerRow, 8).Value = "اسم المخزن";

                var headerRange = worksheet.Range(headerRow, 1, headerRow, 8);
                headerRange.Style.Font.Bold = true;
                headerRange.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;

                var currentRow = 4;
                int sequence = 1;
                foreach (var ticket in ticketList)
                {
                    worksheet.Cell(currentRow, 1).Value = sequence++;
                    worksheet.Cell(currentRow, 2).Value = ticket.ProblemType;
                    worksheet.Cell(currentRow, 3).Value = ticket.CustomerName;
                    worksheet.Cell(currentRow, 4).Value = ticket.BillNumber;
                    worksheet.Cell(currentRow, 5).Value = ticket.BillDate;
                    
                    string statusText = ticket.Status switch
                    {
                        TicketStatus.Open => "مفتوح",
                        TicketStatus.InProgress => "قيد المعالجة",
                        TicketStatus.Resolved => "تم الحل",
                        TicketStatus.Closed => "مغلق",
                        _ => ticket.Status.ToString()
                    };
                    worksheet.Cell(currentRow, 6).Value = statusText;
                    
                    worksheet.Cell(currentRow, 7).Value = ticket.Description;
                    
                    var warehouseCell = worksheet.Cell(currentRow, 8);
                    warehouseCell.Value = ticket.Warehouse.Name;
                    warehouseCell.Style.Fill.BackgroundColor = XLColor.Red;
                    warehouseCell.Style.Font.FontColor = XLColor.White;

                    currentRow++;
                }

                worksheet.Columns().AdjustToContents();

                using (var stream = new MemoryStream())
                {
                    workbook.SaveAs(stream);
                    var content = stream.ToArray();
                    return File(content, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "Tickets.xlsx");
                }
            }
        }

        // GET: Tickets
        public async Task<IActionResult> Index(string searchString, string searchType, string sortOrder, DateTime? startDate, DateTime? endDate)
        {
            ViewData["ProblemTypeSortParm"] = String.IsNullOrEmpty(sortOrder) ? "problem_desc" : "";
            ViewData["StatusSortParm"] = sortOrder == "Status" ? "status_desc" : "Status";
            ViewData["CustomerNameSortParm"] = sortOrder == "CustomerName" ? "customer_desc" : "CustomerName";
            ViewData["BillNumberSortParm"] = sortOrder == "BillNumber" ? "bill_desc" : "BillNumber";
            ViewData["BillDateSortParm"] = sortOrder == "BillDate" ? "date_desc" : "BillDate";
            ViewData["WarehouseSortParm"] = sortOrder == "Warehouse" ? "warehouse_desc" : "Warehouse";
            ViewData["CreatedDateSortParm"] = sortOrder == "CreatedDate" ? "created_desc" : "CreatedDate";
            ViewData["CreatorSortParm"] = sortOrder == "Creator" ? "creator_desc" : "Creator";
            ViewData["AssignedToSortParm"] = sortOrder == "AssignedTo" ? "assigned_desc" : "AssignedTo";
            
            ViewData["StartDate"] = startDate?.ToString("yyyy-MM-dd");
            ViewData["EndDate"] = endDate?.ToString("yyyy-MM-dd");

            var user = await _userManager.GetUserAsync(User);
            if (user == null) return Challenge();

            IQueryable<Ticket> tickets = _context.Tickets
                .Include(t => t.Creator)
                .Include(t => t.AssignedTo)
                .Include(t => t.Warehouse);

            if (await _userManager.IsInRoleAsync(user, "Admin"))
            {
                // Admin sees all
            }
            else
            {
                // Users and Editors see tickets for their warehouses
                var userWarehouseIds = await _context.UserWarehouses
                    .Where(uw => uw.UserId == user.Id)
                    .Select(uw => uw.WarehouseId)
                    .ToListAsync();

                tickets = tickets.Where(t => userWarehouseIds.Contains(t.WarehouseId));
            }

            if (!string.IsNullOrEmpty(searchString))
            {
                switch (searchType)
                {
                    case "CustomerName":
                        tickets = tickets.Where(s => s.CustomerName.Contains(searchString));
                        break;
                    case "BillNumber":
                        tickets = tickets.Where(s => s.BillNumber.Contains(searchString));
                        break;
                    case "WarehouseName":
                        tickets = tickets.Where(s => s.Warehouse.Name.Contains(searchString));
                        break;
                    default:
                        tickets = tickets.Where(s => s.ProblemType.Contains(searchString));
                        break;
                }
            }
            
            if (startDate.HasValue)
            {
                tickets = tickets.Where(t => t.CreatedDate >= startDate.Value);
            }

            if (endDate.HasValue)
            {
                // Add one day to include tickets created on the end date (up to 23:59:59)
                var nextDay = endDate.Value.AddDays(1);
                tickets = tickets.Where(t => t.CreatedDate < nextDay);
            }

            switch (sortOrder)
            {
                case "problem_desc":
                    tickets = tickets.OrderByDescending(s => s.ProblemType);
                    break;
                case "Status":
                    tickets = tickets.OrderBy(s => s.Status);
                    break;
                case "status_desc":
                    tickets = tickets.OrderByDescending(s => s.Status);
                    break;
                case "CustomerName":
                    tickets = tickets.OrderBy(s => s.CustomerName);
                    break;
                case "customer_desc":
                    tickets = tickets.OrderByDescending(s => s.CustomerName);
                    break;
                case "BillNumber":
                    tickets = tickets.OrderBy(s => s.BillNumber);
                    break;
                case "bill_desc":
                    tickets = tickets.OrderByDescending(s => s.BillNumber);
                    break;
                case "BillDate":
                    tickets = tickets.OrderBy(s => s.BillDate);
                    break;
                case "date_desc":
                    tickets = tickets.OrderByDescending(s => s.BillDate);
                    break;
                case "Warehouse":
                    tickets = tickets.OrderBy(s => s.Warehouse.Name);
                    break;
                case "warehouse_desc":
                    tickets = tickets.OrderByDescending(s => s.Warehouse.Name);
                    break;
                case "CreatedDate":
                    tickets = tickets.OrderBy(s => s.CreatedDate);
                    break;
                case "created_desc":
                    tickets = tickets.OrderByDescending(s => s.CreatedDate);
                    break;
                case "Creator":
                    tickets = tickets.OrderBy(s => s.Creator.UserName);
                    break;
                case "creator_desc":
                    tickets = tickets.OrderByDescending(s => s.Creator.UserName);
                    break;
                case "AssignedTo":
                    tickets = tickets.OrderBy(s => s.AssignedTo.UserName);
                    break;
                case "assigned_desc":
                    tickets = tickets.OrderByDescending(s => s.AssignedTo.UserName);
                    break;
                default:
                    tickets = tickets.OrderBy(s => s.ProblemType);
                    break;
            }

            var ticketList = await tickets.ToListAsync();
            
            // Logic for unread comments or new tickets notification
            var unreadTicketIds = new List<int>();
            try
            {
                foreach (var ticket in ticketList)
                {
                    var viewStatus = await _context.TicketViewStatuses
                        .FirstOrDefaultAsync(v => v.TicketId == ticket.Id && v.UserId == user.Id);

                    // Case 1: New Ticket (Never viewed by this user)
                    if (viewStatus == null)
                    {
                        unreadTicketIds.Add(ticket.Id);
                        continue;
                    }

                    // Case 2: New Comment (Viewed before, but has newer comments from others)
                    var lastCommentFromOthers = await _context.Comments
                        .Where(c => c.TicketId == ticket.Id && c.AuthorId != user.Id)
                        .OrderByDescending(c => c.CreatedDate)
                        .FirstOrDefaultAsync();

                    if (lastCommentFromOthers != null && lastCommentFromOthers.CreatedDate > viewStatus.LastViewedDate)
                    {
                        unreadTicketIds.Add(ticket.Id);
                    }
                }
            }
            catch (Exception)
            {
                // If the table doesn't exist yet, we just skip notifications for now
            }
            ViewBag.UnreadTicketIds = unreadTicketIds;

            return View(ticketList);
        }

        // GET: Tickets/Details/5
        public async Task<IActionResult> Details(int? id)
        {
            if (id == null || _context.Tickets == null)
            {
                return NotFound();
            }

            var ticket = await _context.Tickets
                .Include(t => t.Creator)
                .Include(t => t.AssignedTo)
                .Include(t => t.Warehouse)
                .Include(t => t.Comments)
                    .ThenInclude(c => c.Author)
                .Include(t => t.Comments)
                    .ThenInclude(c => c.Attachments)
                .Include(t => t.Attachments)
                .FirstOrDefaultAsync(m => m.Id == id);

            if (ticket == null)
            {
                return NotFound();
            }

            // Check access
            var user = await _userManager.GetUserAsync(User);
            if (!await _userManager.IsInRoleAsync(user, "Admin"))
            {
                var userWarehouseIds = await _context.UserWarehouses
                    .Where(uw => uw.UserId == user.Id)
                    .Select(uw => uw.WarehouseId)
                    .ToListAsync();

                if (!userWarehouseIds.Contains(ticket.WarehouseId))
                {
                    return Forbid();
                }
            }

            // Mark as read
            // Mark as read (Safe Wrap)
            try
            {
                var viewStatus = await _context.TicketViewStatuses
                    .FirstOrDefaultAsync(v => v.TicketId == ticket.Id && v.UserId == user.Id);
                
                if (viewStatus == null)
                {
                    _context.TicketViewStatuses.Add(new TicketViewStatus
                    {
                        TicketId = ticket.Id,
                        UserId = user.Id,
                        LastViewedDate = TimeHelper.GetBaghdadTime()
                    });
                }
                else
                {
                    viewStatus.LastViewedDate = TimeHelper.GetBaghdadTime();
                    _context.Update(viewStatus);
                }
                await _context.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                // Log exception silently or debug. 
                // This fails if TicketViewStatuses table is missing, but we still want to show the ticket details.
                Console.WriteLine($"Error updating TicketViewStatus: {ex.Message}");
            }

            return View(ticket);
        }

        // GET: Tickets/Create
        public async Task<IActionResult> Create()
        {
            var user = await _userManager.GetUserAsync(User);
            
            IEnumerable<Warehouse> warehouses;
            if (await _userManager.IsInRoleAsync(user, "Admin"))
            {
                warehouses = await _context.Warehouses.ToListAsync();
            }
            else
            {
                warehouses = await _context.UserWarehouses
                    .Where(uw => uw.UserId == user.Id)
                    .Include(uw => uw.Warehouse)
                    .Select(uw => uw.Warehouse)
                    .ToListAsync();
            }

            ViewData["WarehouseId"] = new SelectList(warehouses, "Id", "Name");
            return View();
        }

        // POST: Tickets/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create([Bind("ProblemType,Description,CustomerName,BillNumber,BillDate,WarehouseId")] Ticket ticket, List<IFormFile> attachments)
        {
            var user = await _userManager.GetUserAsync(User);
            
            // Validate Warehouse Access
            var hasAccess = await _context.UserWarehouses
                .AnyAsync(uw => uw.UserId == user.Id && uw.WarehouseId == ticket.WarehouseId);
            
            if (!hasAccess && !await _userManager.IsInRoleAsync(user, "Admin"))
            {
                ModelState.AddModelError("WarehouseId", "You do not have access to this warehouse.");
            }

            if (ModelState.IsValid)
            {
                ticket.CreatorId = user.Id;
                ticket.Status = TicketStatus.Open;
                ticket.CreatedDate = TimeHelper.GetBaghdadTime();
                
                _context.Add(ticket);
                await _context.SaveChangesAsync();

                if (attachments != null && attachments.Count > 0)
                {
                    foreach (var file in attachments)
                    {
                        if (file.Length > 0)
                        {
                            var fileName = Path.GetFileName(file.FileName);
                            var filePath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot/uploads", fileName);
                            
                            Directory.CreateDirectory(Path.Combine(Directory.GetCurrentDirectory(), "wwwroot/uploads"));

                            using (var stream = new FileStream(filePath, FileMode.Create))
                            {
                                await file.CopyToAsync(stream);
                            }

                            var attachment = new TicketAttachment
                            {
                                FileName = fileName,
                                FilePath = "/uploads/" + fileName,
                                TicketId = ticket.Id,
                                UploadedDate = TimeHelper.GetBaghdadTime()
                            };
                            _context.TicketAttachments.Add(attachment);
                        }
                    }
                    await _context.SaveChangesAsync();
                }

                // Notify via SignalR for mobile and web
                await _hubContext.Clients.All.SendAsync("ticket_created", new
                {
                    ticket.Id,
                    ticket.ProblemType,
                    ticket.WarehouseId,
                    ticket.CreatedDate
                });

                return RedirectToAction(nameof(Index));
            }
            
            IEnumerable<Warehouse> warehouses;
            if (await _userManager.IsInRoleAsync(user, "Admin"))
            {
                warehouses = await _context.Warehouses.ToListAsync();
            }
            else
            {
                warehouses = await _context.UserWarehouses
                    .Where(uw => uw.UserId == user.Id)
                    .Include(uw => uw.Warehouse)
                    .Select(uw => uw.Warehouse)
                    .ToListAsync();
            }
            ViewData["WarehouseId"] = new SelectList(warehouses, "Id", "Name", ticket.WarehouseId);
            
            return View(ticket);
        }

        // GET: Tickets/Edit/5
        public async Task<IActionResult> Edit(int? id)
        {
            if (id == null || _context.Tickets == null)
            {
                return NotFound();
            }

            var ticket = await _context.Tickets.FindAsync(id);
            if (ticket == null)
            {
                return NotFound();
            }

            // Authorization check
            var user = await _userManager.GetUserAsync(User);
            bool isAdmin = await _userManager.IsInRoleAsync(user, "Admin");
            bool isEditor = await _userManager.IsInRoleAsync(user, "Editor");
            
            if (!isAdmin && !isEditor)
            {
                return Forbid();
            }
            
            if (!isAdmin)
            {
                 var hasAccess = await _context.UserWarehouses
                    .AnyAsync(uw => uw.UserId == user.Id && uw.WarehouseId == ticket.WarehouseId);
                 if (!hasAccess) return Forbid();
            }

            ViewData["AssignedToId"] = new SelectList(_userManager.Users, "Id", "UserName", ticket.AssignedToId);
            
            var userWarehouses = await _context.UserWarehouses
                .Where(uw => uw.UserId == user.Id)
                .Include(uw => uw.Warehouse)
                .Select(uw => uw.Warehouse)
                .ToListAsync();
            
            IEnumerable<Warehouse> warehouses;
            if (isAdmin)
            {
                warehouses = await _context.Warehouses.ToListAsync();
            }
            else
            {
                warehouses = userWarehouses;
            }
            ViewData["WarehouseId"] = new SelectList(warehouses, "Id", "Name", ticket.WarehouseId);

            return View(ticket);
        }

        // POST: Tickets/Edit/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(int id, [Bind("Id,ProblemType,Description,Status,CustomerName,BillNumber,BillDate,WarehouseId,AssignedToId")] Ticket ticket)
        {
            if (id != ticket.Id)
            {
                return NotFound();
            }

            var user = await _userManager.GetUserAsync(User);
            bool isAdmin = await _userManager.IsInRoleAsync(user, "Admin");
            bool isEditor = await _userManager.IsInRoleAsync(user, "Editor");

            if (!isAdmin && !isEditor)
            {
                return Forbid();
            }

            // We need to fetch the original ticket to preserve CreatorId and CreatedDate
            var originalTicket = await _context.Tickets.AsNoTracking().FirstOrDefaultAsync(t => t.Id == id);
            if (originalTicket == null) return NotFound();

            if (!isAdmin)
            {
                 var hasAccess = await _context.UserWarehouses
                    .AnyAsync(uw => uw.UserId == user.Id && uw.WarehouseId == originalTicket.WarehouseId);
                 if (!hasAccess) return Forbid();
            }

            // Re-attach properties that shouldn't change or are not in form
            ticket.CreatorId = originalTicket.CreatorId;
            ticket.CreatedDate = originalTicket.CreatedDate;

            if (ModelState.IsValid)
            {
                try
                {
                    _context.Update(ticket);
                    await _context.SaveChangesAsync();
                }
                catch (DbUpdateConcurrencyException)
                {
                    if (!TicketExists(ticket.Id))
                    {
                        return NotFound();
                    }
                    else
                    {
                        throw;
                    }
                }
                return RedirectToAction(nameof(Index));
            }
            ViewData["AssignedToId"] = new SelectList(_userManager.Users, "Id", "UserName", ticket.AssignedToId);

             IEnumerable<Warehouse> warehouses;
            if (await _userManager.IsInRoleAsync(user, "Admin"))
            {
                warehouses = await _context.Warehouses.ToListAsync();
            }
            else
            {
                warehouses = await _context.UserWarehouses
                    .Where(uw => uw.UserId == user.Id)
                    .Include(uw => uw.Warehouse)
                    .Select(uw => uw.Warehouse)
                    .ToListAsync();
            }
            ViewData["WarehouseId"] = new SelectList(warehouses, "Id", "Name", ticket.WarehouseId);
            return View(ticket);
        }

        // POST: Tickets/EndTicket/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "Admin,Editor")]
        public async Task<IActionResult> EndTicket(int id)
        {
            var ticket = await _context.Tickets.FindAsync(id);
            if (ticket == null)
            {
                return NotFound();
            }

            // Check access for Editor
            var user = await _userManager.GetUserAsync(User);
            if (!await _userManager.IsInRoleAsync(user, "Admin"))
            {
                var userWarehouseIds = await _context.UserWarehouses
                    .Where(uw => uw.UserId == user.Id)
                    .Select(uw => uw.WarehouseId)
                    .ToListAsync();

                if (!userWarehouseIds.Contains(ticket.WarehouseId))
                {
                    return Forbid();
                }
            }

            ticket.Status = TicketStatus.Closed;
            _context.Update(ticket);
            await _context.SaveChangesAsync();

            return RedirectToAction(nameof(Details), new { id = ticket.Id });
        }

        // POST: Tickets/AddComment
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> AddComment(int ticketId, string content, List<IFormFile> attachments)
        {
            if (string.IsNullOrWhiteSpace(content)) return RedirectToAction("Details", new { id = ticketId });

            var ticket = await _context.Tickets.FindAsync(ticketId);
            if (ticket == null) return NotFound();

            var user = await _userManager.GetUserAsync(User);

            var comment = new Comment
            {
                Content = content,
                TicketId = ticketId,
                AuthorId = user.Id,
                CreatedDate = TimeHelper.GetBaghdadTime()
            };

            _context.Comments.Add(comment);
            await _context.SaveChangesAsync();

            if (attachments != null && attachments.Count > 0)
            {
                foreach (var file in attachments)
                {
                    if (file.Length > 0)
                    {
                        var fileName = Path.GetFileName(file.FileName);
                        var filePath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot/uploads", fileName);

                        Directory.CreateDirectory(Path.Combine(Directory.GetCurrentDirectory(), "wwwroot/uploads"));

                        using (var stream = new FileStream(filePath, FileMode.Create))
                        {
                            await file.CopyToAsync(stream);
                        }

                        var attachment = new TicketAttachment
                        {
                            FileName = fileName,
                            FilePath = "/uploads/" + fileName,
                            CommentId = comment.Id,
                            UploadedDate = TimeHelper.GetBaghdadTime()
                        };
                        _context.TicketAttachments.Add(attachment);
                    }
                }
                await _context.SaveChangesAsync();
            }

            // Notify via SignalR for the blue badge
            await _hubContext.Clients.All.SendAsync("NewCommentNotification", ticketId, user.Id, ticket.WarehouseId);

            return RedirectToAction("Details", new { id = ticketId });
        }

        [HttpPost]
        [Authorize(Roles = "Admin")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteAttachment(int id)
        {
            var attachment = await _context.TicketAttachments.FindAsync(id);
            if (attachment == null) return NotFound();

            // Optional: Delete file from disk
            // var filePath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", attachment.FilePath.TrimStart('/'));
            // if (System.IO.File.Exists(filePath)) System.IO.File.Delete(filePath);

            int? ticketId = attachment.TicketId;
            if (ticketId == null && attachment.CommentId != null)
            {
                var comment = await _context.Comments.FindAsync(attachment.CommentId);
                ticketId = comment?.TicketId;
            }

            _context.TicketAttachments.Remove(attachment);
            await _context.SaveChangesAsync();

            if (ticketId != null)
                return RedirectToAction("Details", new { id = ticketId });
            
            return RedirectToAction("Index");
        }

        [HttpPost]
        [Authorize(Roles = "Admin")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ReplaceAttachment(int id, IFormFile newFile)
        {
            var attachment = await _context.TicketAttachments.FindAsync(id);
            if (attachment == null) return NotFound();

            if (newFile != null && newFile.Length > 0)
            {
                var fileName = Path.GetFileName(newFile.FileName);
                var filePath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot/uploads", fileName);

                Directory.CreateDirectory(Path.Combine(Directory.GetCurrentDirectory(), "wwwroot/uploads"));

                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await newFile.CopyToAsync(stream);
                }

                attachment.FileName = fileName;
                attachment.FilePath = "/uploads/" + fileName;
                attachment.UploadedDate = TimeHelper.GetBaghdadTime();

                _context.Update(attachment);
                await _context.SaveChangesAsync();
            }

            int? ticketId = attachment.TicketId;
            if (ticketId == null && attachment.CommentId != null)
            {
                var comment = await _context.Comments.FindAsync(attachment.CommentId);
                ticketId = comment?.TicketId;
            }

            if (ticketId != null)
                return RedirectToAction("Details", new { id = ticketId });

            return RedirectToAction("Index");
        }

        // GET: Tickets/EditComment/5
        public async Task<IActionResult> EditComment(int? id)
        {
            if (id == null || _context.Comments == null)
            {
                return NotFound();
            }

            var comment = await _context.Comments.FindAsync(id);
            if (comment == null)
            {
                return NotFound();
            }

            var user = await _userManager.GetUserAsync(User);
            
            // Check if user is author
            if (comment.AuthorId != user.Id && !await _userManager.IsInRoleAsync(user, "Admin")) 
            {
                return Forbid();
            }

            // If user is NOT Admin, apply time and "last comment" constraints
            if (!await _userManager.IsInRoleAsync(user, "Admin"))
            {
                // Time Limit: 24 Hours
                if (TimeHelper.GetBaghdadTime() > comment.CreatedDate.AddHours(24))
                {
                    return Forbid();
                }

                // Last Comment Constraint
                var lastCommentId = await _context.Comments
                    .Where(c => c.TicketId == comment.TicketId && c.AuthorId == user.Id)
                    .OrderByDescending(c => c.CreatedDate)
                    .Select(c => c.Id)
                    .FirstOrDefaultAsync();

                if (lastCommentId != comment.Id)
                {
                    return Forbid();
                }
            }

            return View(comment);
        }

        // POST: Tickets/EditComment/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> EditComment(int id, [Bind("Id,Content")] Comment comment)
        {
            if (id != comment.Id)
            {
                return NotFound();
            }

            var originalComment = await _context.Comments.FindAsync(id);
            if (originalComment == null) return NotFound();

            var user = await _userManager.GetUserAsync(User);

             // Check if user is author
            if (originalComment.AuthorId != user.Id && !await _userManager.IsInRoleAsync(user, "Admin")) 
            {
                return Forbid();
            }

             // If user is NOT Admin, apply constraints
            if (!await _userManager.IsInRoleAsync(user, "Admin"))
            {
                if (DateTime.Now > originalComment.CreatedDate.AddHours(24))
                {
                    return Forbid();
                }

                var lastCommentId = await _context.Comments
                    .Where(c => c.TicketId == originalComment.TicketId && c.AuthorId == user.Id)
                    .OrderByDescending(c => c.CreatedDate)
                    .Select(c => c.Id)
                    .FirstOrDefaultAsync();

                if (lastCommentId != originalComment.Id)
                {
                    return Forbid();
                }
            }

            if (ModelState.IsValid)
            {
                originalComment.Content = comment.Content;
                _context.Update(originalComment);
                await _context.SaveChangesAsync();
                return RedirectToAction("Details", new { id = originalComment.TicketId });
            }
            return View(comment);
        }

        // POST: Tickets/DeleteComment/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> DeleteComment(int id)
        {
            var comment = await _context.Comments.FindAsync(id);
            if (comment == null)
            {
                return NotFound();
            }

            int ticketId = comment.TicketId;
            _context.Comments.Remove(comment);
            await _context.SaveChangesAsync();

            return RedirectToAction("Details", new { id = ticketId });
        }

        // POST: Tickets/Delete/5
        [HttpPost, ActionName("Delete")]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> DeleteConfirmed(int id)
        {
            if (_context.Tickets == null)
            {
                return Problem("Entity set 'ApplicationDbContext.Tickets' is null.");
            }

            try
            {
                var ticket = await _context.Tickets
                    .Include(t => t.Comments)
                        .ThenInclude(c => c.Attachments)
                    .Include(t => t.Attachments)
                    .FirstOrDefaultAsync(t => t.Id == id);

                if (ticket != null)
                {
                    // 1. Remove attachments belonging to comments
                    if (ticket.Comments != null)
                    {
                        foreach (var comment in ticket.Comments)
                        {
                            if (comment.Attachments != null && comment.Attachments.Any())
                            {
                                _context.TicketAttachments.RemoveRange(comment.Attachments);
                            }
                        }
                        // 2. Remove comments
                        _context.Comments.RemoveRange(ticket.Comments);
                    }

                    // 3. Remove attachments belonging to the ticket directly
                    if (ticket.Attachments != null && ticket.Attachments.Any())
                    {
                        _context.TicketAttachments.RemoveRange(ticket.Attachments.Where(a => a.TicketId != null));
                    }

                    // 4. Finally remove the ticket
                    _context.Tickets.Remove(ticket);
                    
                    await _context.SaveChangesAsync();
                }
            }
            catch (Exception ex)
            {
                // Return descriptive error
                return Problem("حدث خطأ أثناء محاولة حذف التذكرة. قد يكون السبب وجود بيانات مرتبطة بها. التفاصيل: " + ex.Message);
            }

            return RedirectToAction(nameof(Index));
        }

        private bool TicketExists(int id)
        {
          return (_context.Tickets?.Any(e => e.Id == id)).GetValueOrDefault();
        }
    }
}
