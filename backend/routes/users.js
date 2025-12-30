const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');

const usersFilePath = path.join(__dirname, '../data/users.json');

// Helper to read users
const readUsers = () => {
    try {
        const data = fs.readFileSync(usersFilePath, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        return [];
    }
};

// Helper to write users
const writeUsers = (users) => {
    fs.writeFileSync(usersFilePath, JSON.stringify(users, null, 2), 'utf8');
};

// GET all users
router.get('/', (req, res) => {
    const users = readUsers();
    // Don't send passwords in the list
    const safeUsers = users.map(u => ({ username: u.username, role: u.role }));
    res.json({ success: true, data: safeUsers });
});

// POST add user
router.post('/', (req, res) => {
    const { username, password, role = 'admin' } = req.body;
    if (!username || !password) {
        return res.status(400).json({ success: false, error: 'Username dan password wajib diisi' });
    }

    const users = readUsers();
    if (users.find(u => u.username === username)) {
        return res.status(400).json({ success: false, error: 'Username sudah digunakan' });
    }

    users.push({ username, password, role });
    writeUsers(users);
    res.json({ success: true, message: 'User berhasil ditambahkan' });
});

// PUT update user
router.put('/:username', (req, res) => {
    const { username } = req.params;
    const { password, role } = req.body;

    const users = readUsers();
    const userIndex = users.findIndex(u => u.username === username);

    if (userIndex === -1) {
        return res.status(404).json({ success: false, error: 'User tidak ditemukan' });
    }

    if (password) users[userIndex].password = password;
    if (role) users[userIndex].role = role;

    writeUsers(users);
    res.json({ success: true, message: 'User berhasil diperbarui' });
});

// DELETE user
router.delete('/:username', (req, res) => {
    const { username } = req.params;

    // Prevent deleting the main admin
    if (username === 'admin') {
        return res.status(403).json({ success: false, error: 'User admin utama tidak dapat dihapus' });
    }

    let users = readUsers();
    const initialLength = users.length;
    users = users.filter(u => u.username !== username);

    if (users.length === initialLength) {
        return res.status(404).json({ success: false, error: 'User tidak ditemukan' });
    }

    writeUsers(users);
    res.json({ success: true, message: 'User berhasil dihapus' });
});

module.exports = router;
