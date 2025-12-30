const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');

const dataPath = path.join(__dirname, '../data/cctvData.json');

// Helper to load/save data
function loadData() {
    const raw = fs.readFileSync(dataPath);
    return JSON.parse(raw);
}

function saveData(data) {
    fs.writeFileSync(dataPath, JSON.stringify(data, null, 2));
}

// GET all categories
router.get('/', (req, res) => {
    try {
        const data = loadData();
        res.json({ success: true, data: data.categories || [] });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// POST create new category
router.post('/', (req, res) => {
    try {
        const data = loadData();
        if (!data.categories) data.categories = [];

        const newCategory = {
            id: `cat-${Date.now()}`,
            name: req.body.name,
            icon: req.body.icon || 'category',
            color: req.body.color || '#E53935',
            createdAt: new Date().toISOString()
        };

        data.categories.push(newCategory);
        saveData(data);

        res.json({ success: true, data: newCategory });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// PUT update category
router.put('/:id', (req, res) => {
    try {
        const data = loadData();
        if (!data.categories) data.categories = [];

        const index = data.categories.findIndex(c => c.id === req.params.id);
        if (index === -1) {
            return res.status(404).json({ success: false, error: 'Category not found' });
        }

        data.categories[index] = {
            ...data.categories[index],
            name: req.body.name || data.categories[index].name,
            icon: req.body.icon || data.categories[index].icon,
            color: req.body.color || data.categories[index].color,
            updatedAt: new Date().toISOString()
        };

        saveData(data);
        res.json({ success: true, data: data.categories[index] });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// DELETE category
router.delete('/:id', (req, res) => {
    try {
        const data = loadData();
        if (!data.categories) data.categories = [];

        const index = data.categories.findIndex(c => c.id === req.params.id);
        if (index === -1) {
            return res.status(404).json({ success: false, error: 'Category not found' });
        }

        const deleted = data.categories.splice(index, 1)[0];
        saveData(data);

        res.json({ success: true, data: deleted });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

module.exports = router;
