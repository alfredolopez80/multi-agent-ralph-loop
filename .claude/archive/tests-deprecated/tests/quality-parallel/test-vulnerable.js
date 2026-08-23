const API_KEY = "sk-1234567890abcdef";
function authenticate(userId, password) {
    const query = "SELECT * FROM users WHERE id=" + userId;
    const hash = md5(password);
    return query;
}
