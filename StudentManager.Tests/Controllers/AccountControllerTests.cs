using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using StudentManager.Controllers;
using StudentManager.Models;
using StudentManager.Tests.Utilities;

namespace StudentManager.Tests.Controllers;

public class AccountControllerTests
{
    /// <summary>
    /// Register GET 应返回注册视图
    /// </summary>
    [Fact]
    public void Register_GET_返回注册视图()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new AccountController(context);
        TestHelper.SetupControllerContext(controller);

        var result = controller.Register();

        var viewResult = Assert.IsType<ViewResult>(result);
        Assert.Null(viewResult.ViewName);
    }

    /// <summary>
    /// Register POST 有效数据应创建用户并重定向到登录页
    /// </summary>
    [Fact]
    public void Register_POST_有效数据_重定向到登录()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new AccountController(context);
        TestHelper.SetupControllerContext(controller);

        var user = new User { Username = "newuser", Password = "pass123", Role = "User" };

        var result = controller.Register(user);

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Login", redirectResult.ActionName);
        Assert.Equal(1, context.Users.Count());
    }

    /// <summary>
    /// Register POST 无效模型应返回带模型的视图
    /// </summary>
    [Fact]
    public void Register_POST_无效模型_返回视图带模型()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new AccountController(context);
        TestHelper.SetupControllerContext(controller);
        controller.ModelState.AddModelError("Username", "必填");

        var user = new User { Password = "pass123", Role = "User" };

        var result = controller.Register(user);

        var viewResult = Assert.IsType<ViewResult>(result);
        Assert.Equal(user, viewResult.Model);
    }

    /// <summary>
    /// Login GET 应返回登录视图
    /// </summary>
    [Fact]
    public void Login_GET_返回登录视图()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new AccountController(context);
        TestHelper.SetupControllerContext(controller);

        var result = controller.Login();

        var viewResult = Assert.IsType<ViewResult>(result);
        Assert.Null(viewResult.ViewName);
    }

    /// <summary>
    /// Login POST 有效凭据应设置 Session 并重定向到首页
    /// </summary>
    [Fact]
    public void Login_POST_有效凭据_设置Session并重定向()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new AccountController(context);
        var session = new MockHttpSession();
        TestHelper.SetupControllerContext(controller, session);

        var loginUser = new User { Username = "admin", Password = "123456" };

        var result = controller.Login(loginUser);

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Index", redirectResult.ActionName);
        Assert.Equal("Home", redirectResult.ControllerName);

        Assert.Equal("admin", session.GetString("Username"));
        Assert.Equal("Admin", session.GetString("Role"));
        Assert.Equal(1, session.GetInt32("UserId"));
    }

    /// <summary>
    /// Login POST 无效凭据应返回视图并带错误信息
    /// </summary>
    [Fact]
    public void Login_POST_无效凭据_返回视图带错误()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new AccountController(context);
        TestHelper.SetupControllerContext(controller);

        var loginUser = new User { Username = "wrong", Password = "wrong" };

        var result = controller.Login(loginUser);

        var viewResult = Assert.IsType<ViewResult>(result);
        Assert.Equal("用户名或密码错误", controller.ViewBag.Error);
    }

    /// <summary>
    /// Logout 应清除 Session 并重定向到登录页
    /// </summary>
    [Fact]
    public void Logout_清除Session并重定向到登录()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new AccountController(context);
        var session = new MockHttpSession();
        session.SetString("Username", "admin");
        TestHelper.SetupControllerContext(controller, session);

        var result = controller.Logout();

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Login", redirectResult.ActionName);
        Assert.Empty(session.Keys); // Session 已被 Clear
    }

    /// <summary>
    /// MyScores 未登录应重定向到登录页
    /// </summary>
    [Fact]
    public void MyScores_未登录_重定向到登录()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new AccountController(context);
        TestHelper.SetupControllerContext(controller); // 无 Session

        var result = controller.MyScores();

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Login", redirectResult.ActionName);
    }

    /// <summary>
    /// MyScores 已登录且关联学生存在时应返回成绩列表
    /// </summary>
    [Fact]
    public void MyScores_已登录有学生_返回成绩()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new AccountController(context);
        // UserId=2 对应 student1，Id=2 是李四，有 1 条成绩（英语 78分）
        TestHelper.SetupUserContext(controller, userId: 2);

        var result = controller.MyScores();

        var viewResult = Assert.IsType<ViewResult>(result);
        var scores = Assert.IsType<List<Score>>(viewResult.Model);
        var singleScore = Assert.Single(scores);
        Assert.Equal(78, singleScore.Grade);
    }

    /// <summary>
    /// MyScores 已登录但无关联学生应返回空列表
    /// </summary>
    [Fact]
    public void MyScores_已登录无关联学生_返回空列表()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new AccountController(context);
        // UserId=3 在 Students 表中没有对应 Id=3 的学生（Id=3 是王五，但映射按 UserId 找 Student.Id）
        TestHelper.SetupUserContext(controller, userId: 99);
        // 注意：控制器用 UserId 直接去 Students 表查 Id 匹配，99 不存在
        var result = controller.MyScores();

        var viewResult = Assert.IsType<ViewResult>(result);
        var scores = Assert.IsType<List<Score>>(viewResult.Model);
        Assert.Empty(scores);
    }
}
