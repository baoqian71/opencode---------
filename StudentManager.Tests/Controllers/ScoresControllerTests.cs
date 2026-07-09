using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudentManager.Controllers;
using StudentManager.Models;
using StudentManager.Tests.Utilities;

namespace StudentManager.Tests.Controllers;

public class ScoresControllerTests
{
    [Fact]
    public void Index_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new ScoresController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Index();

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public void Index_Admin返回成绩列表含关联数据()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new ScoresController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Index();

        var viewResult = Assert.IsType<ViewResult>(result);
        var scores = Assert.IsType<List<Score>>(viewResult.Model);
        Assert.Equal(3, scores.Count);

        // 验证 Include 加载了关联数据
        Assert.NotNull(scores[0].Student);
        Assert.NotNull(scores[0].Course);
    }

    [Fact]
    public void Create_GET_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new ScoresController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Create();

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public void Create_GET_Admin返回视图含学生和课程列表()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new ScoresController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Create();

        var viewResult = Assert.IsType<ViewResult>(result);
        Assert.NotNull(controller.ViewBag.Students);
        Assert.NotNull(controller.ViewBag.Courses);
    }

    [Fact]
    public void Create_POST_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new ScoresController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Create(new Score());

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public void Create_POST_Admin有效数据_添加成绩并重定向()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new ScoresController(context);
        TestHelper.SetupAdminContext(controller);

        var score = new Score { StudentId = 3, CourseId = 3, Grade = 95 };

        var result = controller.Create(score);

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Index", redirectResult.ActionName);
        Assert.Equal(4, context.Scores.Count());

        // 验证 ScoreDate 由后台自动赋值
        var saved = context.Scores.OrderBy(s => s.Id).Last();
        Assert.Equal(95, saved.Grade);
        Assert.NotEqual(default, saved.ScoreDate);
        Assert.True((DateTime.Now - saved.ScoreDate).TotalSeconds < 60); // 近1分钟内
    }

    [Fact]
    public void Create_POST_无效数据_返回视图含错误()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new ScoresController(context);
        TestHelper.SetupAdminContext(controller);

        // Grade 超出范围，但 Model 没有 [Range] 验证，所以构造模型无效
        // 这里手动加一个 ModelState 错误来模拟
        controller.ModelState.AddModelError("Grade", "成绩必须在0-100之间");

        var score = new Score { StudentId = 1, CourseId = 1, Grade = -1 };

        var result = controller.Create(score);

        var viewResult = Assert.IsType<ViewResult>(result);
        Assert.NotNull(controller.ViewBag.Error);
    }

    [Fact]
    public void Edit_GET_Admin返回编辑视图()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new ScoresController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Edit(1);

        var viewResult = Assert.IsType<ViewResult>(result);
        var score = Assert.IsType<Score>(viewResult.Model);
        Assert.Equal(85, score.Grade);
        Assert.NotNull(controller.ViewBag.Students);
        Assert.NotNull(controller.ViewBag.Courses);
    }

    [Fact]
    public void Edit_GET_不存在返回404()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new ScoresController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Edit(999);

        Assert.IsType<NotFoundResult>(result);
    }

    [Fact]
    public void Edit_POST_Admin更新成绩并重定向()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new ScoresController(context);
        TestHelper.SetupAdminContext(controller);

        var score = new Score { Id = 1, StudentId = 1, CourseId = 1, Grade = 90 };

        var result = controller.Edit(score);

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Index", redirectResult.ActionName);
        Assert.Equal(90, context.Scores.Find(1)!.Grade);
        // ScoreDate 保持不变
        Assert.Equal(new DateTime(2026, 1, 10), context.Scores.Find(1)!.ScoreDate);
    }

    [Fact]
    public void Edit_GET_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new ScoresController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Edit(1);

        Assert.IsType<UnauthorizedResult>(result);
    }
}
