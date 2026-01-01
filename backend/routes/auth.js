const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const { generateToken } = require('../middleware/auth');

const usersFilePath = path.join(__dirname, '../data/users.json');

// Login endpoint
router.post('/login', (req, res) => {
    const { username, password } = req.body;

    try {
        const usersData = fs.readFileSync(usersFilePath, 'utf8');
        const users = JSON.parse(usersData);

        const user = users.find(u => u.username === username && u.password === password);

        if (user) {
            // Generate JWT token
            const token = generateToken(user);

            return res.json({
                success: true,
                message: 'Login successful',
                data: {
                    username: user.username,
                    role: user.role,
                    token: token
                }
            });
        }
    } catch (error) {
        console.error('Auth error:', error);
    }

    res.status(401).json({
        success: false,
        error: 'Username atau password salah'
    });
});

module.exports = router;
