// 引入数据访问层（用于操作数据库）
using StudentManager.Data;

// 引入 Entity Framework Core 的核心功能（比如 UseMySql）
using Microsoft.EntityFrameworkCore;

// 引入 System 命名空间（Version 类）
using System;

// 引入 Pomelo 的 MySQL EF Core 提供程序
using Pomelo.EntityFrameworkCore.MySql.Infrastructure;

// 引入模型（比如 User 表）
using StudentManager.Models;

// 创建应用程序构建器，准备构建 Web 应用
var builder = WebApplication.CreateBuilder(args);

// ========== 服务注册部分 ==========

// 注册数据库上下文（DbContext），配置使用 MySQL 数据库
// 显式指定 MySQL 版本，避免在无法连接数据库的设计时探测（请根据实际 MySQL 版本修改，如 MySQL 8.0.36 / 8.4.0）
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseMySql(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        new MySqlServerVersion(new Version(8, 0, 36))
    )
);

// 注册 MVC 控制器和视图支持
builder.Services.AddControllersWithViews();

// 注册分布式内存缓存（Session 需要依赖缓存）
builder.Services.AddDistributedMemoryCache();

// 注册 Session 服务（用户登录状态管理等）
builder.Services.AddSession();

// ========== 构建应用程序对象 ==========
var app = builder.Build();

// ========== 开发环境下添加默认管理员账户 ==========
// 用作用域 (Scope) 获取服务，操作数据库
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

    // 检查数据库中是否已经存在名为 admin 的用户
    if (!db.Users.Any(u => u.Username == "admin"))
    {
        // 如果不存在，添加一个默认的管理员用户
        db.Users.Add(new User
        {
            Username = "admin",
            Password = "123456", // 注意：仅限开发测试环境使用明文密码，生产环境应加密！
            Role = "Admin"
        });
        db.SaveChanges(); // 保存到数据库
    }
}

// ========== 配置中间件（处理请求的流水线） ==========

// 如果不是开发环境（比如生产环境），使用统一的异常处理页面
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
}

// 启用静态文件中间件（比如CSS、JS、图片等不需要经过控制器处理的文件）
app.UseStaticFiles();

// 启用路由中间件（匹配 URL 到对应控制器和动作方法）
app.UseRouting();

// 启用 Session 中间件（让应用支持用户会话）
app.UseSession();

// 启用授权中间件（控制用户访问权限，比如[Authorize]特性）
app.UseAuthorization();

// 配置默认路由规则
// 如果访问URL中没有指定控制器或动作，则默认跳转到 Home 控制器的 Index 动作
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}"
);

// 启动应用程序，开始监听请求
app.Run();
