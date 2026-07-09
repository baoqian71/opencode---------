# 部署到 Windows + MySQL + VSCode 说明

本说明用于在学生管理系统（StudentManager）本机（Linux 开发机）已改为 MySQL 版后，
迁移到 Windows 机器用 VSCode 运行。

## 一、开发机已完成的修改（项目当前即为 MySQL 版）
- StudentManager.csproj：引用 Pomelo.EntityFrameworkCore.MySql (9.0.0)
- appsettings.json 连接串：
  Server=localhost;Port=3306;Database=StudentManagerDb;User=root;Password=user123;
- Program.cs：UseMySql + 显式版本 new MySqlServerVersion(new Version(8,0,36))
  （若你的 MySQL 不是 8.0.36，请按实际版本改这一行，如 8.4.0 / 5.7.44）
- Migrations 已重建为 MySQL 版（InitialCreate）

## 二、Windows 端准备
1. 安装 .NET 8 SDK：https://dotnet.microsoft.com/download/dotnet/8.0
2. 确认 MySQL Server 已安装并运行（端口 3306 在监听）。
   查看 MySQL 版本（cmd/PowerShell）：
     mysql -u root -p -e "SELECT VERSION();"
   若提示 mysql 不是命令，需把 MySQL 的 bin 目录加入 PATH，或用 MySQL Workbench。
3. 安装 VSCode + 扩展 "C# Dev Kit"（Microsoft 官方）。

## 三、查看 MySQL 用户权限（确认 root 是否能建库建表）
在 Windows 的 MySQL 客户端执行：
  SHOW GRANTS FOR 'root'@'localhost';
若结果含 `ALL PRIVILEGES` 或 `CREATE, CREATE TABLE` 等，即可自动建库建表。
若 root 无建库权限，请先手动建库：
  CREATE DATABASE StudentManagerDb CHARACTER SET utf8mb4;

## 四、在 VSCode 中运行
1. 解压 StudentManager.tar.gz 到如 D:\StudentManager\
2. VSCode 打开该文件夹
3. 打开终端（Ctrl + `），执行：
   dotnet tool install --global dotnet-ef
   dotnet ef database update
   dotnet run
   （迁移 InitialCreate 已随项目提供，无需再 add；若更换库名需重新 add）
4. 浏览器打开 http://localhost:5291
5. 默认管理员自动创建：admin / 123456 （见 Program.cs 种子代码）

## 五、常见问题
- 连接失败 "Unable to connect"：检查 MySQL 服务是否启动、端口/账号密码是否正确。
- 版本不匹配报错：改 Program.cs 中 MySqlServerVersion 的实际版本号。
- 权限不足：按第三节手动建库，或给 root 授权。

## 六、注意
- 明文密码为教学演示用途，生产环境应做哈希处理。
