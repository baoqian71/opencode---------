param(
    [string]$ReportPath = "",
    [switch]$SkipTests
)

function Write-Info  { Write-Host "[INFO] $($args[0])" -ForegroundColor Cyan }
function Write-Ok   { Write-Host "[OK]   $($args[0])" -ForegroundColor Green }
function Write-Err  { Write-Host "[ERROR] $($args[0])" -ForegroundColor Red }

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
if (-not $ReportPath) { $ReportPath = Join-Path $ProjectRoot "学生管理系统自动测试案例报告.docx" }
Write-Info ("Project: " + $ProjectRoot)

# ====== Run tests ======
$TrxFile = $null
if (-not $SkipTests) {
    Write-Info "Running dotnet test ..."
    $out = dotnet test --logger "trx;LogFileName=test-results.trx" 2>&1
    $out | ForEach-Object { "$_" }
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

$dur = if ($startDt -and $finishDt) { $finishDt - $startDt } else { [TimeSpan]::Zero }
$durText = if ($dur.TotalSeconds -ge 1) { ("{0:N2} 秒" -f $dur.TotalSeconds) } else { ("{0:N0} 毫秒" -f $dur.TotalMilliseconds) }
$passRate = [math]::Round($passed / $total * 100, 1)
$startStr = if ($startDt) { $startDt.ToString("yyyy-MM-dd HH:mm:ss") } else { "-" }
$nowStr = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm")
$grouped = $tests | Group-Object Controller

# Delete old file if exists (not locked)
if (Test-Path $ReportPath) { try { Remove-Item $ReportPath -Force -ErrorAction Stop } catch { } }

# ====== Generate Word Document ======
Write-Info "Generating Word document ..."

try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $null = $word.Documents.Add()
    $doc = $word.ActiveDocument

    # ── Helper: set font ──
    function SetFont($rng, $name, $size, $bold, $colorIdx) {
        $null = $rng.Font.Name = $name
        if ($size)  { $null = $rng.Font.Size = $size }
        if ($bold)  { $null = $rng.Font.Bold = $true }
        if ($null -ne $colorIdx) { $null = $rng.Font.ColorIndex = $colorIdx }
    }

    # ── Helper: heading with decorative bottom border ──
    function AddHeading($text, $level) {
        $p = $doc.Content.Paragraphs.Add()
        $null = $p.Range.Text = $text
        SetFont $p.Range "微软雅黑" 18 $true $null
        if ($level -eq 1) {
            $null = $p.Range.Font.Size = 16
            $null = $p.Range.Font.ColorIndex = 9  # Dark Blue
            $null = $p.Range.ParagraphFormat.SpaceBefore = 18
            $null = $p.Range.ParagraphFormat.SpaceAfter = 8
            # Add bottom border to paragraph
            $null = $p.Range.Borders(2).LineStyle = 1  # wdLineStyleSingle
            $null = $p.Range.Borders(2).LineWidth = 4   # wdLineWidth150pt (approx 1.5pt)
            $null = $p.Range.Borders(2).ColorIndex = 9  # Dark Blue
        } elseif ($level -eq 2) {
            $null = $p.Range.Font.Size = 13
            $null = $p.Range.Font.ColorIndex = 1   # Black
            $null = $p.Range.ParagraphFormat.SpaceBefore = 14
            $null = $p.Range.ParagraphFormat.SpaceAfter = 6
            $null = $p.Range.Borders(2).LineStyle = 1
            $null = $p.Range.Borders(2).LineWidth = 2
            $null = $p.Range.Borders(2).ColorIndex = 13  # Violet/Purple
        }
    }

    # ── Helper: body paragraph ──
    function AddPara($text, $bold, $size, $indent) {
        $p = $doc.Content.Paragraphs.Add()
        $null = $p.Range.Text = $text
        SetFont $p.Range "宋体" $size $bold $null
        $null = $p.Range.ParagraphFormat.SpaceBefore = 3
        $null = $p.Range.ParagraphFormat.SpaceAfter = 3
        if ($indent) { $null = $p.Range.ParagraphFormat.LeftIndent = 24 }
    }

    # ── Helper: centered paragraph ──
    function CenterPara($text, $size, $bold, $colorIdx) {
        $p = $doc.Content.Paragraphs.Add()
        $null = $p.Range.Text = $text
        SetFont $p.Range "微软雅黑" $size $bold $colorIdx
        $null = $p.Range.ParagraphFormat.Alignment = 1
        if ($bold) { $null = $p.Range.Font.Bold = $true }
    }

    # ── Helper: table with header + alternating rows ──
    function AddTable($headers, $rows) {
        $r = $rows.Length + 1
        $c = $headers.Length
        $rng = $doc.Content.Paragraphs.Add().Range
        $table = $doc.Tables.Add($rng, $r, $c)
        $null = $table.Style = "Table Grid"
        $null = $table.Borders.InsideLineStyle = 1
        $null = $table.Borders.OutsideLineStyle = 1

        # ── Header row: dark background + white text ──
        for ($ci = 0; $ci -lt $c; $ci++) {
            $cell = $table.Cell(1, $ci+1)
            $null = $cell.Range.Text = $headers[$ci]
            SetFont $cell.Range "微软雅黑" 10 $true 8  # white bold
            $null = $cell.Shading.BackgroundPatternColor = 5263440  # RGB #2C3E50
            $null = $cell.Range.ParagraphFormat.Alignment = 1
        }

        # ── Data rows with alternating shading ──
        for ($ri = 0; $ri -lt $rows.Length; $ri++) {
            $vals = $rows[$ri]
            for ($ci = 0; $ci -lt [Math]::Min($vals.Length, $c); $ci++) {
                $cell = $table.Cell($ri+2, $ci+1)
                $null = $cell.Range.Text = $vals[$ci]
                SetFont $cell.Range "宋体" 9 $false $null
                if ($ci -eq 0) { $null = $cell.Range.ParagraphFormat.Alignment = 1 }
            }
            # Alternating row: light gray
            if ($ri % 2 -eq 1) {
                for ($ci = 0; $ci -lt $c; $ci++) {
                    $cell = $table.Cell($ri+2, $ci+1)
                    $null = $cell.Shading.BackgroundPatternColor = 15790320  # RGB #F0F0F0
                }
            }
        }

        # ── Auto-fit columns to content ──
        $null = $table.Columns.AutoFit()
    }

    # ═══════════════════════════════════════════════════
    #  COVER PAGE
    # ═══════════════════════════════════════════════════

    # Insert some blank lines at top
    for ($i=0; $i -lt 4; $i++) { $null = $doc.Content.Paragraphs.Add() }

    # ── Top decorative banner (colored table with no borders) ──
    $bannerRng = $doc.Content.Paragraphs.Add().Range
    $banner = $doc.Tables.Add($bannerRng, 1, 1)
    $null = $banner.Borders.InsideLineStyle = 0
    $null = $banner.Borders.OutsideLineStyle = 0
    $null = $banner.Cell(1,1).Shading.BackgroundPatternColor = 5263440  # #2C3E50
    $null = $banner.Cell(1,1).Range.ParagraphFormat.Alignment = 1
    $null = $banner.Cell(1,1).Range.Text = "  "
    $null = $banner.Cell(1,1).Range.ParagraphFormat.SpaceBefore = 6
    $null = $banner.Cell(1,1).Range.ParagraphFormat.SpaceAfter = 6

    $null = $doc.Content.Paragraphs.Add()

    CenterPara "学生管理系统" 30 $true 8
    CenterPara "自动测试案例报告" 26 $true 8

    $null = $doc.Content.Paragraphs.Add()

    # ── Subtitle with accent line ──
    $subRng = $doc.Content.Paragraphs.Add().Range
    $null = $subRng.Text = "━━━━━━━━━━━━━━━━━━━━━━━━"
    SetFont $subRng "宋体" 10 $false 13  # Violet
    $null = $subRng.ParagraphFormat.Alignment = 1

    CenterPara "StudentManager  ·  ASP.NET Core MVC  ·  MySQL" 12 $false 9
    CenterPara "生成日期：$nowStr" 11 $false $null

    $null = $doc.Content.Paragraphs.Add()

    $subRng2 = $doc.Content.Paragraphs.Add().Range
    $null = $subRng2.Text = "━━━━━━━━━━━━━━━━━━━━━━━━"
    SetFont $subRng2 "宋体" 10 $false 13
    $null = $subRng2.ParagraphFormat.Alignment = 1

    $null = $doc.Content.Paragraphs.Add()

    # ── Cover stats table ──
    $coverTable = $doc.Tables.Add($doc.Content.Paragraphs.Add().Range, 5, 2)
    $null = $coverTable.Style = "Table Grid"
    $null = $coverTable.Borders.InsideLineStyle = 1
    $null = $coverTable.Borders.OutsideLineStyle = 1

    $null = $coverTable.Cell(1,1).Range.Text = "指标"
    $null = $coverTable.Cell(1,2).Range.Text = "数值"
    for ($hi=1; $hi -le 2; $hi++) {
        SetFont $coverTable.Cell(1,$hi).Range "微软雅黑" 10 $true 8
        $null = $coverTable.Cell(1,$hi).Shading.BackgroundPatternColor = 5263440
        $null = $coverTable.Cell(1,$hi).Range.ParagraphFormat.Alignment = 1
    }
    $coverStats = @(@("总测试用例", "$total"), @("通过", "$passed"), @("失败", "$failed"), @("通过率", "${passRate}%"))
    for ($si=0; $si -lt 4; $si++) {
        $null = $coverTable.Cell($si+2,1).Range.Text = $coverStats[$si][0]
        $null = $coverTable.Cell($si+2,2).Range.Text = $coverStats[$si][1]
        SetFont $coverTable.Cell($si+2,1).Range "宋体" 11 $false $null
        SetFont $coverTable.Cell($si+2,2).Range "宋体" 11 $true 9  # bold + dark blue
        $null = $coverTable.Cell($si+2,2).Range.ParagraphFormat.Alignment = 1
    }
    $null = $coverTable.Columns.AutoFit()

    # ── Page break ──
    $null = $doc.Content.Paragraphs.Add()
    $null = ($doc.Content.Paragraphs.Add()).Range.InsertBreak(7)

    # ═══════════════════════════════════════════════════
    #  TABLE OF CONTENTS
    # ═══════════════════════════════════════════════════
    AddHeading "目  录" 1
    $tocItems = @("一、测试概要","二、技术栈","三、系统架构","四、数据模型与实体关系","五、API 接口清单","六、API 接口汇总","七、测试覆盖率","八、各控制器测试详情")
    foreach ($item in $tocItems) { AddPara $item $true 12 $false }

    $null = ($doc.Content.Paragraphs.Add()).Range.InsertBreak(7)

    # ═══════════════════════════════════════════════════
    #  1. TEST SUMMARY
    # ═══════════════════════════════════════════════════
    AddHeading "一、测试概要" 1

    $statusText = if ($failed -gt 0) { "测试未通过" } else { "全部通过" }
    AddPara "执行时间：$startStr"  $false 11 $true
    AddPara "测试耗时：$durText"   $false 11 $true
    AddPara "测试框架：xUnit + Moq（EF Core InMemory）" $false 11 $true
    AddPara "测试状态：$statusText" $true 11 $true

    AddHeading "测试结果概览" 2
    AddTable @("指标", "数值") @(@("总测试用例", "$total"),@("通过", "$passed"),@("失败", "$failed"),@("跳过", "$skipped"),@("通过率", "${passRate}%"))

    # ═══════════════════════════════════════════════════
    #  2. TECHNOLOGY STACK
    # ═══════════════════════════════════════════════════
    AddHeading "二、技术栈" 1

    AddHeading "后端" 2
    AddTable @("类别", "技术", "说明") @(@("后端框架","ASP.NET Core MVC",".NET 8（SDK 9.0）"),@("对象关系映射","Entity Framework Core 9","Code-First 模式"),@("数据库","MySQL 8.0","Pomelo EF Core 提供程序"),@("认证方式","Session 会话认证","HttpContext.Session"))

    AddHeading "前端" 2
    AddTable @("类别", "技术", "说明") @(@("视图引擎","Razor Pages",".cshtml 模板"),@("CSS 框架","Bootstrap 5","响应式布局"),@("图标库","Font Awesome 6","CDN 加载"),@("客户端脚本","jQuery + 验证插件","非侵入式验证"))

    AddHeading "测试与工具" 2
    AddTable @("类别", "技术", "说明") @(@("测试框架","xUnit + Moq","单元测试"),@("测试数据库","EF Core InMemory","模拟 Session 支持"),@("构建工具","MSBuild / dotnet CLI",".NET SDK 9.0"),@("集成开发环境","Visual Studio Code","C# Dev Kit 扩展"))

    # ═══════════════════════════════════════════════════
    #  3. SYSTEM ARCHITECTURE
    # ═══════════════════════════════════════════════════
    AddHeading "三、系统架构" 1
    AddPara "架构模式：MVC（Model-View-Controller）" $false 11 $true
    AddPara "请求流程：浏览器 → ASP.NET Core 中间件管道 → 控制器 → EF Core → MySQL 数据库 → Razor 视图 → HTML 响应" $false 11 $true
    AddPara "认证流程：登录表单 → 写入 Session（Username / Role / UserId）→ 每个 Action 执行 IsAdmin() 检查" $false 11 $true
    AddPara "路由规则：{controller=Home}/{action=Index}/{id?}（ASP.NET Core 默认约定）" $false 11 $true

    # ═══════════════════════════════════════════════════
    #  4. DATA MODELS
    # ═══════════════════════════════════════════════════
    AddHeading "四、数据模型与实体关系" 1

    AddHeading "实体定义" 2
    AddTable @("实体", "数据表", "字段", "说明") @(@("User（用户）","Users","Id, Username, Password, Role","系统用户（管理员 / 普通用户）"),@("Student（学生）","Students","Id, StudentNo, Name, Class","学生档案记录"),@("Course（课程）","Courses","Id, CourseName, Teacher","课程目录"),@("Score（成绩）","Scores","Id, StudentId(FK), CourseId(FK), Grade, ScoreDate","成绩记录（关联表）"))

    AddHeading "实体关系" 2
    AddPara "Score（成绩） → Student（学生）：多对一（通过 Score.StudentId 外键）" $false 11 $true
    AddPara "Score（成绩） → Course（课程）：多对一（通过 Score.CourseId 外键）" $false 11 $true
    AddPara "User（用户）独立存在，与 Student 无直接外键关联（按惯例 UserId 匹配）" $false 11 $true

    # ═══════════════════════════════════════════════════
    #  5. API ENDPOINTS
    # ═══════════════════════════════════════════════════
    AddHeading "五、API 接口清单" 1

    AddHeading "AccountController  /Account/*" 2
    AddTable @("HTTP", "路由", "方法", "权限", "功能说明") @(@("GET","/Account/Register","Register()","公开","显示注册表单"),@("POST","/Account/Register","Register(User)","公开","创建新用户账号"),@("GET","/Account/Login","Login()","公开","显示登录表单"),@("POST","/Account/Login","Login(User)","公开","用户认证并写入 Session"),@("GET","/Account/Logout","Logout()","公开","清除 Session 并跳转"),@("GET","/Account/MyScores","MyScores()","需登录","查看自己的成绩"))

    AddHeading "HomeController  /Home/*" 2
    AddTable @("HTTP", "路由", "方法", "权限", "功能说明") @(@("GET","/Home/Index","Index()","公开","首页 / 欢迎页面"),@("GET","/Home/Privacy","Privacy()","公开","隐私政策页面"),@("GET","/Home/Error","Error()","公开","错误页面（带 ErrorViewModel）"))

    AddHeading "StudentsController  /Students/*" 2
    AddTable @("HTTP", "路由", "方法", "权限", "功能说明") @(@("GET","/Students/Index?searchString=","Index()","公开","学生列表（支持搜索）"),@("GET","/Students/Create","Create()","管理员","显示添加学生表单"),@("POST","/Students/Create","Create(Student)","管理员","新增学生记录"),@("GET","/Students/Edit/{id}","Edit(id)","管理员","显示编辑表单"),@("POST","/Students/Edit/{id}","Edit(Student)","管理员","更新学生信息"),@("GET","/Students/Delete/{id}","Delete(id)","管理员","显示删除确认页"),@("POST","/Students/Delete/{id}","DeleteConfirmed(id)","管理员","执行删除操作"))

    AddHeading "CoursesController  /Courses/*" 2
    AddTable @("HTTP", "路由", "方法", "权限", "功能说明") @(@("GET","/Courses/Index","Index()","公开","课程列表"),@("GET","/Courses/Create","Create()","管理员","显示添加课程表单"),@("POST","/Courses/Create","Create(Course)","管理员","新增课程"),@("GET","/Courses/Edit/{id}","Edit(id)","管理员","显示编辑表单"),@("POST","/Courses/Edit/{id}","Edit(Course)","管理员","更新课程信息"),@("GET","/Courses/Delete/{id}","Delete(id)","管理员","显示删除确认页"),@("POST","/Courses/Delete/{id}","DeleteConfirmed(id)","管理员","执行删除操作"))

    AddHeading "ScoresController  /Scores/*" 2
    AddTable @("HTTP", "路由", "方法", "权限", "功能说明") @(@("GET","/Scores/Index","Index()","管理员","全部成绩列表（含学生和课程信息）"),@("GET","/Scores/Create","Create()","管理员","显示录入成绩表单"),@("POST","/Scores/Create","Create(Score)","管理员","提交成绩（ScoreDate 自动赋值）"),@("GET","/Scores/Edit/{id}","Edit(id)","管理员","显示编辑成绩表单"),@("POST","/Scores/Edit/{id}","Edit(Score)","管理员","更新成绩（保留原 ScoreDate）"))

    AddHeading "UsersController  /Users/*" 2
    AddTable @("HTTP", "路由", "方法", "权限", "功能说明") @(@("GET","/Users/Index","Index()","管理员","用户列表"),@("GET","/Users/Edit/{id}","Edit(id)","管理员","显示编辑用户表单"),@("POST","/Users/Edit/{id}","Edit(User)","管理员","更新用户信息"),@("GET","/Users/Delete/{id}","Delete(id)","管理员","显示删除确认页"),@("POST","/Users/Delete/{id}","DeleteConfirmed(id)","管理员","执行删除操作"))

    # ═══════════════════════════════════════════════════
    #  6. API SUMMARY
    # ═══════════════════════════════════════════════════
    AddHeading "六、API 接口汇总" 1
    AddTable @("控制器", "接口数", "公开", "仅管理员", "需登录") @(@("AccountController","6","5","0","1"),@("HomeController","3","3","0","0"),@("StudentsController","7","1","6","0"),@("CoursesController","7","1","6","0"),@("ScoresController","5","0","5","0"),@("UsersController","5","0","5","0"),@("合计","33","10","22","1"))

    # ═══════════════════════════════════════════════════
    #  7. TEST COVERAGE
    # ═══════════════════════════════════════════════════
    AddHeading "七、测试覆盖率（按控制器）" 1
    AddTable @("控制器", "总接口数", "测试用例数", "测试文件", "覆盖状态") @(@("AccountController","6","10","AccountControllerTests.cs","全面覆盖"),@("HomeController","3","3","HomeControllerTests.cs","完整覆盖"),@("StudentsController","7","14","StudentsControllerTests.cs","全面覆盖"),@("CoursesController","7","9","CoursesControllerTests.cs","全面覆盖"),@("ScoresController","5","12","ScoresControllerTests.cs","全面覆盖"),@("UsersController","5","8","UsersControllerTests.cs","全面覆盖"))

    # ═══════════════════════════════════════════════════
    #  8. DETAILED TEST RESULTS
    # ═══════════════════════════════════════════════════
    AddHeading "八、各控制器测试详情" 1

    foreach ($g in $grouped) {
        $ctrlName = $g.Name
        $gp = 0; $gf = 0; $gs = 0
        $detailRows = @()
        foreach ($t in $g.Group) {
            if ($t.Outcome -eq "Passed") { $gp++ } elseif ($t.Outcome -eq "Failed") { $gf++ } else { $gs++ }
            $detailRows += @(, @($t.Method, $t.Outcome, $t.Duration))
        }
        $gt = $g.Count
        AddHeading "$ctrlName  （$gp / $gt 通过）" 2
        AddTable @("测试用例", "结果", "耗时") $detailRows
    }

    # ═══════════════════════════════════════════════════
    #  SAVE
    # ═══════════════════════════════════════════════════
    $null = $doc.SaveAs([ref]$ReportPath, [ref]16)
    $word.Quit()

    Write-Ok ("Word report saved: " + $ReportPath)
}
catch {
    Write-Err ("Error: " + $_.Exception.Message)
    try { if ($word) { $word.Quit() } } catch {}
    exit 1
}
