-- El_Hardouz_Ali_final_queries.sql
-- Test & example queries for the `clinic` database
-- Run these in order (or pick ones you want). Comments explain intent and expected results.

-- 0) Quick sanity checks
-- List tables
SHOW TABLES;

-- Describe a core table
DESCRIBE patient;

-- Count rows per main table
SELECT 'insurance_plan' AS table_name, COUNT(*) AS cnt FROM insurance_plan
UNION ALL
SELECT 'patient', COUNT(*) FROM patient
UNION ALL
SELECT 'doctor', COUNT(*) FROM doctor
UNION ALL
SELECT 'appointment', COUNT(*) FROM appointment
UNION ALL
SELECT 'billing', COUNT(*) FROM billing;

-- 1) Selects / Joins
-- Upcoming appointments (next 7 days)
SELECT a.appt_id, p.full_name AS patient, d.full_name AS doctor, a.starts_at, a.ends_at, a.status
FROM appointment a
JOIN patient p ON p.patient_id = a.patient_id
JOIN doctor d ON d.doctor_id = a.doctor_id
WHERE a.starts_at >= NOW() AND a.starts_at < DATE_ADD(NOW(), INTERVAL 7 DAY)
ORDER BY a.starts_at;

-- Appointments with room details
SELECT a.appt_id, p.full_name, d.full_name, r.room_name, a.starts_at, a.ends_at
FROM appointment a
JOIN appointment_room ar ON a.appt_id = ar.appt_id
JOIN clinic_room r ON r.room_id = ar.room_id
JOIN patient p ON p.patient_id = a.patient_id
JOIN doctor d ON d.doctor_id = a.doctor_id
ORDER BY a.starts_at LIMIT 20;

-- Patients with no insurance plan assigned
SELECT patient_id, full_name FROM patient WHERE plan_id IS NULL;

-- Doctors with zero appointments (useful to check staffing)
SELECT d.doctor_id, d.full_name
FROM doctor d
LEFT JOIN appointment a ON a.doctor_id = d.doctor_id
WHERE a.appt_id IS NULL;

-- 2) Aggregation tests (use the views added in the schema file)
-- Total billed per patient (use the view or raw query)
SELECT * FROM vw_billing_per_patient ORDER BY total_billed DESC LIMIT 10;

-- Doctors ranked by total billing (window function example)
SELECT doctor_id, full_name, total_billed,
       RANK() OVER (ORDER BY total_billed DESC) AS billing_rank
FROM vw_billing_per_doctor;

-- Average appointment duration per doctor (from view)
SELECT * FROM vw_avg_appt_duration_per_doctor ORDER BY avg_duration_min DESC;

-- Medication prescription counts
SELECT * FROM vw_prescriptions_per_medication ORDER BY prescriptions_count DESC;

-- Room utilization
SELECT * FROM vw_room_utilization ORDER BY appointments_count DESC;

-- Patients count per plan
SELECT * FROM vw_patients_per_plan;

-- Lab tests summary
SELECT * FROM vw_lab_tests_by_status;

-- 3) Constraint & validation tests (these may error if constraints work)
-- (A) Try inserting a billing with negative amount (should fail because of CHECK)
-- INSERT INTO billing (bill_id, appt_id, amount, payment_status, payment_method, billing_date)
-- VALUES (9999, 101, -1.00, 'unpaid', 'cash', CURDATE());

-- (B) Try inserting a patient with future DOB (should fail because of check)
-- INSERT INTO patient (patient_id, full_name, dob) VALUES (9999, 'Future Person', DATE_ADD(CURDATE(), INTERVAL 1 DAY));

-- (C) Try inserting prescription with invalid route (should fail if check applies)
-- INSERT INTO prescription (rx_id, appt_id, variant_id, route) VALUES (9999, 101, 1, 'invalid-route');

-- 4) Transactional scenarios - Safe update then commit/rollback
-- Example: mark an unpaid billing as paid in a transaction (demo)
-- (You can run step-by-step in client to test rollback behavior)
-- START TRANSACTION;
-- UPDATE billing SET payment_status = 'paid', payment_method = 'card' WHERE bill_id = 2002;
-- SELECT * FROM billing WHERE bill_id = 2002; -- verify
-- ROLLBACK; -- or COMMIT;

-- 5) More advanced checks / edge-cases
-- a) Find overlapping appointments for the same doctor (should not normally occur)
SELECT a1.appt_id AS appt1, a2.appt_id AS appt2, a1.doctor_id, d.full_name,
       a1.starts_at AS start1, a1.ends_at AS end1, a2.starts_at AS start2, a2.ends_at AS end2
FROM appointment a1
JOIN appointment a2 ON a1.doctor_id = a2.doctor_id AND a1.appt_id < a2.appt_id
JOIN doctor d ON d.doctor_id = a1.doctor_id
WHERE a1.ends_at IS NOT NULL AND a2.starts_at IS NOT NULL
  AND a1.starts_at < a2.ends_at AND a2.starts_at < a1.ends_at
ORDER BY d.full_name, a1.starts_at;

-- b) Patients with multiple concurrent insurance plans (should not happen in current schema)
-- (Check for duplicate patient-plan relationships) - here plan_id is single column so just sanity check
SELECT p.patient_id, p.full_name, COUNT(*) as cnt
FROM patient p
GROUP BY p.patient_id, p.full_name
HAVING cnt > 1;

-- c) Frequently prescribed medications (join via variants)
SELECT m.med_name, COUNT(pr.rx_id) AS times_prescribed
FROM medication m
JOIN medication_variant mv ON mv.med_id = m.med_id
JOIN prescription pr ON pr.variant_id = mv.variant_id
GROUP BY m.med_name
ORDER BY times_prescribed DESC LIMIT 10;

-- d) Recent lab tests without results
SELECT lt.test_id, p.full_name AS patient, d.full_name AS doctor, lt.test_name, lt.test_date
FROM lab_test lt
JOIN appointment a ON a.appt_id = lt.appt_id
JOIN patient p ON p.patient_id = a.patient_id
JOIN doctor d ON d.doctor_id = a.doctor_id
LEFT JOIN lab_test_result ltr ON ltr.test_id = lt.test_id
WHERE ltr.result_id IS NULL
ORDER BY lt.test_date DESC;

-- 6) Cleanup / verification helper queries
-- Verify foreign key integrity counts (orphaned rows if any constraints were disabled)
-- Patients referenced by appointments but not present (should be zero)
SELECT a.patient_id
FROM appointment a
LEFT JOIN patient p ON p.patient_id = a.patient_id
WHERE p.patient_id IS NULL;

-- Doctors referenced by appointments but not present (should be zero)
SELECT a.doctor_id
FROM appointment a
LEFT JOIN doctor d ON d.doctor_id = a.doctor_id
WHERE d.doctor_id IS NULL;

-- 7) Example reporting query: monthly revenue and billing counts
SELECT DATE_FORMAT(billing_date, '%Y-%m') AS month, COUNT(*) AS invoices_count, SUM(amount) AS total_revenue
FROM billing
GROUP BY month
ORDER BY month DESC LIMIT 12;

-- End of test queries.
-- Notes: Uncomment the INSERTs / transaction blocks when you want to test constraint enforcement or rollback behavior.


-- #########################################################################
-- Triggers, audit table, and stored procedures
-- These provide automatic checks, auditing and helpful routines to operate
-- on the `clinic` schema. They should be created with a user that has
-- privileges to create triggers and routines.
-- #########################################################################

-- 1) Audit table to record important changes
CREATE TABLE IF NOT EXISTS audit_log (
  log_id INTEGER PRIMARY KEY AUTO_INCREMENT,
  entity_name VARCHAR(64) NOT NULL,
  entity_id INTEGER DEFAULT NULL,
  action VARCHAR(16) NOT NULL,
  performed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  details VARCHAR(1024) DEFAULT NULL
);

DELIMITER $$

-- 2) Trigger: prevent overlapping appointments for same doctor
CREATE TRIGGER trg_appt_before_insert
BEFORE INSERT ON appointment
FOR EACH ROW
BEGIN
  DECLARE v_cnt INT DEFAULT 0;
  -- Count existing appointments for the same doctor that overlap
  SELECT COUNT(*) INTO v_cnt
  FROM appointment a
  WHERE a.doctor_id = NEW.doctor_id
    AND (
      (a.ends_at IS NULL) OR (NEW.ends_at IS NULL) OR
      NOT (a.ends_at <= NEW.starts_at OR a.starts_at >= NEW.ends_at)
    );
  IF v_cnt > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Overlapping appointment for this doctor';
  END IF;
END$$

-- 3) Trigger: ensure billing_date defaults to current date if not provided
CREATE TRIGGER trg_billing_before_insert
BEFORE INSERT ON billing
FOR EACH ROW
BEGIN
  IF NEW.billing_date IS NULL OR NEW.billing_date = '0000-00-00' THEN
    SET NEW.billing_date = CURRENT_DATE();
  END IF;
  IF NEW.amount < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Billing amount cannot be negative';
  END IF;
END$$

-- 4) Audit triggers: log insert/update/delete for appointment, billing, prescription
CREATE TRIGGER trg_appointment_after_insert
AFTER INSERT ON appointment
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES('appointment', NEW.appt_id, 'INSERT', CONCAT('patient=', NEW.patient_id, ',doctor=', NEW.doctor_id));
END$$

CREATE TRIGGER trg_appointment_after_update
AFTER UPDATE ON appointment
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES('appointment', NEW.appt_id, 'UPDATE', CONCAT('status:', OLD.status, '->', NEW.status));
END$$

CREATE TRIGGER trg_appointment_after_delete
AFTER DELETE ON appointment
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES('appointment', OLD.appt_id, 'DELETE', CONCAT('deleted appointment for patient=', OLD.patient_id));
END$$

CREATE TRIGGER trg_billing_after_insert
AFTER INSERT ON billing
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES('billing', NEW.bill_id, 'INSERT', CONCAT('amount=', NEW.amount, ',status=', NEW.payment_status));
END$$

CREATE TRIGGER trg_billing_after_update
AFTER UPDATE ON billing
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES('billing', NEW.bill_id, 'UPDATE', CONCAT('status:', OLD.payment_status, '->', NEW.payment_status));
END$$

CREATE TRIGGER trg_billing_after_delete
AFTER DELETE ON billing
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES('billing', OLD.bill_id, 'DELETE', CONCAT('deleted billing for appt=', OLD.appt_id));
END$$

CREATE TRIGGER trg_prescription_after_insert
AFTER INSERT ON prescription
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES('prescription', NEW.rx_id, 'INSERT', CONCAT('variant=', NEW.variant_id, ',quantity=', NEW.quantity));
END$$

CREATE TRIGGER trg_prescription_after_update
AFTER UPDATE ON prescription
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES('prescription', NEW.rx_id, 'UPDATE', CONCAT('quantity:', OLD.quantity, '->', NEW.quantity));
END$$

CREATE TRIGGER trg_prescription_after_delete
AFTER DELETE ON prescription
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES('prescription', OLD.rx_id, 'DELETE', CONCAT('deleted prescription for appt=', OLD.appt_id));
END$$

-- 5) Stored procedures

-- (a) Create billing for an appointment (inserts and returns new bill_id)
CREATE PROCEDURE sp_create_billing_for_appt(
  IN in_appt_id INT,
  IN in_amount DECIMAL(10,2),
  IN in_payment_method VARCHAR(50),
  OUT out_bill_id INT
)
BEGIN
  DECLARE v_exists INT DEFAULT 0;
  SELECT COUNT(*) INTO v_exists FROM appointment WHERE appt_id = in_appt_id;
  IF v_exists = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment does not exist';
  END IF;
  INSERT INTO billing (appt_id, amount, payment_status, payment_method, billing_date)
  VALUES (in_appt_id, in_amount, 'unpaid', in_payment_method, CURRENT_DATE());
  SET out_bill_id = LAST_INSERT_ID();
END$$

-- (b) Mark a billing as paid
CREATE PROCEDURE sp_mark_billing_paid(
  IN in_bill_id INT,
  IN in_method VARCHAR(50)
)
BEGIN
  UPDATE billing SET payment_status = 'paid', payment_method = in_method WHERE bill_id = in_bill_id;
END$$

-- (c) Schedule an appointment (returns new appt_id)
CREATE PROCEDURE sp_schedule_appointment(
  IN in_patient INT,
  IN in_doctor INT,
  IN in_start DATETIME,
  IN in_end DATETIME,
  IN in_reason VARCHAR(255),
  OUT out_appt_id INT
)
BEGIN
  -- This uses the trigger to prevent overlap; insert and return id
  INSERT INTO appointment (patient_id, doctor_id, starts_at, ends_at, status, reason)
  VALUES (in_patient, in_doctor, in_start, in_end, 'scheduled', in_reason);
  SET out_appt_id = LAST_INSERT_ID();
END$$

-- (d) Monthly revenue report stored procedure
CREATE PROCEDURE sp_get_monthly_revenue(IN in_year INT)
BEGIN
  SELECT DATE_FORMAT(billing_date, '%Y-%m') AS month,
         COUNT(*) AS invoices_count,
         SUM(amount) AS total_revenue
  FROM billing
  WHERE YEAR(billing_date) = in_year
  GROUP BY month
  ORDER BY month;
END$$

-- (e) Top N doctors by revenue
CREATE PROCEDURE sp_get_top_doctors(IN in_limit INT)
BEGIN
  SELECT doctor_id, full_name, total_billed, invoices_count
  FROM vw_billing_per_doctor
  ORDER BY total_billed DESC
  LIMIT in_limit;
END$$

DELIMITER ;

