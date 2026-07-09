using System;

namespace StudentManager.Models
{
    public class Score
    {
        public int Id { get; set; }

        public int StudentId { get; set; } // 学生外键

        public int CourseId { get; set; } // 课程外键

        public decimal Grade { get; set; } // 成绩（百分制）

        public DateTime ScoreDate { get; set; } // 录入日期（由后台赋值，见 ScoresController）

        public Student? Student { get; set; }

        public Course? Course { get; set; }
    }
}
