const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const multer = require('multer');

const dataPath = path.join(__dirname, '../data/trashBinData.json');
const uploadDir = path.join(__dirname, '../uploads/trash-bins');

// Ensure directories exist
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

// Create data file if not exists
if (!fs.existsSync(dataPath)) {
    fs.writeFileSync(dataPath, JSON.stringify({ trashBins: [] }, null, 2));
}

// Configure multer for photo uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, uploadDir),
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, `trash-bin-${uniqueSuffix}${path.extname(file.originalname)}`);
    }
});

const upload = multer({
    storage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
    fileFilter: (req, file, cb) => {
        const allowed = /jpeg|jpg|png|webp/;
        const valid = allowed.test(path.extname(file.originalname).toLowerCase());
        cb(null, valid);
    }
});

// Helper to load/save data
function loadData() {
    const raw = fs.readFileSync(dataPath);
    return JSON.parse(raw);
}

function saveData(data) {
    fs.writeFileSync(dataPath, JSON.stringify(data, null, 2));
}

// GET all trash bins
router.get('/', (req, res) => {
    try {
        const data = loadData();
        res.json({ success: true, data: data.trashBins || [] });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// POST create new trash bin
router.post('/', upload.single('photo'), (req, res) => {
    try {
        const data = loadData();

        const newTrashBin = {
            id: `tb-${Date.now()}`,
            name: req.body.name,
            location: {
                lat: parseFloat(req.body.lat) || 0,
                lng: parseFloat(req.body.lng) || 0
            },
            photoUrl: req.file ? `/uploads/trash-bins/${req.file.filename}` : null,
            createdAt: new Date().toISOString()
        };

        data.trashBins.push(newTrashBin);
        saveData(data);

        res.json({ success: true, data: newTrashBin });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// PUT update trash bin
router.put('/:id', upload.single('photo'), (req, res) => {
    try {
        const data = loadData();
        const index = data.trashBins.findIndex(tb => tb.id === req.params.id);

        if (index === -1) {
            return res.status(404).json({ success: false, error: 'Trash bin not found' });
        }

        const existing = data.trashBins[index];

        data.trashBins[index] = {
            ...existing,
            name: req.body.name || existing.name,
            location: {
                lat: req.body.lat ? parseFloat(req.body.lat) : existing.location.lat,
                lng: req.body.lng ? parseFloat(req.body.lng) : existing.location.lng
            },
            photoUrl: req.file ? `/uploads/trash-bins/${req.file.filename}` : existing.photoUrl,
            updatedAt: new Date().toISOString()
        };

        saveData(data);
        res.json({ success: true, data: data.trashBins[index] });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// DELETE trash bin
router.delete('/:id', (req, res) => {
    try {
        const data = loadData();
        const index = data.trashBins.findIndex(tb => tb.id === req.params.id);

        if (index === -1) {
            return res.status(404).json({ success: false, error: 'Trash bin not found' });
        }

        // Delete photo file if exists
        const trashBin = data.trashBins[index];
        if (trashBin.photoUrl) {
            const photoPath = path.join(__dirname, '..', trashBin.photoUrl);
            if (fs.existsSync(photoPath)) {
                fs.unlinkSync(photoPath);
            }
        }

        const deleted = data.trashBins.splice(index, 1)[0];
        saveData(data);

        res.json({ success: true, data: deleted });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

module.exports = router;
