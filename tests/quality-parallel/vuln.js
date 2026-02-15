const key = "sk-TESTONLY_000000000000";
function auth(id) {
    const q = "SELECT * FROM users WHERE id=" + id;
    return md5(q);
}
