using StudentManager.Data; // 引入应用程序的数据访问相关类
using StudentManager.Models; // 引入应用程序的模型类
using Microsoft.AspNetCore.Mvc; // 引入 ASP.NET Core MVC 的核心功能
using Microsoft.EntityFrameworkCore; // 引入 Entity Framework Core 的核心功能
namespace StudentManager.Controllers
{
    // 账户控制器：负责注册、登录、注销、查看我的成绩
    public class AccountController : Controller
    {
        private readonly ApplicationDbContext _context;

        public AccountController(ApplicationDbContext context)
        {
            _context = context;
        }

        // Register (GET)：返回注册视图
        [HttpGet]
        public IActionResult Register() => View();

        // Register (POST)：处理表单提交，保存新用户数据
        [HttpPost]
        public IActionResult Register(User user)
        {
            if (ModelState.IsValid)
            {
                _context.Users.Add(user);
                _context.SaveChanges();
                return RedirectToAction("Login");
            }
            return View(user);
        }

        // Login (GET)：返回登录视图
        [HttpGet]
        public IActionResult Login() => View();

        // Login (POST)：处理登录请求，验证用户信息，设置Session
        [HttpPost]
        public IActionResult Login(User loginUser)
        {
            var user = _context.Users.FirstOrDefault(u => u.Username == loginUser.Username && u.Password == loginUser.Password);
            if (user != null)
            {
                HttpContext.Session.SetString("Username", user.Username);
                HttpContext.Session.SetString("Role", user.Role);
                HttpContext.Session.SetInt32("UserId", user.Id);

                return RedirectToAction("Index", "Home");
            }

            ViewBag.Error = "用户名或密码错误";
            return View(loginUser);
        }

        // Logout (GET)：清除用户会话信息，注销用户
        [HttpGet]
        public IActionResult Logout()
        {
            HttpContext.Session.Clear();
            return RedirectToAction("Login");
        }

        // MyScores (GET)：显示当前学生用户自己的成绩
        [HttpGet]
        public IActionResult MyScores()
        {
            var userId = HttpContext.Session.GetInt32("UserId") ?? 0;
            if (userId == 0)
            {
                return RedirectToAction("Login", "Account");
            }

            // 通过 UserId 关联 Student（此处以 UserId 作为 Student 的对应标识）
            var student = _context.Students.FirstOrDefault(s => s.Id == userId);
            if (student == null)
            {
                return View(new List<Score>());
            }

            var scores = _context.Scores
                .Where(sc => sc.StudentId == student.Id)
                .Include(sc => sc.Course)
                .ToList();

            ViewBag.StudentName = student.Name;
            return View(scores);
        }
    }
}
