using StudentManager.Data;
using StudentManager.Models;
using Microsoft.AspNetCore.Mvc;

namespace StudentManager.Controllers
{
    // 用户管理控制器，用于管理员管理用户
    public class UsersController : Controller
    {
        private readonly ApplicationDbContext _context;

        public UsersController(ApplicationDbContext context)
        {
            _context = context;
        }

        private bool IsAdmin()
        {
            return HttpContext.Session.GetString("Role") == "Admin";
        }

        // 显示所有用户
        public IActionResult Index()
        {
            if (!IsAdmin()) return Unauthorized();
            var users = _context.Users.ToList();
            return View(users);
        }

        // 编辑用户 GET 请求
        [HttpGet]
        public IActionResult Edit(int id)
        {
            if (!IsAdmin()) return Unauthorized();
            var user = _context.Users.Find(id);
            if (user == null) return NotFound();
            return View(user);
        }

        // 编辑用户 POST 请求
        [HttpPost]
        public IActionResult Edit(User user)
        {
            if (!IsAdmin()) return Unauthorized();
            if (ModelState.IsValid)
            {
                _context.Users.Update(user);
                _context.SaveChanges();
                return RedirectToAction("Index");
            }
            return View(user);
        }

        // 删除用户 GET 请求
        [HttpGet]
        public IActionResult Delete(int id)
        {
            if (!IsAdmin()) return Unauthorized();
            var user = _context.Users.Find(id);
            if (user == null) return NotFound();
            return View(user);
        }

        // 删除用户 POST 请求
        [HttpPost, ActionName("Delete")]
        public IActionResult DeleteConfirmed(int id)
        {
            if (!IsAdmin()) return Unauthorized();
            var user = _context.Users.Find(id);
            if (user != null)
            {
                _context.Users.Remove(user);
                _context.SaveChanges();
            }
            return RedirectToAction("Index");
        }
    }
}
