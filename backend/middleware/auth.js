const jwt = require('jsonwebtoken');

// Secret key for JWT (in production, use environment variable)
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

// Middleware to verify JWT token
const authenticateToken = (req, res, next) => {
    // Get token from header
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
        return res.status(401).json({
            success: false,
            error: 'Access denied. No token provided.'
        });
    }

    try {
        // Verify token
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        next();
    } catch (error) {
        return res.status(403).json({
            success: false,
            error: 'Invalid or expired token.'
        });
    }
};

// Generate JWT token
const generateToken = (user) => {
    return jwt.sign(
        {
            username: user.username,
            role: user.role
        },
        JWT_SECRET,
        { expiresIn: '24h' } // Token expires in 24 hours
    );
};

module.exports = {
    authenticateToken,
    generateToken,
    JWT_SECRET
};
