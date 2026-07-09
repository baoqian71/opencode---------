using Microsoft.AspNetCore.Mvc;
using StudentManager.Controllers;
using StudentManager.Models;
using StudentManager.Tests.Utilities;

namespace StudentManager.Tests.Controllers;

public class UsersControllerTests
{
    [Fact]
    public void Index_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new UsersController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Index();

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public void Index_Admin返回用户列表()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new UsersController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Index();

        var viewResult = Assert.IsType<ViewResult>(result);
        var users = Assert.IsType<List<User>>(viewResult.Model);
        Assert.Equal(3, users.Count);
    }

    [Fact]
    public void Edit_GET_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new UsersController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Edit(1);

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public void Edit_GET_Admin返回用户视图()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new UsersController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Edit(1);

        var viewResult = Assert.IsType<ViewResult>(result);
        var user = Assert.IsType<User>(viewResult.Model);
        Assert.Equal("admin", user.Username);
    }

    [Fact]
    public void Edit_GET_不存在返回404()
    {
        using var context = TestHelper.CreateDbContext();
        var controller = new UsersController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.Edit(999);

        Assert.IsType<NotFoundResult>(result);
    }

    [Fact]
    public void Edit_POST_Admin更新用户并重定向()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        // 分离已跟踪的实体，避免 EF Core Update 时跟踪冲突
        TestHelper.DetachEntity<User>(context, 2);

        var controller = new UsersController(context);
        TestHelper.SetupAdminContext(controller);

        var user = new User { Id = 2, Username = "student1_updated", Password = "newpass", Role = "User" };

        var result = controller.Edit(user);

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Index", redirectResult.ActionName);
        Assert.Equal("student1_updated", context.Users.Find(2)!.Username);
    }

    [Fact]
    public void DeleteConfirmed_删除用户并重定向()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new UsersController(context);
        TestHelper.SetupAdminContext(controller);

        var result = controller.DeleteConfirmed(3);

        var redirectResult = Assert.IsType<RedirectToActionResult>(result);
        Assert.Equal("Index", redirectResult.ActionName);
        Assert.Equal(2, context.Users.Count());
        Assert.Null(context.Users.Find(3));
    }

    [Fact]
    public void Delete_GET_非Admin返回401()
    {
        using var context = TestHelper.CreateDbContext();
        TestHelper.SeedData(context);
        var controller = new UsersController(context);
        TestHelper.SetupUserContext(controller);

        var result = controller.Delete(1);

        Assert.IsType<UnauthorizedResult>(result);
    }
}
