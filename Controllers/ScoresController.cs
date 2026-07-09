using StudentManager.Data;
using StudentManager.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace StudentManager.Controllers
{
    // 成绩管理控制器：Admin 可录入/编辑，学生查看自己的
    public class ScoresController : Controller
    {
        private readonly ApplicationDbContext _context;

        public ScoresController(ApplicationDbContext context)
        {
            _context = context;
        }

        private bool IsAdmin()
        {
            return HttpContext.Session.GetString("Role") == "Admin";
        }

        // 成绩列表（管理员查看全部，含学生与课程信息）
        [HttpGet]
        public IActionResult Index()
        {
            if (!IsAdmin()) return Unauthorized();
            var scores = _context.Scores
                .Include(sc => sc.Student)
                .Include(sc => sc.Course)
                .ToList();
            return View(scores);
        }

        // 录入成绩页面（仅管理员）
        [HttpGet]
        public IActionResult Create()
        {
            if (!IsAdmin()) return Unauthorized();
            ViewBag.Students = _context.Students.ToList();
            ViewBag.Courses = _context.Courses.ToList();
            return View();
        }

        [HttpPost]
        public IActionResult Create(Score score)
        {
            if (!IsAdmin()) return Unauthorized();

            // ScoreDate / Student / Course 不由表单直接提交，清除其绑定错误后再校验
            ModelState.Remove(nameof(Score.ScoreDate));
            ModelState.Remove(nameof(Score.Student));
            ModelState.Remove(nameof(Score.Course));
            score.ScoreDate = DateTime.Now;

            if (ModelState.IsValid)
            {
                _context.Scores.Add(score);
                _context.SaveChanges();
                return RedirectToAction("Index");
            }
            // 诊断：把校验错误暴露到页面
            ViewBag.Error = string.Join("; ", ModelState.Values
                .SelectMany(v => v.Errors)
                .Select(e => e.ErrorMessage));
            ViewBag.Students = _context.Students.ToList();
            ViewBag.Courses = _context.Courses.ToList();
            return View(score);
        }

        // 编辑成绩（仅管理员）
        [HttpGet]
        public IActionResult Edit(int id)
        {
            if (!IsAdmin()) return Unauthorized();
            var score = _context.Scores.Find(id);
            if (score == null) return NotFound();
            ViewBag.Students = _context.Students.ToList();
            ViewBag.Courses = _context.Courses.ToList();
            return View(score);
        }

        [HttpPost]
        public IActionResult Edit(Score score)
        {
            if (!IsAdmin()) return Unauthorized();

            // ScoreDate / Student / Course 不在表单中，清除其绑定错误
            ModelState.Remove(nameof(Score.ScoreDate));
            ModelState.Remove(nameof(Score.Student));
            ModelState.Remove(nameof(Score.Course));

            if (ModelState.IsValid)
            {
                var existing = _context.Scores.Find(score.Id);
                if (existing == null) return NotFound();
                existing.StudentId = score.StudentId;
                existing.CourseId = score.CourseId;
                existing.Grade = score.Grade;
                // ScoreDate 保持原值
                _context.SaveChanges();
                return RedirectToAction("Index");
            }
            ViewBag.Students = _context.Students.ToList();
            ViewBag.Courses = _context.Courses.ToList();
            return View(score);
        }
    }
}
