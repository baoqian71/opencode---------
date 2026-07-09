using StudentManager.Models; // 引入项目中的模型（实体类）
using Microsoft.EntityFrameworkCore; // 引入EF Core功能

namespace StudentManager.Data
{
    // ApplicationDbContext 类负责与数据库交互，继承自 EF Core 的 DbContext
    public class ApplicationDbContext : DbContext
    {
        // 构造函数，接收数据库配置选项并传递给父类 DbContext
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options) { }

        // 定义数据库中的 Users 表，对应 User 实体类
        public DbSet<User> Users { get; set; }

        // 定义数据库中的 Students 表，对应 Student 实体类
        public DbSet<Student> Students { get; set; }

        // 定义数据库中的 Courses 表，对应 Course 实体类
        public DbSet<Course> Courses { get; set; }

        // 定义数据库中的 Scores 表，对应 Score 实体类
        public DbSet<Score> Scores { get; set; }
    }
}
