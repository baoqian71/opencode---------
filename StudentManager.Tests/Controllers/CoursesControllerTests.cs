using Microsoft.AspNetCore.Mvc;
using StudentManager.Controllers;
using StudentManager.Models;
using StudentManager.Tests.Utilities;

namespace StudentManager.Tests.Controllers;

public class CoursesControllerTests
{
    [Fact]
    public void Index_返回课程列表()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new CoursesController(context);
        TestHelper.SetupControllerContext(controller);

        var result = controller.Index();

        var viewResult = Assert.IsType<ViewResult>(result);
        var courses = Assert.IsType<List<Course>>(viewResult.Model);
        Assert.Equal(3, courses.Count);
    }

    [Fact]
    public void Create_GET_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new CoursesController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Create();

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public void Create_GET_Admin返回视图()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new CoursesController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Create();

        Assert.IsType<ViewResult>(result);
    }

    [Fact]
    public void Create_POST_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new CoursesController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Create(new Course());

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public void Create_POST_Admin有效数据_添加课程并重定向()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new CoursesController(context);
        TestHelper.SetupAdminContext(controller);

        var course = new Course { CourseName = "编译原理", Teacher = "张教授" };

        var result = controller.Create(course);

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Index", redirectResult.ActionName);
        Assert.Equal(1, context.Courses.Count());
    }

    [Fact]
    public void Edit_GET_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new CoursesController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Edit(1);

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public void Edit_GET_Admin返回课程视图()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new CoursesController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Edit(1);

        var viewResult = Assert.IsType<ViewResult>(result);
        var course = Assert.IsType<Course>(viewResult.Model);
        Assert.Equal("高等数学", course.CourseName);
    }

    [Fact]
    public void Edit_GET_不存在返回404()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new CoursesController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Edit(999);

        Assert.IsType<NotFoundResult>(result);
    }

    [Fact]
    public void Edit_POST_Admin更新课程并重定向()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        // 分离已跟踪的实体，避免 EF Core Update 时跟踪冲突
        TestHelper.DetachEntity<Course>(context, 1);

        var controller = new CoursesController(context);
        TestHelper.SetupAdminContext(controller);

        var course = new Course { Id = 1, CourseName = "高等数学(上)", Teacher = "陈教授" };

        var result = controller.Edit(course);

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Index", redirectResult.ActionName);
        Assert.Equal("高等数学(上)", context.Courses.Find(1)!.CourseName);
    }

    [Fact]
    public void DeleteConfirmed_删除课程并重定向()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new CoursesController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.DeleteConfirmed(1);

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Index", redirectResult.ActionName);
        Assert.Equal(2, context.Courses.Count());
    }
}
