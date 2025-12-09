use Clinic

DELIMITER $$

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
