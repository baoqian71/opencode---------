namespace StudentManager.Models
{
    public class User
    {
        public int Id { get; set; }

        public string Username { get; set; }

        public string Password { get; set; } // 初期用明文，后续加哈希

        public string Role { get; set; } = "User"; // 或 "Admin"
    }
}
