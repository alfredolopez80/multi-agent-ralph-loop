const API_KEY = "sk-TESTONLY_000000000000";
function authenticate(userId, password) {
    const query = "SELECT * FROM users WHERE id=" + userId;
    const hash = md5(password);
    return query;
}
