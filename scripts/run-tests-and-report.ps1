param(
    [string]$ReportPath = "",
    [switch]$SkipTests
)

function Write-Info  { Write-Host "[INFO] $($args[0])" -ForegroundColor Cyan }
function Write-Ok   { Write-Host "[OK]   $($args[0])" -ForegroundColor Green }
function Write-Err  { Write-Host "[ERROR] $($args[0])" -ForegroundColor Red }

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
if (-not $ReportPath) { $ReportPath = Join-Path $ProjectRoot "test-report.html" }
Write-Info ("Project: " + $ProjectRoot)

# ====== Run tests ======
if (-not $SkipTests) {
    Write-Info "Running dotnet test ..."
    $out = dotnet test --logger "trx;LogFileName=test-results.trx" 2>&1
    $out | ForEach-Object { "$_" }
    $TrxFile = $null
    foreach ($line in $out) {
        $s = "$line"
        if ($s -match '\S+\.trx') {
            $parts = $s -split '\s+'
            foreach ($p in $parts) {
                if ($p -match '^\S+\.trx$') { $TrxFile = $p; break }
            }
        }
        if ($TrxFile) { break }
    }
    if (-not $TrxFile -or -not (Test-Path $TrxFile)) {
        $d = Join-Path $ProjectRoot "StudentManager.Tests\TestResults"
        if (Test-Path $d) { $f = Get-ChildItem $d -Filter "*.trx" | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if ($f) { $TrxFile = $f.FullName } }
    }
} else {
    Write-Info "Skip tests, use existing TRX"
    $d = Join-Path $ProjectRoot "StudentManager.Tests\TestResults"
    if (Test-Path $d) { $f = Get-ChildItem $d -Filter "*.trx" | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if ($f) { $TrxFile = $f.FullName } }
}
if (-not $TrxFile -or -not (Test-Path $TrxFile)) { Write-Err "TRX file not found"; exit 1 }
Write-Info ("TRX: " + $TrxFile)

# ====== Parse TRX ======
$xdoc = [xml](Get-Content $TrxFile -Raw -Encoding UTF8)
$ns = @{e = "http://microsoft.com/schemas/VisualStudio/TeamTest/2010"}
$Times = Select-Xml -Xml $xdoc -XPath "//e:Times" -Namespace $ns | Select-Object -ExpandProperty Node
$startDt = if ($Times) { [DateTime]$Times.start } else { $null }
$finishDt = if ($Times) { [DateTime]$Times.finish } else { $null }
$resultNodes = Select-Xml -Xml $xdoc -XPath "//e:Results/e:UnitTestResult" -Namespace $ns | Select-Object -ExpandProperty Node

$tests = @(); $passed = 0; $failed = 0; $skipped = 0
foreach ($node in $resultNodes) {
    $name = $node.testName; $outcome = $node.outcome
    $cls = ""; $method = $name
    if ($name -match '^(.+)\.([^\.]+)$') { $cls = $matches[1]; $method = $matches[2] }
    $ctrl = "Other"
    if ($cls -match '\.(\w+Controller)Tests$') { $ctrl = $matches[1] }
    elseif ($cls -match '\.(\w+)Tests$') { $ctrl = $matches[1] }
    switch ($outcome) { "Passed" { $passed++ } "Failed" { $failed++ } default { $skipped++ } }
    $tests += [PSCustomObject]@{ Name=$name; Method=$method; Class=$cls; Controller=$ctrl; Outcome=$outcome; Duration=$node.duration }
}
$total = $tests.Count
Write-Ok ("Parsed: " + $total + " tests (pass:" + $passed + " fail:" + $failed + " skip:" + $skipped + ")")
if ($total -eq 0) { Write-Err "No test data"; exit 1 }

# ====== Stats ======
$dur = if ($startDt -and $finishDt) { $finishDt - $startDt } else { [TimeSpan]::Zero }
$durText = if ($dur.TotalSeconds -ge 1) { ("{0:N2} sec" -f $dur.TotalSeconds) } else { ("{0:N0} ms" -f $dur.TotalMilliseconds) }
$passRate = [math]::Round($passed / $total * 100, 1)
$failRate = [math]::Round($failed / $total * 100, 1)
$skipRate = [math]::Round($skipped / $total * 100, 1)
$statusColor = if ($failed -gt 0) { "#e74c3c" } else { "#27ae60" }
$statusText = if ($failed -gt 0) { "测试未通过" } else { "全部通过" }
$startStr = if ($startDt) { $startDt.ToString("yyyy-MM-dd HH:mm:ss") } else { "-" }
$nowStr = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm")

# ====== Group by controller ======
$grouped = $tests | Group-Object Controller
$ctrlHtml = ""
foreach ($g in $grouped) {
    $gp = 0; $gf = 0; $rows = ""
    foreach ($t in $g.Group) {
        if ($t.Outcome -eq "Passed") { $gp++ } elseif ($t.Outcome -eq "Failed") { $gf++ }
        $b = switch ($t.Outcome) {
            "Passed" { "<span class='b b-p'>通过</span>" }
            "Failed" { "<span class='b b-f'>失败</span>" }
            default  { "<span class='b b-s'>跳过</span>" }
        }
        $rows = $rows + "<tr><td class='tn'>" + $t.Method + "</td><td>" + $b + "</td><td class='d'>" + $t.Duration + "</td></tr>"
    }
    $gt = $g.Count; $gpr = [math]::Round($gp/$gt*100,0)
    $ctrlHtml = $ctrlHtml + @"
<div class='cg'>
  <div class='ch' onclick="this.parentElement.classList.toggle('cl')">
    <div class='ct'><span class='cn'>$($g.Name)</span><span class='cs'>$gp / $gt <span class='mb'><span class='mf' style='width:${gpr}%'></span></span></span></div>
    <span class='ti'>V</span>
  </div>
  <div class='cb'><table class='tt'><thead><tr><th style='width:60%'>测试用例</th><th style='width:20%'>结果</th><th style='width:20%'>耗时</th></tr></thead><tbody>$rows</tbody></table></div>
</div>
"@
}

$segPass = "<div class='sg sg-p' style='width:" + $passRate + "%'></div>"
$segFail = if ($failed -gt 0) { "<div class='sg sg-f' style='width:" + $failRate + "%'></div>" } else { "" }
$segSkip = if ($skipped -gt 0) { "<div class='sg sg-s' style='width:" + $skipRate + "%'></div>" } else { "" }

# ====== Build HTML ======
$sb = New-Object System.Text.StringBuilder

$sb.AppendLine('<!DOCTYPE html>') | Out-Null
$sb.AppendLine('<html lang="zh-CN">') | Out-Null
$sb.AppendLine('<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">') | Out-Null
$sb.AppendLine('<title>学生管理系统 · 综合测试报告</title>') | Out-Null
$sb.AppendLine('<style>') | Out-Null
$sb.AppendLine('*{margin:0;padding:0;box-sizing:border-box}') | Out-Null
$sb.AppendLine('body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#f0f2f5;color:#333;padding:20px}') | Out-Null
$sb.AppendLine('.c{max-width:1200px;margin:0 auto}') | Out-Null
$sb.AppendLine('.h{background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;padding:30px 35px;border-radius:12px;margin-bottom:24px}') | Out-Null
$sb.AppendLine('.h h1{font-size:26px;margin-bottom:4px}.h .sub{opacity:.85;font-size:14px}') | Out-Null
$sb.AppendLine('.h .ver{opacity:.7;font-size:12px;margin-top:4px}') | Out-Null

# Dashboard cards
$sb.AppendLine('.d{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:24px}') | Out-Null
$sb.AppendLine('.cd{background:#fff;border-radius:10px;padding:20px;text-align:center;box-shadow:0 1px 3px rgba(0,0,0,.08)}') | Out-Null
$sb.AppendLine('.cd .n{font-size:32px;font-weight:700;margin-bottom:4px}.cd .l{font-size:13px;color:#888}') | Out-Null
$sb.AppendLine('.t0 .n{color:#3498db}.t1 .n{color:#27ae60}.t2 .n{color:#e74c3c}.t3 .n{color:#f39c12}') | Out-Null

# Progress bar
$sb.AppendLine('.pw{background:#fff;border-radius:10px;padding:20px 25px;margin-bottom:24px;box-shadow:0 1px 3px rgba(0,0,0,.08)}') | Out-Null
$sb.AppendLine('.pb{height:24px;background:#ecf0f1;border-radius:12px;overflow:hidden;display:flex}') | Out-Null
$sb.AppendLine('.sg{height:100%;transition:width .6s ease}.sg-p{background:linear-gradient(90deg,#27ae60,#2ecc71)}') | Out-Null
$sb.AppendLine('.sg-f{background:linear-gradient(90deg,#e74c3c,#e67e22)}.sg-s{background:linear-gradient(90deg,#95a5a6,#bdc3c7)}') | Out-Null
$sb.AppendLine('.pl{display:flex;justify-content:space-between;margin-top:10px;font-size:13px;color:#666}') | Out-Null
$sb.AppendLine('.pl i{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:4px;vertical-align:middle}') | Out-Null

# Meta
$sb.AppendLine('.mi{display:flex;gap:24px;flex-wrap:wrap;margin-bottom:24px;padding:16px 20px;background:#fff;border-radius:10px;box-shadow:0 1px 3px rgba(0,0,0,.08);font-size:13px;color:#666}') | Out-Null
$sb.AppendLine('.mi .ml{font-weight:600;color:#333}') | Out-Null

# Section: general
$sb.AppendLine('.sec{background:#fff;border-radius:12px;padding:24px 28px;margin-bottom:20px;box-shadow:0 2px 8px rgba(0,0,0,.06)}') | Out-Null
$sb.AppendLine('.sec h2{display:inline;font-size:18px;font-weight:600;color:#2c3e50;margin-bottom:16px;padding-bottom:10px}') | Out-Null
$sb.AppendLine('.sec-num{display:inline-block;background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;width:28px;height:28px;line-height:28px;text-align:center;border-radius:50%;font-size:13px;font-weight:600;margin-right:8px;vertical-align:middle}') | Out-Null
$sb.AppendLine('.sec-hdr{border-bottom:2px solid #667eea;margin-bottom:16px;padding-bottom:10px}') | Out-Null
$sb.AppendLine('.sec h3{font-size:15px;font-weight:600;color:#34495e;margin:14px 0 8px}') | Out-Null

# Tech stack grid
$sb.AppendLine('.tg{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px}') | Out-Null
$sb.AppendLine('.ti{background:#f8f9fa;border-radius:8px;padding:14px 16px;border-left:3px solid #667eea}') | Out-Null
$sb.AppendLine('.ti .tl{font-size:11px;color:#999;text-transform:uppercase;letter-spacing:.5px;margin-bottom:2px}') | Out-Null
$sb.AppendLine('.ti .tv{font-size:14px;font-weight:600;color:#2c3e50}') | Out-Null
$sb.AppendLine('.ti .td{font-size:12px;color:#888;margin-top:2px}') | Out-Null

# Tables
$sb.AppendLine('.tbl{width:100%;border-collapse:collapse;font-size:13px;margin-bottom:12px}') | Out-Null
$sb.AppendLine('.tbl th{text-align:left;padding:8px 12px;background:#f8f9fa;color:#666;font-weight:600;font-size:12px;border-bottom:2px solid #e0e0e0}') | Out-Null
$sb.AppendLine('.tbl td{padding:8px 12px;border-bottom:1px solid #f0f0f0}') | Out-Null
$sb.AppendLine('.tbl tr:hover td{background:#fafafa}') | Out-Null
$sb.AppendLine('.tbl .mono{font-family:"SF Mono","Consolas",monospace;font-size:12px}') | Out-Null
$sb.AppendLine('.tbl .badge{display:inline-block;padding:1px 8px;border-radius:8px;font-size:11px;font-weight:500}') | Out-Null
$sb.AppendLine('.tbl .bg-green{background:#e8f8f0;color:#27ae60}') | Out-Null
$sb.AppendLine('.tbl .bg-blue{background:#e8f0fe;color:#2979ff}') | Out-Null
$sb.AppendLine('.tbl .bg-orange{background:#fff3e0;color:#e65100}') | Out-Null
$sb.AppendLine('.tbl .bg-purple{background:#f3e5f5;color:#7b1fa2}') | Out-Null

# Controller group (from existing)
$sb.AppendLine('.cg{background:#fff;border-radius:10px;margin-bottom:12px;box-shadow:0 1px 3px rgba(0,0,0,.08);overflow:hidden}') | Out-Null
$sb.AppendLine('.ch{display:flex;justify-content:space-between;align-items:center;padding:14px 20px;cursor:pointer;user-select:none}.ch:hover{background:#f8f9fa}') | Out-Null
$sb.AppendLine('.ct{display:flex;align-items:center;gap:16px;flex:1}') | Out-Null
$sb.AppendLine('.cn{font-size:16px;font-weight:600;color:#2c3e50}.cs{font-size:13px;color:#888;display:flex;align-items:center;gap:8px}') | Out-Null
$sb.AppendLine('.mb{display:inline-block;width:60px;height:8px;background:#ecf0f1;border-radius:4px;overflow:hidden;vertical-align:middle}') | Out-Null
$sb.AppendLine('.mf{display:block;height:100%;background:linear-gradient(90deg,#27ae60,#2ecc71);border-radius:4px}') | Out-Null
$sb.AppendLine('.ti{font-size:14px;color:#bbb;transition:transform .2s;margin-left:12px}') | Out-Null
$sb.AppendLine('.cb{border-top:1px solid #f0f0f0}.cl .cb{display:none}.cl .ti{transform:rotate(-90deg)}') | Out-Null
$sb.AppendLine('.tt{width:100%;border-collapse:collapse;font-size:14px}') | Out-Null
$sb.AppendLine('.tt th{text-align:left;padding:10px 20px;background:#fafafa;color:#888;font-weight:500;font-size:12px;text-transform:uppercase;letter-spacing:.5px}') | Out-Null
$sb.AppendLine('.tt td{padding:10px 20px;border-top:1px solid #f5f5f5}.tt tr:hover td{background:#fafafa}') | Out-Null
$sb.AppendLine('.tn{font-family:"SF Mono","Consolas",monospace;font-size:13px}') | Out-Null
$sb.AppendLine('.d{font-family:"SF Mono","Consolas",monospace;font-size:12px;color:#999}') | Out-Null
$sb.AppendLine('.b{display:inline-block;padding:2px 10px;border-radius:10px;font-size:12px;font-weight:500}') | Out-Null
$sb.AppendLine('.b-p{background:#e8f8f0;color:#27ae60}.b-f{background:#fde8e8;color:#e74c3c}.b-s{background:#f0f0f0;color:#95a5a6}') | Out-Null
$sb.AppendLine('.st{margin-bottom:16px;font-weight:600;font-size:16px;color:#2c3e50}') | Out-Null
$sb.AppendLine('.ft{text-align:center;padding:24px 0;font-size:12px;color:#aaa}') | Out-Null
$sb.AppendLine('@media(max-width:768px){.d{grid-template-columns:repeat(2,1fr)}.tg{grid-template-columns:repeat(2,1fr)}.h h1{font-size:20px}}') | Out-Null
$sb.AppendLine('</style></head><body><div class="c">') | Out-Null

# ===== HEADER =====
$sb.AppendLine('<div class="h"><h1>📋 学生管理系统 · 综合测试报告</h1><div class="sub">StudentManager ASP.NET Core MVC — 全量测试与项目分析</div><div class="ver">生成时间：' + $nowStr + ' | .NET 8 + ASP.NET Core MVC + MySQL</div></div>') | Out-Null

# ===== DASHBOARD =====
$sb.AppendLine('<div class="d">') | Out-Null
$sb.AppendLine("<div class='cd t0'><div class='n'>$total</div><div class='l'>总测试用例</div></div>") | Out-Null
$sb.AppendLine("<div class='cd t1'><div class='n'>$passed</div><div class='l'>通过</div></div>") | Out-Null
$sb.AppendLine("<div class='cd t2'><div class='n'>$failed</div><div class='l'>失败</div></div>") | Out-Null
$sb.AppendLine("<div class='cd t3'><div class='n'>${passRate}%</div><div class='l'>通过率</div></div>") | Out-Null
$sb.AppendLine('</div>') | Out-Null

# ===== PROGRESS BAR =====
$sb.AppendLine('<div class="pw"><div class="pb">') | Out-Null
$sb.AppendLine($segPass + $segFail + $segSkip) | Out-Null
$sb.AppendLine('</div><div class="pl">') | Out-Null
$sb.AppendLine("<span><i style='background:#27ae60'></i> 通过 ($passed)</span>") | Out-Null
$sb.AppendLine("<span><i style='background:#e74c3c'></i> 失败 ($failed)</span>") | Out-Null
$sb.AppendLine("<span><i style='background:#95a5a6'></i> 跳过 ($skipped)</span>") | Out-Null
$sb.AppendLine('</div></div>') | Out-Null

# ===== META =====
$sb.AppendLine("<div class='mi'><span><span class='ml'>测试耗时：</span> $durText</span><span><span class='ml'>执行时间：</span> $startStr</span><span><span class='ml'>状态：</span> <span style='color:$statusColor;font-weight:600'>$statusText</span></span></div>") | Out-Null

# ===== 1. TECHNOLOGY STACK =====
$sb.AppendLine('<div class="sec">') | Out-Null
$sb.AppendLine('<div class="sec-hdr"><span class="sec-num">①</span><h2>技术栈</h2></div>') | Out-Null
$sb.AppendLine('<div class="tg">') | Out-Null

# Backend
$sb.AppendLine('<div class="ti"><div class="tl">后端框架</div><div class="tv">ASP.NET Core MVC</div><div class="td">.NET 8（SDK 9.0）</div></div>') | Out-Null
$sb.AppendLine('<div class="ti"><div class="tl">对象关系映射</div><div class="tv">Entity Framework Core 9</div><div class="td">Code-First 模式</div></div>') | Out-Null
$sb.AppendLine('<div class="ti"><div class="tl">数据库</div><div class="tv">MySQL 8.0</div><div class="td">Pomelo EF Core 提供程序</div></div>') | Out-Null
$sb.AppendLine('<div class="ti"><div class="tl">认证方式</div><div class="tv">Session 会话认证</div><div class="td">HttpContext.Session</div></div>') | Out-Null

# Frontend
$sb.AppendLine('<div class="ti"><div class="tl">视图引擎</div><div class="tv">Razor Pages</div><div class="td">.cshtml 模板</div></div>') | Out-Null
$sb.AppendLine('<div class="ti"><div class="tl">CSS 框架</div><div class="tv">Bootstrap 5</div><div class="td">响应式布局</div></div>') | Out-Null
$sb.AppendLine('<div class="ti"><div class="tl">图标库</div><div class="tv">Font Awesome 6</div><div class="td">CDN 加载</div></div>') | Out-Null
$sb.AppendLine('<div class="ti"><div class="tl">客户端脚本</div><div class="tv">jQuery + 验证插件</div><div class="td">非侵入式验证</div></div>') | Out-Null

# Testing
$sb.AppendLine('<div class="ti"><div class="tl">测试框架</div><div class="tv">xUnit + Moq</div><div class="td">单元测试</div></div>') | Out-Null
$sb.AppendLine('<div class="ti"><div class="tl">测试数据库</div><div class="tv">EF Core InMemory</div><div class="td">模拟 Session 支持</div></div>') | Out-Null
$sb.AppendLine('<div class="ti"><div class="tl">构建工具</div><div class="tv">MSBuild / dotnet CLI</div><div class="td">.NET SDK 9.0</div></div>') | Out-Null
$sb.AppendLine('<div class="ti"><div class="tl">集成开发环境</div><div class="tv">Visual Studio Code</div><div class="td">C# Dev Kit 扩展</div></div>') | Out-Null

$sb.AppendLine('</div></div>') | Out-Null

# ===== 2. SYSTEM ARCHITECTURE =====
$sb.AppendLine('<div class="sec">') | Out-Null
$sb.AppendLine('<div class="sec-hdr"><span class="sec-num">②</span><h2>系统架构</h2></div>') | Out-Null
$sb.AppendLine("<div style='font-size:13px;color:#555;line-height:2'>") | Out-Null
$sb.AppendLine("<strong>架构模式：</strong>MVC（Model-View-Controller）<br>") | Out-Null
$sb.AppendLine("<strong>请求流程：</strong>浏览器 → ASP.NET Core 中间件管道 → 控制器 → EF Core → MySQL 数据库 → Razor 视图 → HTML 响应<br>") | Out-Null
$sb.AppendLine("<strong>认证流程：</strong>登录表单 → 写入 Session（Username / Role / UserId）→ 每个 Action 执行 IsAdmin() 检查<br>") | Out-Null
$sb.AppendLine("<strong>路由规则：</strong><code>{controller=Home}/{action=Index}/{id?}</code>（ASP.NET Core 默认约定）") | Out-Null
$sb.AppendLine('</div>') | Out-Null
$sb.AppendLine('</div>') | Out-Null

# ===== 3. DATA MODELS (ER) =====
$sb.AppendLine('<div class="sec">') | Out-Null
$sb.AppendLine('<div class="sec-hdr"><span class="sec-num">③</span><h2>数据模型与实体关系</h2></div>') | Out-Null

$sb.AppendLine('<h3>实体定义</h3>') | Out-Null
$sb.AppendLine('<table class="tbl">') | Out-Null
$sb.AppendLine('<thead><tr><th>实体</th><th>数据表</th><th>字段</th><th>说明</th></tr></thead><tbody>') | Out-Null
$sb.AppendLine("<tr><td><strong>User</strong>（用户）</td><td class='mono'>Users</td><td>Id, Username, Password, Role</td><td>系统用户（管理员 / 普通用户）</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><strong>Student</strong>（学生）</td><td class='mono'>Students</td><td>Id, StudentNo, Name, Class</td><td>学生档案记录</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><strong>Course</strong>（课程）</td><td class='mono'>Courses</td><td>Id, CourseName, Teacher</td><td>课程目录</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><strong>Score</strong>（成绩）</td><td class='mono'>Scores</td><td>Id, StudentId(FK), CourseId(FK), Grade, ScoreDate</td><td>成绩记录（关联表）</td></tr>") | Out-Null
$sb.AppendLine('</tbody></table>') | Out-Null

$sb.AppendLine('<h3>实体关系</h3>') | Out-Null
$sb.AppendLine("<div style='font-size:13px;color:#555;line-height:2'>") | Out-Null
$sb.AppendLine("<strong>Score</strong>（成绩）→ <strong>Student</strong>（学生）：多对一（通过 Score.StudentId 外键）<br>") | Out-Null
$sb.AppendLine("<strong>Score</strong>（成绩）→ <strong>Course</strong>（课程）：多对一（通过 Score.CourseId 外键）<br>") | Out-Null
$sb.AppendLine("<strong>User</strong>（用户）独立存在，与 Student 无直接外键关联（按惯例 UserId 匹配）") | Out-Null
$sb.AppendLine('</div>') | Out-Null
$sb.AppendLine('</div>') | Out-Null

# ===== 4. API ENDPOINTS =====
$sb.AppendLine('<div class="sec">') | Out-Null
$sb.AppendLine('<div class="sec-hdr"><span class="sec-num">④</span><h2>API 接口清单</h2></div>') | Out-Null

# Account
$sb.AppendLine('<h3>📁 AccountController <span style="font-weight:400;font-size:12px;color:#888">/Account/*</span></h3>') | Out-Null
$sb.AppendLine('<table class="tbl"><thead><tr><th style="width:60px">HTTP</th><th>路由</th><th>方法</th><th style="width:70px">权限</th><th>功能说明</th></tr></thead><tbody>') | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Account/Register</td><td>Register()</td><td><span class='badge bg-blue'>公开</span></td><td>显示注册表单</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-orange'>POST</span></td><td class='mono'>/Account/Register</td><td>Register(User)</td><td><span class='badge bg-blue'>公开</span></td><td>创建新用户账号</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Account/Login</td><td>Login()</td><td><span class='badge bg-blue'>公开</span></td><td>显示登录表单</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-orange'>POST</span></td><td class='mono'>/Account/Login</td><td>Login(User)</td><td><span class='badge bg-blue'>公开</span></td><td>用户认证并写入 Session</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Account/Logout</td><td>Logout()</td><td><span class='badge bg-blue'>公开</span></td><td>清除 Session 并跳转</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Account/MyScores</td><td>MyScores()</td><td><span class='badge bg-purple'>需登录</span></td><td>查看自己的成绩</td></tr>") | Out-Null
$sb.AppendLine('</tbody></table>') | Out-Null

# Home
$sb.AppendLine('<h3>🏠 HomeController <span style="font-weight:400;font-size:12px;color:#888">/Home/*</span></h3>') | Out-Null
$sb.AppendLine('<table class="tbl"><thead><tr><th style="width:60px">HTTP</th><th>路由</th><th>方法</th><th style="width:70px">权限</th><th>功能说明</th></tr></thead><tbody>') | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Home/Index</td><td>Index()</td><td><span class='badge bg-blue'>公开</span></td><td>首页 / 欢迎页面</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Home/Privacy</td><td>Privacy()</td><td><span class='badge bg-blue'>公开</span></td><td>隐私政策页面</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Home/Error</td><td>Error()</td><td><span class='badge bg-blue'>公开</span></td><td>错误页面（带 ErrorViewModel）</td></tr>") | Out-Null
$sb.AppendLine('</tbody></table>') | Out-Null

# Students
$sb.AppendLine('<h3>👨‍🎓 StudentsController <span style="font-weight:400;font-size:12px;color:#888">/Students/*</span></h3>') | Out-Null
$sb.AppendLine('<table class="tbl"><thead><tr><th style="width:60px">HTTP</th><th>路由</th><th>方法</th><th style="width:70px">权限</th><th>功能说明</th></tr></thead><tbody>') | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Students/Index?searchString=</td><td>Index()</td><td><span class='badge bg-blue'>公开</span></td><td>学生列表（支持搜索）</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Students/Create</td><td>Create()</td><td><span class='badge bg-orange'>管理员</span></td><td>显示添加学生表单</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-orange'>POST</span></td><td class='mono'>/Students/Create</td><td>Create(Student)</td><td><span class='badge bg-orange'>管理员</span></td><td>新增学生记录</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Students/Edit/{id}</td><td>Edit(id)</td><td><span class='badge bg-orange'>管理员</span></td><td>显示编辑表单</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-orange'>POST</span></td><td class='mono'>/Students/Edit/{id}</td><td>Edit(Student)</td><td><span class='badge bg-orange'>管理员</span></td><td>更新学生信息</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Students/Delete/{id}</td><td>Delete(id)</td><td><span class='badge bg-orange'>管理员</span></td><td>显示删除确认页</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-orange'>POST</span></td><td class='mono'>/Students/Delete/{id}</td><td>DeleteConfirmed(id)</td><td><span class='badge bg-orange'>管理员</span></td><td>执行删除操作</td></tr>") | Out-Null
$sb.AppendLine('</tbody></table>') | Out-Null

# Courses
$sb.AppendLine('<h3>📚 CoursesController <span style="font-weight:400;font-size:12px;color:#888">/Courses/*</span></h3>') | Out-Null
$sb.AppendLine('<table class="tbl"><thead><tr><th style="width:60px">HTTP</th><th>路由</th><th>方法</th><th style="width:70px">权限</th><th>功能说明</th></tr></thead><tbody>') | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Courses/Index</td><td>Index()</td><td><span class='badge bg-blue'>公开</span></td><td>课程列表</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Courses/Create</td><td>Create()</td><td><span class='badge bg-orange'>管理员</span></td><td>显示添加课程表单</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-orange'>POST</span></td><td class='mono'>/Courses/Create</td><td>Create(Course)</td><td><span class='badge bg-orange'>管理员</span></td><td>新增课程</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Courses/Edit/{id}</td><td>Edit(id)</td><td><span class='badge bg-orange'>管理员</span></td><td>显示编辑表单</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-orange'>POST</span></td><td class='mono'>/Courses/Edit/{id}</td><td>Edit(Course)</td><td><span class='badge bg-orange'>管理员</span></td><td>更新课程信息</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Courses/Delete/{id}</td><td>Delete(id)</td><td><span class='badge bg-orange'>管理员</span></td><td>显示删除确认页</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-orange'>POST</span></td><td class='mono'>/Courses/Delete/{id}</td><td>DeleteConfirmed(id)</td><td><span class='badge bg-orange'>管理员</span></td><td>执行删除操作</td></tr>") | Out-Null
$sb.AppendLine('</tbody></table>') | Out-Null

# Scores
$sb.AppendLine('<h3>📊 ScoresController <span style="font-weight:400;font-size:12px;color:#888">/Scores/*</span></h3>') | Out-Null
$sb.AppendLine('<table class="tbl"><thead><tr><th style="width:60px">HTTP</th><th>路由</th><th>方法</th><th style="width:70px">权限</th><th>功能说明</th></tr></thead><tbody>') | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Scores/Index</td><td>Index()</td><td><span class='badge bg-orange'>管理员</span></td><td>全部成绩列表（含学生和课程信息）</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Scores/Create</td><td>Create()</td><td><span class='badge bg-orange'>管理员</span></td><td>显示录入成绩表单</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-orange'>POST</span></td><td class='mono'>/Scores/Create</td><td>Create(Score)</td><td><span class='badge bg-orange'>管理员</span></td><td>提交成绩（ScoreDate 自动赋值）</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Scores/Edit/{id}</td><td>Edit(id)</td><td><span class='badge bg-orange'>管理员</span></td><td>显示编辑成绩表单</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-orange'>POST</span></td><td class='mono'>/Scores/Edit/{id}</td><td>Edit(Score)</td><td><span class='badge bg-orange'>管理员</span></td><td>更新成绩（保留原 ScoreDate）</td></tr>") | Out-Null
$sb.AppendLine('</tbody></table>') | Out-Null

# Users
$sb.AppendLine('<h3>👤 UsersController <span style="font-weight:400;font-size:12px;color:#888">/Users/*</span></h3>') | Out-Null
$sb.AppendLine('<table class="tbl"><thead><tr><th style="width:60px">HTTP</th><th>路由</th><th>方法</th><th style="width:70px">权限</th><th>功能说明</th></tr></thead><tbody>') | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Users/Index</td><td>Index()</td><td><span class='badge bg-orange'>管理员</span></td><td>用户列表</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Users/Edit/{id}</td><td>Edit(id)</td><td><span class='badge bg-orange'>管理员</span></td><td>显示编辑用户表单</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-orange'>POST</span></td><td class='mono'>/Users/Edit/{id}</td><td>Edit(User)</td><td><span class='badge bg-orange'>管理员</span></td><td>更新用户信息</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-green'>GET</span></td><td class='mono'>/Users/Delete/{id}</td><td>Delete(id)</td><td><span class='badge bg-orange'>管理员</span></td><td>显示删除确认页</td></tr>") | Out-Null
$sb.AppendLine("<tr><td><span class='badge bg-orange'>POST</span></td><td class='mono'>/Users/Delete/{id}</td><td>DeleteConfirmed(id)</td><td><span class='badge bg-orange'>管理员</span></td><td>执行删除操作</td></tr>") | Out-Null
$sb.AppendLine('</tbody></table>') | Out-Null

$sb.AppendLine('</div>') | Out-Null

# ===== 5. API SUMMARY =====
$sb.AppendLine('<div class="sec">') | Out-Null
$sb.AppendLine('<div class="sec-hdr"><span class="sec-num">⑤</span><h2>API 接口汇总</h2></div>') | Out-Null
$sb.AppendLine('<table class="tbl"><thead><tr><th>控制器</th><th>接口数</th><th>公开</th><th>仅管理员</th><th>需登录</th></tr></thead><tbody>') | Out-Null
$sb.AppendLine("<tr><td>AccountController</td><td>6</td><td>5</td><td>0</td><td>1</td></tr>") | Out-Null
$sb.AppendLine("<tr><td>HomeController</td><td>3</td><td>3</td><td>0</td><td>0</td></tr>") | Out-Null
$sb.AppendLine("<tr><td>StudentsController</td><td>7</td><td>1</td><td>6</td><td>0</td></tr>") | Out-Null
$sb.AppendLine("<tr><td>CoursesController</td><td>7</td><td>1</td><td>6</td><td>0</td></tr>") | Out-Null
$sb.AppendLine("<tr><td>ScoresController</td><td>5</td><td>0</td><td>5</td><td>0</td></tr>") | Out-Null
$sb.AppendLine("<tr><td>UsersController</td><td>5</td><td>0</td><td>5</td><td>0</td></tr>") | Out-Null
$sb.AppendLine("<tr style='font-weight:600;background:#f8f9fa'><td><strong>合计</strong></td><td><strong>33</strong></td><td><strong>10</strong></td><td><strong>22</strong></td><td><strong>1</strong></td></tr>") | Out-Null
$sb.AppendLine('</tbody></table>') | Out-Null
$sb.AppendLine('</div>') | Out-Null

# ===== 6. TEST COVERAGE =====
$sb.AppendLine('<div class="sec">') | Out-Null
$sb.AppendLine('<div class="sec-hdr"><span class="sec-num">⑥</span><h2>测试覆盖率（按控制器）</h2></div>') | Out-Null

$ctrlCoverage = @"
<div style='overflow-x:auto'>
<table class='tbl'>
<thead><tr><th>控制器</th><th>总接口数</th><th>测试用例数</th><th>测试文件</th><th>覆盖状态</th></tr></thead>
<tbody>
<tr><td>AccountController</td><td>6</td><td>10</td><td>AccountControllerTests.cs</td><td><span class='badge bg-green'>全面覆盖</span></td></tr>
<tr><td>HomeController</td><td>3</td><td>3</td><td>HomeControllerTests.cs</td><td><span class='badge bg-green'>完整覆盖</span></td></tr>
<tr><td>StudentsController</td><td>7</td><td>14</td><td>StudentsControllerTests.cs</td><td><span class='badge bg-green'>全面覆盖</span></td></tr>
<tr><td>CoursesController</td><td>7</td><td>9</td><td>CoursesControllerTests.cs</td><td><span class='badge bg-green'>全面覆盖</span></td></tr>
<tr><td>ScoresController</td><td>5</td><td>12</td><td>ScoresControllerTests.cs</td><td><span class='badge bg-green'>全面覆盖</span></td></tr>
<tr><td>UsersController</td><td>5</td><td>8</td><td>UsersControllerTests.cs</td><td><span class='badge bg-green'>全面覆盖</span></td></tr>
</tbody></table>
</div>
"@
$sb.AppendLine($ctrlCoverage) | Out-Null
$sb.AppendLine('</div>') | Out-Null

# ===== 7. TEST RESULTS BY CONTROLLER =====
$sb.AppendLine("<div class='st' style='margin-bottom:16px;font-weight:600;font-size:16px;color:#2c3e50'>⑦ 各控制器测试详情 <span style='font-weight:400;font-size:13px;color:#888'>(点击可折叠展开)</span></div>") | Out-Null
$sb.AppendLine($ctrlHtml) | Out-Null

# ===== FOOTER =====
$sb.AppendLine('</div>') | Out-Null
$sb.AppendLine("<div class='ft'>学生管理系统 StudentManager | .NET 8 + ASP.NET Core MVC + MySQL | 报告生成时间：$nowStr</div>") | Out-Null
$sb.AppendLine("<script>document.querySelectorAll('.ch').forEach(function(e){e.addEventListener('click',function(){this.parentElement.classList.toggle('cl')})})</script>") | Out-Null
$sb.AppendLine('</body></html>') | Out-Null

# ====== Write file ======
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($ReportPath, $sb.ToString(), $utf8Bom)
Write-Ok ("Report: " + $ReportPath)

try { Start-Process "msedge.exe" -ArgumentList ("file://" + $ReportPath) -ErrorAction SilentlyContinue } catch {}
