const key = "sk-1234567890abcdef";
function auth(id) {
    const q = "SELECT * FROM users WHERE id=" + id;
    return md5(q);
}
