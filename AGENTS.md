# AGENTS.md

ASP.NET Core MVC 学生管理系统 (StudentManager), .NET 8 + EF Core 9 + MySQL (Pomelo).

## Commands
- Build: `dotnet build`
- Run: `dotnet run` (dev server: http://localhost:5291, see `Properties/launchSettings.json`)
- DB migrate: `dotnet ef database update` (migrations already generated for MySQL)
- Test: `dotnet test` (xUnit, 56 tests in `StudentManager.Tests/`)
- No lint or formatter configured.

## Architecture (verified)
- Entry point: `Program.cs` — registers `ApplicationDbContext` via `UseMySql`, MVC, Session, `UseAuthorization`, default route `{controller=Home}/{action=Index}/{id?}`.
- `Controllers/`: `Home` (static), `Account` (register/login/logout/MyScores), `Students` (CRUD, admin), `Courses` (CRUD, admin), `Scores` (admin 录入/编辑；学生看自己的), `Users` (admin user mgmt).
- `Models/`: `User`, `Student`, `Course`, `Score`, `ErrorViewModel`. `Data/ApplicationDbContext.cs` defines 4 `DbSet`s.
- `Views/` Razor + `wwwroot/lib` (Bootstrap). Front-end is Chinese ("学生管理系统").

## Critical gotchas
- **DB = MySQL** (`appsettings.json`: `Server=localhost;Port=3306;Database=StudentManagerDb;User=root;Password=user123;`). Tables are NOT auto-created; run `dotnet ef database update` to build them.
- **MySQL 版本写死在 Program.cs**：`new MySqlServerVersion(new Version(8, 0, 46))`。若 MySQL 实际版本不同会报错，需改此版本号。
- **Passwords stored in plaintext** in `User.Password`. Do not assume hashing exists.
- **Auth is Session-based**, role checked via `HttpContext.Session.GetString("Role") == "Admin"` (helper `IsAdmin()` in controllers). Default admin seeding in `Program.cs` creates `admin/123456` if absent.
- `Score.ScoreDate` 非可空、不在表单提交；`ScoresController` 的 Create/Edit POST 用 `ModelState.Remove(nameof(Score.ScoreDate))` 清除其绑定错误并由后台 `DateTime.Now` 赋值。
- `bin/` and `obj/` are build artifacts; do not edit.

## Conventions
- Code and comments are in Chinese; keep new comments consistent.
- Default admin role string is literally `"Admin"`; user role `"User"`.

## 测试项目（StudentManager.Tests）
- xUnit + Moq + EF Core InMemory，共 56 个测试用例，覆盖所有 Controller。
- `TestHelper.cs` 提供 InMemory 数据库创建、MockSession 管理、种子数据、实体分离等方法。
- 测试遵循「行为测试」原则：断言返回值（View/Redirect/Unauthorized）而非实现细节。
- **测试原则**：
  1. **测试行为，不测实现** — 断言 Controller 返回正确的视图/重定向/状态码，不测内部数据如何拼装
  2. **新增功能必须追加测试** — 每个新 Action/Controller 必须有对应的测试方法
  3. **修改代码后确保已有测试通过** — `dotnet test` 0 失败后方可交付
  4. **不重写测试，只追加或修正** — 接口/行为不变时，测试代码不需要改

## 与 Agent 协作的行为规范（用户明确要求）
- 全程使用中文回复。
- 实事求是：不得编造事实。遇到未知路径、不确定名称、或不清楚的实现细节时，必须向用户提问确认，不可臆测代填。
- 涉及编程时，写完完整代码后必须进行调试测试：尽量多测试几遍，保证编译通过（`dotnet build` 0 错误），并确保项目功能达到计划预期后再交付。
- **修改代码时必须保证 `dotnet test` 全部通过**，新增功能必须追加对应测试。
