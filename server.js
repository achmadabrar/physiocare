// server.js - Main Express Server
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const mysql = require("mysql2/promise");
const dotenv = require("dotenv");
const multer = require("multer");
const path = require("path");
const { body, validationResult } = require("express-validator");

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));
app.use("/uploads", express.static("uploads"));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
});
app.use("/api/", limiter);

// Database connection pool
const pool = mysql.createPool({
  host: process.env.DB_HOST || "localhost",
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "physiohome",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  acquireTimeout: 60000,
  timeout: 60000,
});

// File upload configuration
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, "uploads/");
  },
  filename: function (req, file, cb) {
    cb(
      null,
      Date.now() +
        "-" +
        Math.round(Math.random() * 1e9) +
        path.extname(file.originalname)
    );
  },
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: function (req, file, cb) {
    if (file.mimetype.startsWith("image/")) {
      cb(null, true);
    } else {
      cb(new Error("Only image files are allowed!"), false);
    }
  },
});

// JWT middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    return res.status(401).json({ error: "Access token required" });
  }

  jwt.verify(
    token,
    process.env.JWT_SECRET || "your-secret-key",
    (err, user) => {
      if (err) {
        return res.status(403).json({ error: "Invalid token" });
      }
      req.user = user;
      next();
    }
  );
};

// Role-based authorization middleware
const authorize = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: "Insufficient permissions" });
    }
    next();
  };
};

// Validation middleware
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: "Validation failed",
      details: errors.array(),
    });
  }
  next();
};

// =============================================================================
// AUTH ROUTES
// =============================================================================

// User Registration
app.post(
  "/api/auth/register",
  [
    body("email").isEmail().normalizeEmail(),
    body("password").isLength({ min: 6 }),
    body("first_name").trim().isLength({ min: 2 }),
    body("last_name").trim().isLength({ min: 2 }),
    body("phone").isMobilePhone("id-ID"),
    body("role").isIn(["admin", "therapist", "patient"]),
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const {
        email,
        password,
        first_name,
        last_name,
        phone,
        role = "patient",
      } = req.body;

      // Check if user already exists
      const [existingUsers] = await pool.execute(
        "SELECT id FROM users WHERE email = ?",
        [email]
      );

      if (existingUsers.length > 0) {
        return res.status(409).json({ error: "User already exists" });
      }

      // Hash password
      const hashedPassword = await bcrypt.hash(password, 12);

      // Create user
      const [result] = await pool.execute(
        `INSERT INTO users (email, password, first_name, last_name, phone, role, created_at) 
       VALUES (?, ?, ?, ?, ?, ?, NOW())`,
        [email, hashedPassword, first_name, last_name, phone, role]
      );

      // Generate JWT token
      const token = jwt.sign(
        {
          userId: result.insertId,
          email,
          role,
          firstName: first_name,
          lastName: last_name,
        },
        process.env.JWT_SECRET || "your-secret-key",
        { expiresIn: "24h" }
      );

      res.status(201).json({
        message: "User registered successfully",
        token,
        user: {
          id: result.insertId,
          email,
          firstName: first_name,
          lastName: last_name,
          phone,
          role,
        },
      });
    } catch (error) {
      console.error("Registration error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }
);

// User Login
app.post(
  "/api/auth/login",
  [body("email").isEmail().normalizeEmail(), body("password").notEmpty()],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { email, password } = req.body;

      // Find user
      const [users] = await pool.execute(
        "SELECT * FROM users WHERE email = ?",
        [email]
      );

      if (users.length === 0) {
        return res.status(401).json({ error: "Invalid credentials" });
      }

      const user = users[0];

      // Verify password
      const isPasswordValid = await bcrypt.compare(password, user.password);
      if (!isPasswordValid) {
        return res.status(401).json({ error: "Invalid credentials" });
      }

      // Update last login
      await pool.execute("UPDATE users SET last_login = NOW() WHERE id = ?", [
        user.id,
      ]);

      // Generate JWT token
      const token = jwt.sign(
        {
          userId: user.id,
          email: user.email,
          role: user.role,
          firstName: user.first_name,
          lastName: user.last_name,
        },
        process.env.JWT_SECRET || "your-secret-key",
        { expiresIn: "24h" }
      );

      res.json({
        message: "Login successful",
        token,
        user: {
          id: user.id,
          email: user.email,
          firstName: user.first_name,
          lastName: user.last_name,
          phone: user.phone,
          role: user.role,
        },
      });
    } catch (error) {
      console.error("Login error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }
);

// Get Current User Profile
app.get("/api/auth/profile", authenticateToken, async (req, res) => {
  try {
    const [users] = await pool.execute(
      "SELECT id, email, first_name, last_name, phone, role, created_at, last_login FROM users WHERE id = ?",
      [req.user.userId]
    );

    if (users.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    res.json({ user: users[0] });
  } catch (error) {
    console.error("Profile error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// =============================================================================
// THERAPIST ROUTES
// =============================================================================

// Get all therapists
app.get("/api/therapists", async (req, res) => {
  try {
    const [therapists] = await pool.execute(`
      SELECT u.id, u.first_name, u.last_name, u.email, u.phone,
             t.specialization, t.license_number, t.experience_years,
             t.bio, t.profile_image, t.hourly_rate
      FROM users u
      LEFT JOIN therapists t ON u.id = t.user_id
      WHERE u.role = 'therapist' AND u.is_active = 1
    `);

    res.json({ therapists });
  } catch (error) {
    console.error("Get therapists error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Create/Update therapist profile
app.post(
  "/api/therapists/profile",
  authenticateToken,
  authorize("therapist", "admin"),
  upload.single("profile_image"),
  [
    body("specialization").trim().notEmpty(),
    body("license_number").trim().notEmpty(),
    body("experience_years").isInt({ min: 0 }),
    body("hourly_rate").isFloat({ min: 0 }),
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const {
        specialization,
        license_number,
        experience_years,
        bio,
        hourly_rate,
      } = req.body;
      const userId = req.user.userId;
      const profileImage = req.file ? req.file.filename : null;

      // Check if therapist profile exists
      const [existing] = await pool.execute(
        "SELECT id FROM therapists WHERE user_id = ?",
        [userId]
      );

      if (existing.length > 0) {
        // Update existing profile
        await pool.execute(
          `
        UPDATE therapists SET 
          specialization = ?, license_number = ?, experience_years = ?, 
          bio = ?, hourly_rate = ?, profile_image = COALESCE(?, profile_image),
          updated_at = NOW()
        WHERE user_id = ?
      `,
          [
            specialization,
            license_number,
            experience_years,
            bio,
            hourly_rate,
            profileImage,
            userId,
          ]
        );
      } else {
        // Create new profile
        await pool.execute(
          `
        INSERT INTO therapists (user_id, specialization, license_number, experience_years, bio, hourly_rate, profile_image, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
      `,
          [
            userId,
            specialization,
            license_number,
            experience_years,
            bio,
            hourly_rate,
            profileImage,
          ]
        );
      }

      res.json({ message: "Therapist profile updated successfully" });
    } catch (error) {
      console.error("Update therapist profile error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }
);

// =============================================================================
// APPOINTMENT ROUTES
// =============================================================================

// Create new appointment
app.post(
  "/api/appointments",
  authenticateToken,
  [
    body("therapist_id").isInt(),
    body("appointment_date").isISO8601(),
    body("appointment_time").matches(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/),
    body("service_type").trim().notEmpty(),
    body("address").trim().notEmpty(),
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const {
        therapist_id,
        appointment_date,
        appointment_time,
        service_type,
        notes,
        address,
      } = req.body;
      const patient_id = req.user.userId;

      // Check if therapist exists
      const [therapist] = await pool.execute(
        'SELECT id FROM users WHERE id = ? AND role = "therapist" AND is_active = 1',
        [therapist_id]
      );

      if (therapist.length === 0) {
        return res.status(404).json({ error: "Therapist not found" });
      }

      // Check for scheduling conflicts
      const [conflicts] = await pool.execute(
        `
      SELECT id FROM appointments 
      WHERE therapist_id = ? AND appointment_date = ? AND appointment_time = ? 
      AND status NOT IN ('cancelled', 'completed')
    `,
        [therapist_id, appointment_date, appointment_time]
      );

      if (conflicts.length > 0) {
        return res.status(409).json({ error: "Time slot already booked" });
      }

      // Create appointment
      const [result] = await pool.execute(
        `
      INSERT INTO appointments (patient_id, therapist_id, appointment_date, appointment_time, 
                               service_type, notes, patient_address, status, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'scheduled', NOW())
    `,
        [
          patient_id,
          therapist_id,
          appointment_date,
          appointment_time,
          service_type,
          notes,
          address,
        ]
      );

      res.status(201).json({
        message: "Appointment booked successfully",
        appointmentId: result.insertId,
      });
    } catch (error) {
      console.error("Create appointment error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }
);

// Get appointments
app.get("/api/appointments", authenticateToken, async (req, res) => {
  try {
    const { status, date, limit = 50 } = req.query;
    let query = `
      SELECT a.*, 
             p.first_name as patient_first_name, p.last_name as patient_last_name, p.phone as patient_phone,
             t.first_name as therapist_first_name, t.last_name as therapist_last_name, t.phone as therapist_phone,
             th.specialization
      FROM appointments a
      LEFT JOIN users p ON a.patient_id = p.id
      LEFT JOIN users t ON a.therapist_id = t.id
      LEFT JOIN therapists th ON t.id = th.user_id
    `;

    const params = [];
    const conditions = [];

    // Role-based filtering
    if (req.user.role === "patient") {
      conditions.push("a.patient_id = ?");
      params.push(req.user.userId);
    } else if (req.user.role === "therapist") {
      conditions.push("a.therapist_id = ?");
      params.push(req.user.userId);
    }

    // Additional filters
    if (status) {
      conditions.push("a.status = ?");
      params.push(status);
    }

    if (date) {
      conditions.push("a.appointment_date = ?");
      params.push(date);
    }

    if (conditions.length > 0) {
      query += " WHERE " + conditions.join(" AND ");
    }

    query +=
      " ORDER BY a.appointment_date DESC, a.appointment_time DESC LIMIT ?";
    params.push(parseInt(limit));

    const [appointments] = await pool.execute(query, params);

    res.json({ appointments });
  } catch (error) {
    console.error("Get appointments error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Update appointment status
app.put(
  "/api/appointments/:id/status",
  authenticateToken,
  [
    body("status").isIn([
      "scheduled",
      "confirmed",
      "in_progress",
      "completed",
      "cancelled",
    ]),
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { id } = req.params;
      const { status, notes } = req.body;

      // Check appointment exists and user has permission
      const [appointments] = await pool.execute(
        `
      SELECT * FROM appointments 
      WHERE id = ? AND (patient_id = ? OR therapist_id = ? OR ? = 'admin')
    `,
        [id, req.user.userId, req.user.userId, req.user.role]
      );

      if (appointments.length === 0) {
        return res.status(404).json({ error: "Appointment not found" });
      }

      // Update appointment
      await pool.execute(
        `
      UPDATE appointments SET status = ?, notes = COALESCE(?, notes), updated_at = NOW()
      WHERE id = ?
    `,
        [status, notes, id]
      );

      res.json({ message: "Appointment status updated successfully" });
    } catch (error) {
      console.error("Update appointment status error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }
);

// =============================================================================
// DASHBOARD ROUTES
// =============================================================================

// Get dashboard statistics
app.get(
  "/api/dashboard/stats",
  authenticateToken,
  authorize("admin", "therapist"),
  async (req, res) => {
    try {
      const today = new Date().toISOString().split("T")[0];

      // Today's appointments
      const [todayAppointments] = await pool.execute(
        "SELECT COUNT(*) as count FROM appointments WHERE appointment_date = ?",
        [today]
      );

      // Completed sessions today
      const [completedToday] = await pool.execute(
        'SELECT COUNT(*) as count FROM appointments WHERE appointment_date = ? AND status = "completed"',
        [today]
      );

      // Pending appointments
      const [pending] = await pool.execute(
        'SELECT COUNT(*) as count FROM appointments WHERE status = "scheduled"'
      );

      // Total revenue today (mock calculation)
      const [revenueToday] = await pool.execute(
        `
      SELECT SUM(th.hourly_rate) as revenue FROM appointments a
      LEFT JOIN therapists th ON a.therapist_id = th.user_id
      WHERE a.appointment_date = ? AND a.status = "completed"
    `,
        [today]
      );

      res.json({
        stats: {
          todayAppointments: todayAppointments[0].count,
          completedToday: completedToday[0].count,
          pending: pending[0].count,
          revenueToday: revenueToday[0].revenue || 0,
        },
      });
    } catch (error) {
      console.error("Dashboard stats error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }
);

// Get recent activities
app.get(
  "/api/dashboard/activities",
  authenticateToken,
  authorize("admin"),
  async (req, res) => {
    try {
      const [activities] = await pool.execute(`
      SELECT 
        a.id,
        a.status,
        a.appointment_date,
        a.appointment_time,
        a.created_at,
        a.updated_at,
        CONCAT(p.first_name, ' ', p.last_name) as patient_name,
        CONCAT(t.first_name, ' ', t.last_name) as therapist_name,
        a.service_type
      FROM appointments a
      LEFT JOIN users p ON a.patient_id = p.id
      LEFT JOIN users t ON a.therapist_id = t.id
      ORDER BY a.updated_at DESC
      LIMIT 10
    `);

      res.json({ activities });
    } catch (error) {
      console.error("Dashboard activities error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }
);

// =============================================================================
// PATIENT ROUTES
// =============================================================================

// Get all patients (for admin/therapist)
app.get(
  "/api/patients",
  authenticateToken,
  authorize("admin", "therapist"),
  async (req, res) => {
    try {
      const [patients] = await pool.execute(`
      SELECT u.id, u.first_name, u.last_name, u.email, u.phone, u.created_at,
             COUNT(a.id) as total_appointments
      FROM users u
      LEFT JOIN appointments a ON u.id = a.patient_id
      WHERE u.role = 'patient' AND u.is_active = 1
      GROUP BY u.id
      ORDER BY u.created_at DESC
    `);

      res.json({ patients });
    } catch (error) {
      console.error("Get patients error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }
);

// =============================================================================
// ERROR HANDLING
// =============================================================================

// 404 handler
app.use("*", (req, res) => {
  res.status(404).json({ error: "Route not found" });
});

// Global error handler
app.use((error, req, res, next) => {
  console.error("Global error:", error);

  if (error instanceof multer.MulterError) {
    if (error.code === "LIMIT_FILE_SIZE") {
      return res.status(400).json({ error: "File too large" });
    }
  }

  res.status(500).json({ error: "Internal server error" });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || "development"}`);
});

module.exports = app;
