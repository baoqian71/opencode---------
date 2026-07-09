using Microsoft.AspNetCore.Mvc;
using StudentManager.Controllers;
using StudentManager.Models;
using StudentManager.Tests.Utilities;

namespace StudentManager.Tests.Controllers;

public class StudentsControllerTests
{
    [Fact]
    public void Index_返回学生列表()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new StudentsController(context);
        TestHelper.SetupControllerContext(controller);

        var result = controller.Index(string.Empty);

        var viewResult = Assert.IsType<ViewResult>(result);
        var students = Assert.IsType<List<Student>>(viewResult.Model);
        Assert.Equal(3, students.Count);
    }

    [Fact]
    public void Index_按姓名搜索返回过滤结果()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new StudentsController(context);
        TestHelper.SetupControllerContext(controller);

        var result = controller.Index("张三");

        var viewResult = Assert.IsType<ViewResult>(result);
        var students = Assert.IsType<List<Student>>(viewResult.Model);
        var single = Assert.Single(students);
        Assert.Equal("张三", single.Name);
    }

    [Fact]
    public void Index_按学号搜索返回过滤结果()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new StudentsController(context);
        TestHelper.SetupControllerContext(controller);

        var result = controller.Index("2024002");

        var viewResult = Assert.IsType<ViewResult>(result);
        var students = Assert.IsType<List<Student>>(viewResult.Model);
        var single = Assert.Single(students);
        Assert.Equal("李四", single.Name);
    }

    [Fact]
    public void Create_GET_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new StudentsController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Create();

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public void Create_GET_Admin返回视图()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new StudentsController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Create();

        var viewResult = Assert.IsType<ViewResult>(result);
        Assert.Null(viewResult.ViewName);
    }

    [Fact]
    public void Create_POST_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new StudentsController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Create(new Student());

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public void Create_POST_Admin有效数据_添加学生并重定向()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new StudentsController(context);
        TestHelper.SetupAdminContext(controller);

        var student = new Student { StudentNo = "2024004", Name = "赵六", Class = "网络工程一班" };

        var result = controller.Create(student);

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Index", redirectResult.ActionName);
        Assert.Equal(1, context.Students.Count());
        Assert.Equal("赵六", context.Students.First().Name);
    }

    [Fact]
    public void Edit_GET_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new StudentsController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Edit(1);

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public void Edit_GET_Admin返回学生视图()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new StudentsController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Edit(1);

        var viewResult = Assert.IsType<ViewResult>(result);
        var student = Assert.IsType<Student>(viewResult.Model);
        Assert.Equal("张三", student.Name);
    }

    [Fact]
    public void Edit_GET_不存在返回404()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new StudentsController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Edit(999);

        Assert.IsType<NotFoundResult>(result);
    }

    [Fact]
    public void Edit_POST_Admin更新学生并重定向()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        // 分离已跟踪的实体，避免 EF Core Update 时跟踪冲突
        TestHelper.DetachEntity<Student>(context, 1);

        var controller = new StudentsController(context);
        TestHelper.SetupAdminContext(controller);

        var student = new Student { Id = 1, StudentNo = "2024001", Name = "张三(改)", Class = "计算机一班" };

        var result = controller.Edit(student);

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Index", redirectResult.ActionName);
        Assert.Equal("张三(改)", context.Students.Find(1)!.Name);
    }

    [Fact]
    public void Delete_GET_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new StudentsController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Delete(1);

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public void Delete_GET_Admin返回确认视图()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new StudentsController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Delete(1);

        var viewResult = Assert.IsType<ViewResult>(result);
        var student = Assert.IsType<Student>(viewResult.Model);
        Assert.Equal("张三", student.Name);
    }

    [Fact]
    public void DeleteConfirmed_删除学生并重定向()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new StudentsController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.DeleteConfirmed(1);

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Index", redirectResult.ActionName);
        Assert.Equal(2, context.Students.Count());
        Assert.Null(context.Students.Find(1));
    }
}
