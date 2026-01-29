// Security test file with patterns
const apiKey = "sk-live-1234567890abcdef"; // Hardcoded API key

function login(username: string, password: string) {
    const query = "SELECT * FROM users WHERE username = '" + username + "'"; // SQL injection
    return db.execute(query);
}
