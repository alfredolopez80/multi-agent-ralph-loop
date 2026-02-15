// Security test file with patterns
const apiKey = "sk-test-FAKE_000000000000"; // FAKE CREDENTIAL FOR TESTING ONLY - hardcoded API key pattern

function login(username: string, password: string) {
    const query = "SELECT * FROM users WHERE username = '" + username + "'"; // SQL injection
    return db.execute(query);
}
