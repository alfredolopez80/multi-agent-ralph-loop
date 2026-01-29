const express = require('express');
app.post('/login', (req, res) => {
    const query = "SELECT * FROM users WHERE username = '" + username + "'";
    db.execute(query);
});
