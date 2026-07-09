# 部署到 Windows + SQL Server 说明

本说明用于将学生管理系统（StudentManager）从 Linux 开发机迁移到已有 SQL Server 的 Windows 机器。
项目原始使用 SQLite，部署到 SQL Server 需按以下步骤替换数据库提供程序与连接字符串。

## 一、在开发机（Linux）已完成的打包
- 已打包为：`/tmp/opencode/StudentManager.tar.gz`
- 已排除：bin/、obj/、.vs/、*.db（生成物与本地数据库）
- Windows 10/11 自带 tar，可直接解压；或用 7-Zip 等工具。

## 二、在 Windows 机器上操作
1. 解压 `StudentManager.tar.gz` 到目标目录（如 `D:\StudentManager\`）。
2. 安装 .NET 8 SDK（若仅运行可装 .NET 8 Runtime）：
   https://dotnet.microsoft.com/download/dotnet/8.0
3. 替换数据库提供程序：
   - 用本目录 `部署参考/StudentManager.SQLServer.csproj` 的内容覆盖 `StudentManager.csproj`
     （仅把 `Microsoft.EntityFrameworkCore.Sqlite` 改为 `Microsoft.EntityFrameworkCore.SqlServer`）。
4. 修改连接字符串 `appsettings.json` 的 `ConnectionStrings:DefaultConnection` 为实际 SQL Server：
   - 本机默认实例示例：
     "Server=.;Database=StudentManagerDb;Trusted_Connection=True;TrustServerCertificate=True;"
   - 命名实例示例：
     "Server=.\\SQLEXPRESS;Database=StudentManagerDb;Trusted_Connection=True;TrustServerCertificate=True;"
   - 远程/SQL 账号验证示例：
     "Server=192.168.1.10;Database=StudentManagerDb;User Id=sa;Password=你的密码;TrustServerCertificate=True;"
   （可直接以 `部署参考/appsettings.SQLServer.json` 为模板，按实际填。）
5. 重新生成迁移（SQLite 与 SQL Server 迁移不通用，必须重建）：
   以管理员身份打开终端，进入项目目录执行：
   dotnet tool install --global dotnet-ef
   dotnet ef migrations remove
   dotnet ef migrations add InitialCreate
   dotnet ef database update
6. 运行：
   dotnet run
   浏览器打开 http://localhost:5291
7. 默认管理员账号会在首次启动时自动创建：
   用户名 admin / 密码 123456 （Role=Admin，见 Program.cs 种子代码）

## 三、注意事项
- 明文密码为教学演示用途，生产环境应对密码做哈希处理。
- 若目标 SQL Server 不允许自动建库，请先手动创建空库 StudentManagerDb，再执行迁移。
- Program.cs 中已启用默认管理员种子，数据库已存在 admin 时会跳过，不会重复插入。
