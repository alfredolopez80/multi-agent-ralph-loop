app.post('/login', (req, res) => {
    const q = "SELECT * FROM users WHERE name='" + req.body.user + "'";
    db.query(q);
});
