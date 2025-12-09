USE Clinic;

DELIMITER $$

/* 1) Prevent inserting an appointment that overlaps with an 
      existing appointment for the same doctor.*/
DROP TRIGGER IF EXISTS trg_appt_before_insert $$
CREATE TRIGGER trg_appt_before_insert
BEFORE INSERT ON appointment
FOR EACH ROW
BEGIN
  DECLARE v_cnt INT DEFAULT 0;

  -- CHECK IF start or end is NULL
  IF NEW.starts_at IS NULL OR NEW.ends_at IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Start time and end time are required';
  END IF;

  -- VALIDATE that end is after start
  IF NEW.ends_at <= NEW.starts_at THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'End time must be after the start time';
  END IF;

  -- CHECK FOR OVERLAPS
  SELECT COUNT(*) INTO v_cnt
  FROM appointment a
  WHERE a.doctor_id = NEW.doctor_id
    AND a.starts_at < NEW.ends_at
    AND a.ends_at > NEW.starts_at;

  IF v_cnt > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'This doctor already has an appointment during the selected time range';
  END IF;

END$$



/* ----------------------------------------------------------
   2) Set billing_date to today if missing AND prevent 
      inserting a negative billing amount.
-----------------------------------------------------------*/
DROP TRIGGER IF EXISTS trg_billing_before_insert $$
CREATE TRIGGER trg_billing_before_insert
BEFORE INSERT ON billing
FOR EACH ROW
BEGIN
  IF NEW.billing_date IS NULL OR NEW.billing_date = '0000-00-00' THEN
    SET NEW.billing_date = CURRENT_DATE();
  END IF;

  IF NEW.amount < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Billing amount cannot be negative';
  END IF;
END$$


/* ----------------------------------------------------------
   3 Log every new appointment inserted into the audit_log table.
-----------------------------------------------------------*/
DROP TRIGGER IF EXISTS trg_appointment_after_insert $$
CREATE TRIGGER trg_appointment_after_insert
AFTER INSERT ON appointment
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES ('appointment', NEW.appt_id, 'INSERT',
          CONCAT('patient=', NEW.patient_id, ',doctor=', NEW.doctor_id));
END$$


/* ----------------------------------------------------------
   4 Log each appointment update, including old and new status.
-----------------------------------------------------------*/
DROP TRIGGER IF EXISTS trg_appointment_after_update $$
CREATE TRIGGER trg_appointment_after_update
AFTER UPDATE ON appointment
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES ('appointment', NEW.appt_id, 'UPDATE',
          CONCAT('status:', OLD.status, '->', NEW.status));
END$$


/* ----------------------------------------------------------
   5 Log when an appointment is deleted, including the patient ID.
-----------------------------------------------------------*/
DROP TRIGGER IF EXISTS trg_appointment_after_delete $$
CREATE TRIGGER trg_appointment_after_delete
AFTER DELETE ON appointment
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES ('appointment', OLD.appt_id, 'DELETE',
          CONCAT('deleted appointment for patient=', OLD.patient_id));
END$$


/* ----------------------------------------------------------
   6 Log new billing records inserted, including amount and status.
-----------------------------------------------------------*/
DROP TRIGGER IF EXISTS trg_billing_after_insert $$
CREATE TRIGGER trg_billing_after_insert
AFTER INSERT ON billing
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES ('billing', NEW.bill_id, 'INSERT',
          CONCAT('amount=', NEW.amount, ',status=', NEW.payment_status));
END$$


/* ----------------------------------------------------------
   7 Log billing updates, noting the change in payment status.
-----------------------------------------------------------*/
DROP TRIGGER IF EXISTS trg_billing_after_update $$
CREATE TRIGGER trg_billing_after_update
AFTER UPDATE ON billing
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES ('billing', NEW.bill_id, 'UPDATE',
          CONCAT('status:', OLD.payment_status, '->', NEW.payment_status));
END$$


/* ----------------------------------------------------------
   8 Log deletion of billing records, including related appointment.
-----------------------------------------------------------*/
DROP TRIGGER IF EXISTS trg_billing_after_delete $$
CREATE TRIGGER trg_billing_after_delete
AFTER DELETE ON billing
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES ('billing', OLD.bill_id, 'DELETE',
          CONCAT('deleted billing for appt=', OLD.appt_id));
END$$


/* ----------------------------------------------------------
   9 Log new prescription insertions with variant and quantity.
-----------------------------------------------------------*/
DROP TRIGGER IF EXISTS trg_prescription_after_insert $$
CREATE TRIGGER trg_prescription_after_insert
AFTER INSERT ON prescription
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES ('prescription', NEW.rx_id, 'INSERT',
          CONCAT('variant=', NEW.variant_id, ',quantity=', NEW.quantity));
END$$


/* ----------------------------------------------------------
   10 Log prescription updates, showing old and new quantity.
-----------------------------------------------------------*/
DROP TRIGGER IF EXISTS trg_prescription_after_update $$
CREATE TRIGGER trg_prescription_after_update
AFTER UPDATE ON prescription
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES ('prescription', NEW.rx_id, 'UPDATE',
          CONCAT('quantity:', OLD.quantity, '->', NEW.quantity));
END$$


/* ----------------------------------------------------------
   11 Log prescription deletions, including which appointment it belonged to.
-----------------------------------------------------------*/
DROP TRIGGER IF EXISTS trg_prescription_after_delete $$
CREATE TRIGGER trg_prescription_after_delete
AFTER DELETE ON prescription
FOR EACH ROW
BEGIN
  INSERT INTO audit_log(entity_name, entity_id, action, details)
  VALUES ('prescription', OLD.rx_id, 'DELETE',
          CONCAT('deleted prescription for appt=', OLD.appt_id));
END$$

DELIMITER ;


/* ----------------------------------------------------------
   11 Log prescription deletions, including which appointment it belonged to.
-----------------------------------------------------------*/

DROP TRIGGER IF EXISTS trg_appt_before_insert;
CREATE TRIGGER trg_appt_before_insert
BEFORE INSERT ON appointment
FOR EACH ROW
BEGIN
  DECLARE v_cnt INT DEFAULT 0;
  
  -- Prevent scheduling appointments in the past
  IF NEW.starts_at < NOW() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot schedule appointment in the past';
  END IF;
  
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
  END IF;
END;