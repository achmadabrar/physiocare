-- database.sql - Complete PhysioHome Database Schema

-- Create database
CREATE DATABASE IF NOT EXISTS physiohome CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE physiohome;

-- =============================================================================
-- USERS TABLE
-- =============================================================================
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    role ENUM('admin', 'therapist', 'patient') NOT NULL DEFAULT 'patient',
    is_active BOOLEAN DEFAULT TRUE,
    email_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    
    INDEX idx_email (email),
    INDEX idx_role (role),
    INDEX idx_active (is_active)
);

-- =============================================================================
-- THERAPISTS TABLE (Extended profile for therapist users)
-- =============================================================================
CREATE TABLE therapists (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT UNIQUE NOT NULL,
    specialization VARCHAR(255) NOT NULL,
    license_number VARCHAR(100) UNIQUE NOT NULL,
    experience_years INT NOT NULL DEFAULT 0,
    bio TEXT,
    profile_image VARCHAR(255),
    hourly_rate DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    rating DECIMAL(3, 2) DEFAULT 0.00,
    total_reviews INT DEFAULT 0,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_specialization (specialization),
    INDEX idx_available (is_available),
    INDEX idx_rating (rating)
);

-- =============================================================================
-- PATIENTS TABLE (Extended profile for patient users)
-- =============================================================================
CREATE TABLE patients (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT UNIQUE NOT NULL,
    date_of_birth DATE,
    gender ENUM('male', 'female', 'other'),
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    medical_history TEXT,
    allergies TEXT,
    current_medications TEXT,
    insurance_provider VARCHAR(100),
    insurance_number VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_gender (gender)
);

-- =============================================================================
-- APPOINTMENTS TABLE
-- =============================================================================
CREATE TABLE appointments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    patient_id INT NOT NULL,
    therapist_id INT NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    service_type VARCHAR(100) NOT NULL,
    status ENUM('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show') DEFAULT 'scheduled',
    duration_minutes INT DEFAULT 60,
    notes TEXT,
    patient_address TEXT NOT NULL,
    therapist_notes TEXT,
    total_cost DECIMAL(10, 2),
    payment_status ENUM('pending', 'paid', 'refunded', 'cancelled') DEFAULT 'pending',
    cancellation_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (therapist_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_patient_id (patient_id),
    INDEX idx_therapist_id (therapist_id),
    INDEX idx_appointment_date (appointment_date),
    INDEX idx_status (status),
    INDEX idx_payment_status (payment_status),
    UNIQUE KEY unique_appointment (therapist_id, appointment_date, appointment_time)
);

-- =============================================================================
-- SERVICES TABLE
-- =============================================================================
CREATE TABLE services (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(100) NOT NULL,
    base_price DECIMAL(10, 2) NOT NULL,
    duration_minutes INT DEFAULT 60,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_category (category),
    INDEX idx_active (is_active)
);

-- =============================================================================
-- THERAPIST SERVICES (Many-to-Many relationship)
-- =============================================================================
CREATE TABLE therapist_services (
    id INT PRIMARY KEY AUTO_INCREMENT,
    therapist_id INT NOT NULL,
    service_id INT NOT NULL,
    custom_price DECIMAL(10, 2),
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (therapist_id) REFERENCES therapists(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
    UNIQUE KEY unique_therapist_service (therapist_id, service_id)
);

-- =============================================================================
-- REVIEWS TABLE
-- =============================================================================
CREATE TABLE reviews (
    id INT PRIMARY KEY AUTO_INCREMENT,
    appointment_id INT UNIQUE NOT NULL,
    patient_id INT NOT NULL,
    therapist_id INT NOT NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    is_anonymous BOOLEAN DEFAULT FALSE,
    is_approved BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE,
    FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (therapist_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_therapist_rating (therapist_id, rating),
    INDEX idx_approved (is_approved)
);

-- =============================================================================
-- PAYMENTS TABLE
-- =============================================================================
CREATE TABLE payments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    appointment_id INT NOT NULL,
    patient_id INT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    payment_status ENUM('pending', 'processing', 'completed', 'failed', 'refunded') DEFAULT 'pending',
    transaction_id VARCHAR(255),
    gateway_response TEXT,
    paid_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE,
    FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_appointment_id (appointment_id),
    INDEX idx_patient_id (patient_id),
    INDEX idx_status (payment_status),
    INDEX idx_transaction_id (transaction_id)
);

-- =============================================================================
-- NOTIFICATIONS TABLE
-- =============================================================================
CREATE TABLE notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    related_id INT NULL, -- Could reference appointment_id, payment_id, etc.
    related_type VARCHAR(50) NULL, -- 'appointment', 'payment', etc.
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP NULL,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_unread (user_id, is_read),
    INDEX idx_type (type)
);

-- =============================================================================
-- AVAILABILITY TABLE (Therapist working hours)
-- =============================================================================
CREATE TABLE therapist_availability (
    id INT PRIMARY KEY AUTO_INCREMENT,
    therapist_id INT NOT NULL,
    day_of_week TINYINT NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0=Sunday, 6=Saturday
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (therapist_id) REFERENCES therapists(id) ON DELETE CASCADE,
    INDEX idx_therapist_day (therapist_id, day_of_week),
    UNIQUE KEY unique_therapist_day_time (therapist_id, day_of_week, start_time, end_time)
);

-- =============================================================================
-- SYSTEM SETTINGS TABLE
-- =============================================================================
CREATE TABLE system_settings (
    id INT PRIMARY KEY AUTO_INCREMENT,
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT,
    setting_type VARCHAR(50) DEFAULT 'string',
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_key (setting_key),
    INDEX idx_public (is_public)
);

-- =============================================================================
-- AUDIT LOG TABLE (For tracking important changes)
-- =============================================================================
CREATE TABLE audit_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id INT,
    old_values JSON,
    new_values JSON,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_action (user_id, action),
    INDEX idx_table_record (table_name, record_id),
    INDEX idx_created_at (created_at)
);

-- =============================================================================
-- INSERT DEFAULT DATA
-- =============================================================================

-- Insert default admin user
INSERT INTO users (email, password, first_name, last_name, phone, role, is_active, email_verified) VALUES
('admin@physiohome.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewFCh8CCCNbgHtKO', 'Admin', 'PhysioHome', '+6281234567890', 'admin', TRUE, TRUE);
-- Password: admin123

-- Insert sample services
INSERT INTO services (name, description, category, base_price, duration_minutes) VALUES
('Fisioterapi Ortopedi', 'Terapi untuk masalah tulang, otot, dan sendi', 'Ortopedi', 200000.00, 60),
('Fisioterapi Neurologi', 'Terapi untuk gangguan sistem saraf', 'Neurologi', 250000.00, 60),
('Fisioterapi Kardiopulmoner', 'Terapi untuk masalah jantung dan paru-paru', 'Kardiopulmoner', 220000.00, 60),
('Fisioterapi Pediatri', 'Terapi khusus untuk anak-anak', 'Pediatri', 180000.00, 45),
('Fisioterapi Geriatri', 'Terapi khusus untuk lansia', 'Geriatri', 190000.00, 60),
('Fisioterapi Olahraga', 'Terapi untuk cedera dan pemulihan olahraga', 'Olahraga', 240000.00, 60);

-- Insert sample therapists
INSERT INTO users (email, password, first_name, last_name, phone, role, is_active, email_verified) VALUES
('sarah.wijaya@physiohome.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewFCh8CCCNbgHtKO', 'Sarah', 'Wijaya', '+6281234567891', 'therapist', TRUE, TRUE),
('ahmad.rizki@physiohome.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewFCh8CCCNbgHtKO', 'Ahmad', 'Rizki', '+6281234567892', 'therapist', TRUE, TRUE),
('maya.sari@physiohome.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewFCh8CCCNbgHtKO', 'Maya', 'Sari', '+6281234567893', 'therapist', TRUE, TRUE),
('budi.santoso@physiohome.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewFCh8CCCNbgHtKO', 'Budi', 'Santoso', '+6281234567894', 'therapist', TRUE, TRUE);

-- Insert therapist profiles (assuming user IDs 2-5 for the therapists above)
INSERT INTO therapists (user_id, specialization, license_number, experience_years, bio, hourly_rate, rating, total_reviews) VALUES
(2, 'Ortopedi & Olahraga', 'FT001234', 8, 'Spesialis fisioterapi ortopedi dengan pengalaman 8 tahun menangani cedera olahraga dan gangguan muskuloskeletal.', 200000.00, 4.8, 125),
(3, 'Neurologi & Stroke', 'FT001235', 6, 'Ahli fisioterapi neurologi dengan fokus pada rehabilitasi stroke dan gangguan sistem saraf.', 250000.00, 4.9, 98),
(4, 'Pediatri & Geriatri', 'FT001236', 5, 'Spesialis fisioterapi untuk anak-anak dan lansia dengan pendekatan yang patient dan komprehensif.', 180000.00, 4.7, 87),
(5, 'Kardiopulmoner', 'FT001237', 7, 'Fisioterapis berpengalaman dalam rehabilitasi jantung dan paru-paru.', 220000.00, 4.6, 76);

-- Insert sample patients
INSERT INTO users (email, password, first_name, last_name, phone, role, is_active, email_verified) VALUES
('john.doe@email.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewFCh8CCCNbgHtKO', 'John', 'Doe', '+6281234567895', 'patient', TRUE, TRUE),
('anna.smith@email.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewFCh8CCCNbgHtKO', 'Anna', 'Smith', '+6281234567896', 'patient', TRUE, TRUE),
('michael.brown@email.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewFCh8CCCNbgHtKO', 'Michael', 'Brown', '+6281234567897', 'patient', TRUE, TRUE);

-- Insert therapist services (linking therapists to services they provide)
INSERT INTO therapist_services (therapist_id, service_id, custom_price) VALUES
(1, 1, 200000.00), -- Sarah - Ortopedi
(1, 6, 240000.00), -- Sarah - Olahraga
(2, 2, 250000.00), -- Ahmad - Neurologi
(3, 4, 180000.00), -- Maya - Pediatri
(3, 5, 190000.00), -- Maya - Geriatri
(4, 3, 220000.00); -- Budi - Kardiopulmoner

-- Insert therapist availability (sample working hours)
INSERT INTO therapist_availability (therapist_id, day_of_week, start_time, end_time) VALUES
-- Sarah Wijaya (therapist_id = 1)
(1, 1, '08:00:00', '17:00:00'), -- Monday
(1, 2, '08:00:00', '17:00:00'), -- Tuesday
(1, 3, '08:00:00', '17:00:00'), -- Wednesday
(1, 4, '08:00:00', '17:00:00'), -- Thursday
(1, 5, '08:00:00', '17:00:00'), -- Friday
(1, 6, '08:00:00', '14:00:00'), -- Saturday

-- Ahmad Rizki (therapist_id = 2)
(2, 1, '09:00:00', '18:00:00'), -- Monday
(2, 2, '09:00:00', '18:00:00'), -- Tuesday
(2, 3, '09:00:00', '18:00:00'), -- Wednesday
(2, 4, '09:00:00', '18:00:00'), -- Thursday
(2, 5, '09:00:00', '18:00:00'), -- Friday

-- Maya Sari (therapist_id = 3)
(3, 1, '08:00:00', '16:00:00'), -- Monday
(3, 2, '08:00:00', '16:00:00'), -- Tuesday
(3, 3, '08:00:00', '16:00:00'), -- Wednesday
(3, 4, '08:00:00', '16:00:00'), -- Thursday
(3, 5, '08:00:00', '16:00:00'), -- Friday
(3, 6, '08:00:00', '12:00:00'), -- Saturday

-- Budi Santoso (therapist_id = 4)
(4, 1, '07:00:00', '15:00:00'), -- Monday
(4, 2, '07:00:00', '15:00:00'), -- Tuesday
(4, 3, '07:00:00', '15:00:00'), -- Wednesday
(4, 4, '07:00:00', '15:00:00'), -- Thursday
(4, 5, '07:00:00', '15:00:00'), -- Friday
(4, 6, '07:00:00', '13:00:00'), -- Saturday
(4, 0, '08:00:00', '12:00:00'); -- Sunday

-- Insert sample appointments
INSERT INTO appointments (patient_id, therapist_id, appointment_date, appointment_time, service_type, status, notes, patient_address, total_cost, payment_status) VALUES
(6, 2, CURDATE(), '09:00:00', 'Ortopedi', 'in_progress', 'Nyeri punggung bawah', 'Jl. Sudirman No. 123, Jakarta Pusat', 200000.00, 'paid'),
(7, 3, CURDATE(), '10:00:00', 'Neurologi', 'scheduled', 'Rehabilitasi pasca stroke', 'Jl. Thamrin No. 456, Jakarta Pusat', 250000.00, 'pending'),
(8, 4, CURDATE(), '11:00:00', 'Pediatri', 'scheduled', 'Terapi perkembangan anak', 'Jl. Gatot Subroto No. 789, Jakarta Selatan', 180000.00, 'pending');

-- Insert sample system settings
INSERT INTO system_settings (setting_key, setting_value, setting_type, description, is_public) VALUES
('app_name', 'PhysioHome', 'string', 'Application name', TRUE),
('company_phone', '+62812-3456-7890', 'string', 'Company contact phone', TRUE),
('company_email', 'info@physiohome.id', 'string', 'Company contact email', TRUE),
('company_address', 'Jakarta, Indonesia', 'string', 'Company address', TRUE),
('default_appointment_duration', '60', 'integer', 'Default appointment duration in minutes', FALSE),
('max_appointments_per_day', '10', 'integer', 'Maximum appointments per therapist per day', FALSE),
('booking_advance_days', '30', 'integer', 'How many days in advance can appointments be booked', FALSE),
('cancellation_hours', '24', 'integer', 'Minimum hours before appointment for cancellation', FALSE),
('service_area', 'Jakarta, Bogor, Depok, Tangerang, Bekasi', 'string', 'Service coverage area', TRUE);

-- =============================================================================
-- CREATE VIEWS FOR COMMON QUERIES
-- =============================================================================

-- View for appointment details with all related information
CREATE VIEW appointment_details AS
SELECT 
    a.id,
    a.appointment_date,
    a.appointment_time,
    a.service_type,
    a.status,
    a.duration_minutes,
    a.notes,
    a.therapist_notes,
    a.patient_address,
    a.total_cost,
    a.payment_status,
    a.created_at,
    a.updated_at,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    p.email AS patient_email,
    p.phone AS patient_phone,
    CONCAT(t.first_name, ' ', t.last_name) AS therapist_name,
    t.email AS therapist_email,
    t.phone AS therapist_phone,
    th.specialization,
    th.hourly_rate,
    s.name AS service_name,
    s.description AS service_description
FROM appointments a
LEFT JOIN users p ON a.patient_id = p.id
LEFT JOIN users t ON a.therapist_id = t.id  
LEFT JOIN therapists th ON t.id = th.user_id
LEFT JOIN services s ON a.service_type = s.category;

-- View for therapist statistics
CREATE VIEW therapist_stats AS
SELECT 
    t.id AS therapist_id,
    CONCAT(u.first_name, ' ', u.last_name) AS therapist_name,
    t.specialization,
    t.rating,
    t.total_reviews,
    COUNT(a.id) AS total_appointments,
    COUNT(CASE WHEN a.status = 'completed' THEN 1 END) AS completed_appointments,
    COUNT(CASE WHEN a.status = 'cancelled' THEN 1 END) AS cancelled_appointments,
    AVG(CASE WHEN a.status = 'completed' THEN a.total_cost END) AS avg_appointment_cost,
    SUM(CASE WHEN a.status = 'completed' THEN a.total_cost ELSE 0 END) AS total_revenue
FROM therapists t
LEFT JOIN users u ON t.user_id = u.id
LEFT JOIN appointments a ON u.id = a.therapist_id
GROUP BY t.id, u.first_name, u.last_name, t.specialization, t.rating, t.total_reviews;

-- =============================================================================
-- CREATE STORED PROCEDURES
-- =============================================================================

DELIMITER //

-- Procedure to update therapist rating after a review
CREATE PROCEDURE UpdateTherapistRating(IN therapist_user_id INT)
BEGIN
    DECLARE avg_rating DECIMAL(3,2);
    DECLARE review_count INT;
    
    SELECT AVG(rating), COUNT(*) 
    INTO avg_rating, review_count
    FROM reviews 
    WHERE therapist_id = therapist_user_id AND is_approved = TRUE;
    
    UPDATE therapists 
    SET rating = COALESCE(avg_rating, 0.00), 
        total_reviews = COALESCE(review_count, 0)
    WHERE user_id = therapist_user_id;
END //

-- Procedure to get available time slots for a therapist on a specific date
CREATE PROCEDURE GetAvailableTimeSlots(
    IN therapist_user_id INT, 
    IN appointment_date DATE
)
BEGIN
    DECLARE day_of_week INT;
    SET day_of_week = DAYOFWEEK(appointment_date) - 1; -- Convert to 0=Sunday format
    
    SELECT 
        ta.start_time,
        ta.end_time,
        TIME(ta.start_time) AS slot_time
    FROM therapist_availability ta
    WHERE ta.therapist_id = (
        SELECT id FROM therapists WHERE user_id = therapist_user_id
    )
    AND ta.day_of_week = day_of_week
    AND ta.is_available = TRUE
    AND TIME(ta.start_time) NOT IN (
        SELECT TIME(a.appointment_time)
        FROM appointments a
        WHERE a.therapist_id = therapist_user_id
        AND a.appointment_date = appointment_date
        AND a.status NOT IN ('cancelled', 'completed')
    )
    ORDER BY ta.start_time;
END //

DELIMITER ;

-- =============================================================================
-- CREATE TRIGGERS
-- =============================================================================

DELIMITER //

-- Trigger to automatically update appointment total cost
CREATE TRIGGER calculate_appointment_cost
BEFORE INSERT ON appointments
FOR EACH ROW
BEGIN
    DECLARE therapist_rate DECIMAL(10,2);
    
    SELECT hourly_rate INTO therapist_rate
    FROM therapists t
    JOIN users u ON t.user_id = u.id
    WHERE u.id = NEW.therapist_id;
    
    IF NEW.total_cost IS NULL THEN
        SET NEW.total_cost = therapist_rate * (NEW.duration_minutes / 60);
    END IF;
END //

-- Trigger to log appointment status changes
CREATE TRIGGER log_appointment_changes
AFTER UPDATE ON appointments
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values, created_at)
        VALUES (
            NEW.patient_id,
            'status_change',
            'appointments',
            NEW.id,
            JSON_OBJECT('status', OLD.status),
            JSON_OBJECT('status', NEW.status),
            NOW()
        );
    END IF;
END //

-- Trigger to create notification on appointment creation
CREATE TRIGGER create_appointment_notification
AFTER INSERT ON appointments
FOR EACH ROW
BEGIN
    -- Notify therapist
    INSERT INTO notifications (user_id, title, message, type, related_id, related_type)
    VALUES (
        NEW.therapist_id,
        'Appointment Baru',
        CONCAT('Anda memiliki appointment baru pada ', DATE_FORMAT(NEW.appointment_date, '%d/%m/%Y'), ' jam ', TIME_FORMAT(NEW.appointment_time, '%H:%i')),
        'appointment',
        NEW.id,
        'appointment'
    );
    
    -- Notify patient
    INSERT INTO notifications (user_id, title, message, type, related_id, related_type)
    VALUES (
        NEW.patient_id,
        'Appointment Terkonfirmasi',
        CONCAT('Appointment Anda telah terjadwal pada ', DATE_FORMAT(NEW.appointment_date, '%d/%m/%Y'), ' jam ', TIME_FORMAT(NEW.appointment_time, '%H:%i')),
        'appointment',
        NEW.id,
        'appointment'
    );
END //

DELIMITER ;

-- =============================================================================
-- CREATE INDEXES FOR PERFORMANCE
-- =============================================================================

-- Additional indexes for better query performance
CREATE INDEX idx_appointments_date_status ON appointments(appointment_date, status);
CREATE INDEX idx_appointments_therapist_date ON appointments(therapist_id, appointment_date);
CREATE INDEX idx_users_role_active ON users(role, is_active);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read, created_at);
CREATE INDEX idx_reviews_therapist_approved ON reviews(therapist_id, is_approved, rating);

-- Full-text search indexes
ALTER TABLE therapists ADD FULLTEXT(specialization, bio);
ALTER TABLE services ADD FULLTEXT(name, description);

-- =============================================================================
-- SAMPLE DATA COMPLETION MESSAGE
-- =============================================================================

SELECT 'Database schema created successfully!' AS status;
SELECT 'Sample data inserted successfully!' AS status;
SELECT CONCAT('Total users created: ', COUNT(*)) AS users_count FROM users;
SELECT CONCAT('Total therapists created: ', COUNT(*)) AS therapists_count FROM therapists;
SELECT CONCAT('Total services created: ', COUNT(*)) AS services_count FROM services;
SELECT CONCAT('Total appointments created: ', COUNT(*)) AS appointments_count FROM appointments;