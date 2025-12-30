const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');

// Upload directory for GeoJSON files
const geojsonDir = path.join(__dirname, '../data/geojson');
if (!fs.existsSync(geojsonDir)) {
    fs.mkdirSync(geojsonDir, { recursive: true });
}

// Configure multer for GeoJSON upload
const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, geojsonDir),
    filename: (req, file, cb) => {
        const filename = `geojson_${Date.now()}.geojson`;
        cb(null, filename);
    }
});

const upload = multer({
    storage,
    fileFilter: (req, file, cb) => {
        if (file.mimetype === 'application/json' ||
            file.originalname.endsWith('.geojson') ||
            file.originalname.endsWith('.json')) {
            cb(null, true);
        } else {
            cb(new Error('Only GeoJSON files are allowed'), false);
        }
    },
    limits: { fileSize: 10 * 1024 * 1024 } // 10MB max
});

// Metadata file to track layers
const metadataPath = path.join(geojsonDir, 'layers.json');

const readLayersMetadata = () => {
    try {
        if (fs.existsSync(metadataPath)) {
            return JSON.parse(fs.readFileSync(metadataPath, 'utf8'));
        }
    } catch (e) {
        console.error('Error reading layers metadata:', e);
    }
    return { kecamatan: [], kelurahan: [] };
};

const writeLayersMetadata = (data) => {
    fs.writeFileSync(metadataPath, JSON.stringify(data, null, 2), 'utf8');
};

// ========== KECAMATAN ENDPOINTS ==========

// GET - Get all kecamatan
router.get('/kecamatan', (req, res) => {
    const metadata = readLayersMetadata();
    res.json({ success: true, data: metadata.kecamatan || [] });
});

// GET - Get specific kecamatan GeoJSON data
router.get('/kecamatan/:id/data', (req, res) => {
    const { id } = req.params;
    const metadata = readLayersMetadata();
    const kecamatan = metadata.kecamatan?.find(k => k.id === id);

    if (!kecamatan || !kecamatan.filename) {
        return res.json({ success: true, data: null });
    }

    try {
        const filepath = path.join(geojsonDir, kecamatan.filename);
        if (!fs.existsSync(filepath)) {
            return res.json({ success: true, data: null });
        }

        const geojsonData = JSON.parse(fs.readFileSync(filepath, 'utf8'));
        res.json({ success: true, data: geojsonData });
    } catch (e) {
        res.status(500).json({ success: false, error: 'Error reading GeoJSON file' });
    }
});

// POST - Upload kecamatan
router.post('/kecamatan', upload.single('file'), (req, res) => {
    const { name, color } = req.body;

    if (!name) {
        return res.status(400).json({ success: false, error: 'Name is required' });
    }

    if (!req.file) {
        return res.status(400).json({ success: false, error: 'No file uploaded' });
    }

    // Validate GeoJSON structure
    try {
        const content = fs.readFileSync(req.file.path, 'utf8');
        const geojson = JSON.parse(content);

        if (!geojson.type || !['FeatureCollection', 'Feature', 'GeometryCollection'].includes(geojson.type)) {
            fs.unlinkSync(req.file.path);
            return res.status(400).json({ success: false, error: 'Invalid GeoJSON structure' });
        }
    } catch (e) {
        if (fs.existsSync(req.file.path)) {
            fs.unlinkSync(req.file.path);
        }
        return res.status(400).json({ success: false, error: 'Invalid JSON format' });
    }

    const metadata = readLayersMetadata();
    const newKecamatan = {
        id: uuidv4(),
        name,
        color: color || '#0000FF',
        filename: req.file.filename,
        uploadedAt: new Date().toISOString(),
        originalName: req.file.originalname
    };

    metadata.kecamatan = metadata.kecamatan || [];
    metadata.kecamatan.push(newKecamatan);
    writeLayersMetadata(metadata);

    res.json({
        success: true,
        message: 'Kecamatan berhasil ditambahkan',
        data: newKecamatan
    });
});

// DELETE - Remove kecamatan
router.delete('/kecamatan/:id', (req, res) => {
    const { id } = req.params;
    const metadata = readLayersMetadata();

    const kecamatan = metadata.kecamatan?.find(k => k.id === id);
    if (!kecamatan) {
        return res.status(404).json({ success: false, error: 'Kecamatan tidak ditemukan' });
    }

    // Delete file
    if (kecamatan.filename) {
        const filepath = path.join(geojsonDir, kecamatan.filename);
        if (fs.existsSync(filepath)) {
            fs.unlinkSync(filepath);
        }
    }

    // Remove from metadata
    metadata.kecamatan = metadata.kecamatan.filter(k => k.id !== id);

    // Also remove related kelurahan
    const relatedKelurahan = metadata.kelurahan?.filter(kel => kel.kecamatanId === id) || [];
    relatedKelurahan.forEach(kel => {
        if (kel.filename) {
            const filepath = path.join(geojsonDir, kel.filename);
            if (fs.existsSync(filepath)) {
                fs.unlinkSync(filepath);
            }
        }
    });
    metadata.kelurahan = metadata.kelurahan?.filter(kel => kel.kecamatanId !== id) || [];

    writeLayersMetadata(metadata);

    res.json({ success: true, message: 'Kecamatan dan kelurahan terkait berhasil dihapus' });
});

// ========== KELURAHAN ENDPOINTS ==========

// GET - Get all kelurahan
router.get('/kelurahan', (req, res) => {
    const metadata = readLayersMetadata();
    res.json({ success: true, data: metadata.kelurahan || [] });
});

// GET - Get specific kelurahan GeoJSON data
router.get('/kelurahan/:id/data', (req, res) => {
    const { id } = req.params;
    const metadata = readLayersMetadata();
    const kelurahan = metadata.kelurahan?.find(k => k.id === id);

    if (!kelurahan || !kelurahan.filename) {
        return res.json({ success: true, data: null });
    }

    try {
        const filepath = path.join(geojsonDir, kelurahan.filename);
        if (!fs.existsSync(filepath)) {
            return res.json({ success: true, data: null });
        }

        const geojsonData = JSON.parse(fs.readFileSync(filepath, 'utf8'));
        res.json({ success: true, data: geojsonData });
    } catch (e) {
        res.status(500).json({ success: false, error: 'Error reading GeoJSON file' });
    }
});

// POST - Upload kelurahan
router.post('/kelurahan', upload.single('file'), (req, res) => {
    const { name, color, kecamatanId } = req.body;

    if (!name) {
        return res.status(400).json({ success: false, error: 'Name is required' });
    }

    if (!kecamatanId) {
        return res.status(400).json({ success: false, error: 'Kecamatan ID is required' });
    }

    if (!req.file) {
        return res.status(400).json({ success: false, error: 'No file uploaded' });
    }

    // Verify kecamatan exists
    const metadata = readLayersMetadata();
    const kecamatanExists = metadata.kecamatan?.find(k => k.id === kecamatanId);
    if (!kecamatanExists) {
        fs.unlinkSync(req.file.path);
        return res.status(400).json({ success: false, error: 'Kecamatan not found' });
    }

    // Validate GeoJSON structure
    try {
        const content = fs.readFileSync(req.file.path, 'utf8');
        const geojson = JSON.parse(content);

        if (!geojson.type || !['FeatureCollection', 'Feature', 'GeometryCollection'].includes(geojson.type)) {
            fs.unlinkSync(req.file.path);
            return res.status(400).json({ success: false, error: 'Invalid GeoJSON structure' });
        }
    } catch (e) {
        if (fs.existsSync(req.file.path)) {
            fs.unlinkSync(req.file.path);
        }
        return res.status(400).json({ success: false, error: 'Invalid JSON format' });
    }

    const newKelurahan = {
        id: uuidv4(),
        name,
        kecamatanId,
        color: color || '#00FF00',
        filename: req.file.filename,
        uploadedAt: new Date().toISOString(),
        originalName: req.file.originalname
    };

    metadata.kelurahan = metadata.kelurahan || [];
    metadata.kelurahan.push(newKelurahan);
    writeLayersMetadata(metadata);

    res.json({
        success: true,
        message: 'Kelurahan berhasil ditambahkan',
        data: newKelurahan
    });
});

// DELETE - Remove kelurahan
router.delete('/kelurahan/:id', (req, res) => {
    const { id } = req.params;
    const metadata = readLayersMetadata();

    const kelurahan = metadata.kelurahan?.find(k => k.id === id);
    if (!kelurahan) {
        return res.status(404).json({ success: false, error: 'Kelurahan tidak ditemukan' });
    }

    // Delete file
    if (kelurahan.filename) {
        const filepath = path.join(geojsonDir, kelurahan.filename);
        if (fs.existsSync(filepath)) {
            fs.unlinkSync(filepath);
        }
    }

    // Remove from metadata
    metadata.kelurahan = metadata.kelurahan.filter(k => k.id !== id);
    writeLayersMetadata(metadata);

    res.json({ success: true, message: 'Kelurahan berhasil dihapus' });
});

module.exports = router;
