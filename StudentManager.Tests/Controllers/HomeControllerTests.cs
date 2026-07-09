using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;
using StudentManager.Controllers;
using StudentManager.Models;
using StudentManager.Tests.Utilities;

namespace StudentManager.Tests.Controllers;

public class HomeControllerTests
{
    private readonly HomeController _controller;

    public HomeControllerTests()
    {
        var mockLogger = new Mock<ILogger<HomeController>>();
        _controller = new HomeController(mockLogger.Object);
        // Error 方法需要 HttpContext.TraceIdentifier
        TestHelper.SetupControllerContext(_controller);
    }

    [Fact]
    public void Index_返回默认视图()
    {
        var result = _controller.Index();

        var viewResult = Assert.IsType<ViewResult>(result);
        Assert.Null(viewResult.ViewName);
    }

    [Fact]
    public void Privacy_返回默认视图()
    {
        var result = _controller.Privacy();

        var viewResult = Assert.IsType<ViewResult>(result);
        Assert.Null(viewResult.ViewName);
    }

    [Fact]
    public void Error_返回ErrorViewModel()
    {
        var result = _controller.Error();

        var viewResult = Assert.IsType<ViewResult>(result);
        Assert.Null(viewResult.ViewName);
        Assert.IsType<ErrorViewModel>(viewResult.Model);
    }
}
