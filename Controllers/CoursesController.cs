using StudentManager.Data;
using StudentManager.Models;
using Microsoft.AspNetCore.Mvc;

namespace StudentManager.Controllers
{
    // 课程管理控制器：Admin 可增删改查
    public class CoursesController : Controller
    {
        private readonly ApplicationDbContext _context;

        public CoursesController(ApplicationDbContext context)
        {
            _context = context;
        }

        private bool IsAdmin()
        {
            return HttpContext.Session.GetString("Role") == "Admin";
        }

        // 显示课程列表
        [HttpGet]
        public IActionResult Index()
        {
            return View(_context.Courses.ToList());
        }

        // 添加课程（仅管理员）
        [HttpGet]
        public IActionResult Create()
        {
            if (!IsAdmin()) return Unauthorized();
            return View();
        }

        [HttpPost]
        public IActionResult Create(Course course)
        {
            if (!IsAdmin()) return Unauthorized();
            if (ModelState.IsValid)
            {
                _context.Courses.Add(course);
                _context.SaveChanges();
                return RedirectToAction("Index");
            }
            return View(course);
        }

        // 编辑课程（仅管理员）
        [HttpGet]
        public IActionResult Edit(int id)
        {
            if (!IsAdmin()) return Unauthorized();
            var course = _context.Courses.Find(id);
            if (course == null) return NotFound();
            return View(course);
        }

        [HttpPost]
        public IActionResult Edit(Course course)
        {
            if (!IsAdmin()) return Unauthorized();
            if (ModelState.IsValid)
            {
                _context.Courses.Update(course);
                _context.SaveChanges();
                return RedirectToAction("Index");
            }
            return View(course);
        }

        // 删除课程（仅管理员）
        [HttpGet]
        public IActionResult Delete(int id)
        {
            if (!IsAdmin()) return Unauthorized();
            var course = _context.Courses.Find(id);
            if (course == null) return NotFound();
            return View(course);
        }

        [HttpPost, ActionName("Delete")]
        public IActionResult DeleteConfirmed(int id)
        {
            if (!IsAdmin()) return Unauthorized();
            var course = _context.Courses.Find(id);
            if (course != null)
            {
                _context.Courses.Remove(course);
                _context.SaveChanges();
            }
            return RedirectToAction("Index");
        }
    }
}
