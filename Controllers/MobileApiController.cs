using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Backend.Data;
using Backend.Models;
using System.Text.Json;
using Microsoft.AspNetCore.SignalR;
using Backend.Hubs;

namespace Backend.Controllers
{
    [ApiController]
    [Route("api/mobile")]
    public class MobileApiController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly SignInManager<ApplicationUser> _signInManager;
        private readonly IHubContext<TicketHub> _hubContext;

        public MobileApiController(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager,
            SignInManager<ApplicationUser> signInManager,
            IHubContext<TicketHub> hubContext)
        {
            _context = context;
            _userManager = userManager;
            _signInManager = signInManager;
            _hubContext = hubContext;
        }

        // POST: api/mobile/login
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            if (string.IsNullOrEmpty(request.Username) || string.IsNullOrEmpty(request.Password))
            {
                return BadRequest(new { success = false, message = "Username and password required" });
            }

            var username = request.Username.Trim();
            var user = await _userManager.FindByNameAsync(username);
            
            if (user == null)
            {
                user = await _userManager.FindByEmailAsync(username);
            }

            if (user == null)
            {
                return Unauthorized(new { success = false, message = "اسم المستخدم أو كلمة المرور غير صحيحة" });
            }

            var result = await _signInManager.CheckPasswordSignInAsync(user, request.Password, false);
            if (!result.Succeeded)
            {
                return Unauthorized(new { success = false, message = "اسم المستخدم أو كلمة المرور غير صحيحة" });
            }

            // Get user roles
            var roles = await _userManager.GetRolesAsync(user);

            // Get user warehouses
            var warehouses = await _context.UserWarehouses
                .Where(uw => uw.UserId == user.Id)
                .Include(uw => uw.Warehouse)
                .Select(uw => new { uw.Warehouse.Id, uw.Warehouse.Name })
                .ToListAsync();

            return Ok(new
            {
                success = true,
                user = new
                {
                    id = user.Id,
                    username = user.UserName,
                    roles = roles,
                    warehouses = warehouses,
                    isAdmin = roles.Contains("Admin")
                }
            });
        }

        // GET: api/mobile/tickets?userId={userId}
        [HttpGet("tickets")]
        public async Task<IActionResult> GetTickets([FromQuery] string userId)
        {
            if (string.IsNullOrEmpty(userId))
            {
                return BadRequest(new { error = "userId required" });
            }

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
            {
                return NotFound(new { error = "User not found" });
            }

            var roles = await _userManager.GetRolesAsync(user);
            var isAdmin = roles.Contains("Admin");

            IQueryable<Ticket> ticketsQuery = _context.Tickets
                .Include(t => t.Warehouse)
                .Include(t => t.Creator)
                .Include(t => t.AssignedTo);

            // If not admin, filter by user's warehouses
            if (!isAdmin)
            {
                var userWarehouseIds = await _context.UserWarehouses
                    .Where(uw => uw.UserId == userId)
                    .Select(uw => uw.WarehouseId)
                    .ToListAsync();

                ticketsQuery = ticketsQuery.Where(t => userWarehouseIds.Contains(t.WarehouseId));
            }

            var tickets = await ticketsQuery
                .OrderByDescending(t => t.CreatedDate)
                .Select(t => new
                {
                    t.Id,
                    t.ProblemType,
                    t.Description,
                    t.CustomerName,
                    t.BillNumber,
                    t.BillDate,
                    t.WarehouseId,
                    WarehouseName = t.Warehouse.Name,
                    t.Status,
                    t.CreatedDate,
                    t.CreatorId,
                    CommentCount = _context.Comments.Count(c => c.TicketId == t.Id),
                    LastCommentDate = _context.Comments
                        .Where(c => c.TicketId == t.Id)
                        .OrderByDescending(c => c.CreatedDate)
                        .Select(c => (DateTime?)c.CreatedDate)
                        .FirstOrDefault()
                })
                .ToListAsync();

            return Ok(tickets);
        }

        // GET: api/mobile/warehouses?userId={userId}
        [HttpGet("warehouses")]
        public async Task<IActionResult> GetWarehouses([FromQuery] string userId)
        {
            if (string.IsNullOrEmpty(userId))
            {
                return BadRequest(new { error = "userId required" });
            }

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
            {
                return NotFound(new { error = "User not found" });
            }

            var roles = await _userManager.GetRolesAsync(user);
            var isAdmin = roles.Contains("Admin");

            IQueryable<Warehouse> warehousesQuery = _context.Warehouses;

            // If not admin, filter by user's warehouses
            if (!isAdmin)
            {
                var userWarehouseIds = await _context.UserWarehouses
                    .Where(uw => uw.UserId == userId)
                    .Select(uw => uw.WarehouseId)
                    .ToListAsync();

                warehousesQuery = warehousesQuery.Where(w => userWarehouseIds.Contains(w.Id));
            }

            var warehouses = await warehousesQuery
                .Select(w => new { w.Id, w.Name })
                .ToListAsync();

            return Ok(warehouses);
        }

        // GET: api/mobile/tickets/{id}/attachments
        [HttpGet("tickets/{id}/attachments")]
        public async Task<IActionResult> GetTicketAttachments(int id)
        {
            var attachments = await _context.TicketAttachments
                .Where(a => a.TicketId == id)
                .Select(a => new
                {
                    a.Id,
                    a.FileName,
                    a.FilePath,
                    a.UploadedDate
                })
                .ToListAsync();

            return Ok(attachments);
        }

        // GET: api/mobile/tickets/{id}/comments
        [HttpGet("tickets/{id}/comments")]
        public async Task<IActionResult> GetTicketComments(int id)
        {
            var comments = await _context.Comments
                .Where(c => c.TicketId == id)
                .Include(c => c.Author)
                .OrderBy(c => c.CreatedDate)
                .Select(c => new
                {
                    c.Id,
                    c.Content,
                    c.CreatedDate,
                    c.TicketId,
                    AuthorName = c.Author.UserName
                })
                .ToListAsync();

            return Ok(comments);
        }

        // POST: api/mobile/tickets
        [HttpPost("tickets")]
        public async Task<IActionResult> CreateTicket([FromForm] CreateTicketRequest request)
        {
            if (string.IsNullOrEmpty(request.UserId))
            {
                return BadRequest(new { error = "userId required" });
            }

            var user = await _userManager.FindByIdAsync(request.UserId);
            if (user == null)
            {
                return NotFound(new { error = "User not found" });
            }

            var roles = await _userManager.GetRolesAsync(user);
            var isAdmin = roles.Contains("Admin");

            // Validate warehouse access
            if (!isAdmin)
            {
                var hasAccess = await _context.UserWarehouses
                    .AnyAsync(uw => uw.UserId == request.UserId && uw.WarehouseId == request.WarehouseId);

                if (!hasAccess)
                {
                    return Forbid();
                }
            }

            var ticket = new Ticket
            {
                ProblemType = request.ProblemType,
                Description = request.Description,
                CustomerName = request.CustomerName,
                BillNumber = request.BillNumber,
                BillDate = request.BillDate ?? TimeHelper.GetBaghdadTime(),
                WarehouseId = request.WarehouseId,
                Status = TicketStatus.Open,
                CreatedDate = TimeHelper.GetBaghdadTime(),
                CreatorId = request.UserId
            };

            _context.Tickets.Add(ticket);
            await _context.SaveChangesAsync();

            // Handle file attachments
            if (request.Attachments != null && request.Attachments.Count > 0)
            {
                var uploadPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads");
                Directory.CreateDirectory(uploadPath);

                foreach (var file in request.Attachments)
                {
                    if (file.Length > 0)
                    {
                        var fileName = Path.GetFileName(file.FileName);
                        var filePath = Path.Combine(uploadPath, fileName);

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

            // Trigger SignalR notification
            await _hubContext.Clients.All.SendAsync("ticket_created", new
            {
                ticket.Id,
                ticket.ProblemType,
                ticket.WarehouseId,
                ticket.CreatedDate
            });

            // Also notify specific warehouse group
            await _hubContext.Clients.Group($"Warehouse_{ticket.WarehouseId}").SendAsync("new_ticket", new
            {
                ticket.Id,
                ticket.ProblemType
            });

            return Ok(new { success = true, id = ticket.Id, message = "Ticket Created" });
        }

        // PUT: api/mobile/tickets/{id}/status
        [HttpPut("tickets/{id}/status")]
        public async Task<IActionResult> UpdateTicketStatus(int id, [FromBody] UpdateStatusRequest request)
        {
            var ticket = await _context.Tickets.FindAsync(id);
            if (ticket == null)
            {
                return NotFound();
            }

            ticket.Status = (TicketStatus)request.Status;
            await _context.SaveChangesAsync();

            return Ok(new { success = true });
        }

        // POST: api/mobile/tickets/{id}/comments
        [HttpPost("tickets/{id}/comments")]
        public async Task<IActionResult> AddComment(int id, [FromBody] AddCommentRequest request)
        {
            if (string.IsNullOrEmpty(request.UserId))
            {
                return BadRequest(new { error = "userId required" });
            }

            var ticket = await _context.Tickets.FindAsync(id);
            if (ticket == null)
            {
                return NotFound();
            }

            var comment = new Comment
            {
                Content = request.Content,
                TicketId = id,
                AuthorId = request.UserId,
                CreatedDate = TimeHelper.GetBaghdadTime()
            };

            _context.Comments.Add(comment);
            await _context.SaveChangesAsync();

            // Trigger SignalR notification for new comment
            await _hubContext.Clients.All.SendAsync("comment_added", new
            {
                id,
                ticketId = id,
                content = request.Content,
                authorId = request.UserId
            });

            return Ok(new { success = true });
        }
    }

    // Request DTOs
    public class LoginRequest
    {
        public string Username { get; set; }
        public string Password { get; set; }
    }

    public class CreateTicketRequest
    {
        public string UserId { get; set; }
        public string ProblemType { get; set; }
        public string Description { get; set; }
        public string CustomerName { get; set; }
        public string BillNumber { get; set; }
        public DateTime? BillDate { get; set; }
        public int WarehouseId { get; set; }
        public List<IFormFile>? Attachments { get; set; }
    }

    public class UpdateStatusRequest
    {
        public int Status { get; set; }
    }

    public class AddCommentRequest
    {
        public string UserId { get; set; }
        public string Content { get; set; }
    }
}
