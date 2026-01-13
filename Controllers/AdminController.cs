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

namespace Backend.Controllers
{
    [Authorize(Roles = "Admin")]
    public class AdminController : Controller
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;

        public AdminController(ApplicationDbContext context, UserManager<ApplicationUser> userManager)
        {
            _context = context;
            _userManager = userManager;
        }

        public IActionResult Index()
        {
            return View();
        }

        // --- Warehouse Management ---
        public async Task<IActionResult> Warehouses()
        {
            return View(await _context.Warehouses.ToListAsync());
        }

        public IActionResult CreateWarehouse()
        {
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> CreateWarehouse([Bind("Id,Name")] Warehouse warehouse)
        {
            if (ModelState.IsValid)
            {
                _context.Add(warehouse);
                await _context.SaveChangesAsync();
                return RedirectToAction(nameof(Warehouses));
            }
            return View(warehouse);
        }

        public async Task<IActionResult> EditWarehouse(int? id)
        {
            if (id == null) return NotFound();
            var warehouse = await _context.Warehouses.FindAsync(id);
            if (warehouse == null) return NotFound();
            return View(warehouse);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> EditWarehouse(int id, [Bind("Id,Name")] Warehouse warehouse)
        {
            if (id != warehouse.Id) return NotFound();

            if (ModelState.IsValid)
            {
                try
                {
                    _context.Update(warehouse);
                    await _context.SaveChangesAsync();
                }
                catch (DbUpdateConcurrencyException)
                {
                    if (!_context.Warehouses.Any(e => e.Id == warehouse.Id)) return NotFound();
                    else throw;
                }
                return RedirectToAction(nameof(Warehouses));
            }
            return View(warehouse);
        }

        public async Task<IActionResult> DeleteWarehouse(int? id)
        {
            if (id == null) return NotFound();
            var warehouse = await _context.Warehouses.FirstOrDefaultAsync(m => m.Id == id);
            if (warehouse == null) return NotFound();
            return View(warehouse);
        }

        [HttpPost, ActionName("DeleteWarehouse")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteWarehouseConfirmed(int id)
        {
            var warehouse = await _context.Warehouses.FindAsync(id);
            if (warehouse != null)
            {
                _context.Warehouses.Remove(warehouse);
                await _context.SaveChangesAsync();
            }
            return RedirectToAction(nameof(Warehouses));
        }

        // --- User Management ---
        public async Task<IActionResult> Users()
        {
            var users = await _userManager.Users.Include(u => u.UserWarehouses).ThenInclude(uw => uw.Warehouse).ToListAsync();
            return View(users);
        }

        public async Task<IActionResult> CreateUser()
        {
            ViewBag.Warehouses = await _context.Warehouses.ToListAsync();
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> CreateUser(string email, string password, string firstName, string lastName, string role, string[] selectedWarehouses)
        {
            if (ModelState.IsValid)
            {
                var user = new ApplicationUser { UserName = email, Email = email, FirstName = firstName, LastName = lastName };
                var result = await _userManager.CreateAsync(user, password);
                if (result.Succeeded)
                {
                    if (!string.IsNullOrEmpty(role))
                    {
                        await _userManager.AddToRoleAsync(user, role);
                    }

                    if (selectedWarehouses != null)
                    {
                        foreach (var warehouseId in selectedWarehouses)
                        {
                            _context.UserWarehouses.Add(new UserWarehouse { UserId = user.Id, WarehouseId = int.Parse(warehouseId) });
                        }
                        await _context.SaveChangesAsync();
                    }

                    return RedirectToAction(nameof(Users));
                }
                foreach (var error in result.Errors)
                {
                    ModelState.AddModelError(string.Empty, error.Description);
                }
            }
            ViewBag.Warehouses = await _context.Warehouses.ToListAsync();
            return View();
        }

        public async Task<IActionResult> EditUser(string id)
        {
            if (id == null) return NotFound();
            var user = await _userManager.Users.Include(u => u.UserWarehouses).FirstOrDefaultAsync(u => u.Id == id);
            if (user == null) return NotFound();

            ViewBag.Warehouses = await _context.Warehouses.ToListAsync();
            return View(user);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> EditUser(string id, string[] selectedWarehouses)
        {
            var user = await _userManager.Users.Include(u => u.UserWarehouses).FirstOrDefaultAsync(u => u.Id == id);
            if (user == null) return NotFound();

            // Update Warehouses
            _context.UserWarehouses.RemoveRange(user.UserWarehouses);
            if (selectedWarehouses != null)
            {
                foreach (var warehouseId in selectedWarehouses)
                {
                    _context.UserWarehouses.Add(new UserWarehouse { UserId = user.Id, WarehouseId = int.Parse(warehouseId) });
                }
            }
            await _context.SaveChangesAsync();

            return RedirectToAction(nameof(Users));
        }

        public async Task<IActionResult> ResetPassword(string id)
        {
            if (id == null) return NotFound();
            var user = await _userManager.FindByIdAsync(id);
            if (user == null) return NotFound();
            return View(user);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ResetPassword(string id, string newPassword)
        {
            var user = await _userManager.FindByIdAsync(id);
            if (user == null) return NotFound();

            var token = await _userManager.GeneratePasswordResetTokenAsync(user);
            var result = await _userManager.ResetPasswordAsync(user, token, newPassword);

            if (result.Succeeded)
            {
                return RedirectToAction(nameof(Users));
            }

            foreach (var error in result.Errors)
            {
                ModelState.AddModelError(string.Empty, error.Description);
            }
            return View(user);
        }
    }
}
