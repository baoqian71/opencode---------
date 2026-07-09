using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Http;
using StudentManager.Data;
using StudentManager.Models;

namespace StudentManager.Tests.Utilities;

/// <summary>
/// 测试辅助类：提供 InMemory 数据库和模拟 Session 的通用方法
/// </summary>
public static class TestHelper
{
    /// <summary>
    /// 创建使用唯一名称的 InMemory 数据库上下文（每次调用独立，避免测试间数据污染）
    /// </summary>
    public static ApplicationDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new ApplicationDbContext(options);
    }

    /// <summary>
    /// 为 Controller 设置带有 MockSession 的 ControllerContext
    /// </summary>
    public static void SetupControllerContext(Controller controller, MockHttpSession? session = null)
    {
        session ??= new MockHttpSession();
        var httpContext = new DefaultHttpContext { Session = session };
        controller.ControllerContext = new ControllerContext
        {
            HttpContext = httpContext
        };
    }

    /// <summary>
    /// 为 Controller 设置管理员身份（Admin 角色）
    /// </summary>
    public static void SetupAdminContext(Controller controller)
    {
        var session = new MockHttpSession();
        session.SetString("Username", "admin");
        session.SetString("Role", "Admin");
        session.SetInt32("UserId", 1);
        SetupControllerContext(controller, session);
    }

    /// <summary>
    /// 为 Controller 设置普通用户身份（User 角色）
    /// </summary>
    public static void SetupUserContext(Controller controller, int userId = 2)
    {
        var session = new MockHttpSession();
        session.SetString("Username", "student1");
        session.SetString("Role", "User");
        session.SetInt32("UserId", userId);
        SetupControllerContext(controller, session);
    }

    /// <summary>
    /// 播种测试数据
    /// </summary>
    public static void SeedData(ApplicationDbContext context)
    {
        // 用户
        context.Users.AddRange(
            new User { Id = 1, Username = "admin", Password = "123456", Role = "Admin" },
            new User { Id = 2, Username = "student1", Password = "123456", Role = "User" },
            new User { Id = 3, Username = "student2", Password = "123456", Role = "User" }
        );

        // 学生
        context.Students.AddRange(
            new Student { Id = 1, StudentNo = "2024001", Name = "张三", Class = "计算机一班" },
            new Student { Id = 2, StudentNo = "2024002", Name = "李四", Class = "计算机一班" },
            new Student { Id = 3, StudentNo = "2024003", Name = "王五", Class = "软件工程二班" }
        );

        // 课程
        context.Courses.AddRange(
            new Course { Id = 1, CourseName = "高等数学", Teacher = "陈教授" },
            new Course { Id = 2, CourseName = "数据结构", Teacher = "刘教授" },
            new Course { Id = 3, CourseName = "操作系统", Teacher = "王教授" }
        );

        // 成绩
        context.Scores.AddRange(
            new Score { Id = 1, StudentId = 1, CourseId = 1, Grade = 85, ScoreDate = new DateTime(2026, 1, 10) },
            new Score { Id = 2, StudentId = 1, CourseId = 2, Grade = 92, ScoreDate = new DateTime(2026, 1, 10) },
            new Score { Id = 3, StudentId = 2, CourseId = 1, Grade = 78, ScoreDate = new DateTime(2026, 1, 10) }
        );

        context.SaveChanges();
    }

    /// <summary>
    /// 将指定 Id 的实体从 EF Core 跟踪中分离，避免 Update 时的跟踪冲突
    /// </summary>
    public static void DetachEntity<T>(ApplicationDbContext context, object id) where T : class
    {
        var tracked = context.Set<T>().Local.FirstOrDefault(e =>
        {
            var entry = context.Entry(e);
            return entry.Property("Id").CurrentValue?.Equals(id) == true;
        });
        if (tracked != null)
            context.Entry(tracked).State = EntityState.Detached;
    }
}

/// <summary>
/// 模拟 ISession 的实现，用于 Controller 测试
/// </summary>
public class MockHttpSession : ISession
{
    private readonly Dictionary<string, byte[]> _store = new();

    public string Id => Guid.NewGuid().ToString();
    public bool IsAvailable => true;
    public IEnumerable<string> Keys => _store.Keys;

    public void Clear() => _store.Clear();
    public Task CommitAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
    public Task LoadAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
    public void Remove(string key) => _store.Remove(key);
    public void Set(string key, byte[] value) => _store[key] = value;
    public bool TryGetValue(string key, out byte[] value)
    {
        var result = _store.TryGetValue(key, out var val);
        value = val!;
        return result;
    }

    // 扩展方法需要的 SetString / GetString / SetInt32 / GetInt32 由 ASP.NET Core 扩展方法自动使用 Set/TryGetValue
}
