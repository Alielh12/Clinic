DROP DATABASE IF EXISTS clinic;
CREATE DATABASE clinic;
USE clinic;



CREATE TABLE insurance_plan (
  plan_id INTEGER PRIMARY KEY,
  provider_name VARCHAR(150) NOT NULL,
  plan_name VARCHAR(150),
  coverage_details VARCHAR(255),
  
  CONSTRAINT chk_provider_name CHECK (CHAR_LENGTH(provider_name) > 0)
);


CREATE TABLE clinic_room (
  room_id INTEGER PRIMARY KEY,
  room_name VARCHAR(50) NOT NULL,
  room_type VARCHAR(100) DEFAULT 'General',
  notes VARCHAR(255) DEFAULT 'No notes'
);


CREATE TABLE specialty (
  specialty_id INTEGER PRIMARY KEY AUTO_INCREMENT,
  specialty_name VARCHAR(100) NOT NULL UNIQUE
);


CREATE TABLE patient (
  patient_id INTEGER PRIMARY KEY,
  full_name VARCHAR(150) NOT NULL,
  dob DATE DEFAULT NULL,
  email VARCHAR(255) DEFAULT NULL,
  phone VARCHAR(30) DEFAULT NULL,
  address VARCHAR(255) DEFAULT NULL,

  plan_id INTEGER DEFAULT NULL,
  
  CONSTRAINT fk_patient_plan
    FOREIGN KEY (plan_id) REFERENCES insurance_plan(plan_id),

  CONSTRAINT chk_patient_email CHECK (email IS NULL OR email LIKE '%@%.%')
);

CREATE TABLE doctor (
  doctor_id INTEGER PRIMARY KEY,
  full_name VARCHAR(150) NOT NULL,
  email VARCHAR(255) DEFAULT NULL,
  phone VARCHAR(30) DEFAULT NULL,
  
  CONSTRAINT chk_doctor_email CHECK (email IS NULL OR email LIKE '%@%.%')
);


CREATE TABLE doctor_specialty (
  doctor_id INTEGER NOT NULL,
  specialty_id INTEGER NOT NULL,
  
  PRIMARY KEY (doctor_id, specialty_id),
  CONSTRAINT fk_ds_doctor FOREIGN KEY (doctor_id) REFERENCES doctor(doctor_id),
  CONSTRAINT fk_ds_specialty FOREIGN KEY (specialty_id) REFERENCES specialty(specialty_id)
);


CREATE TABLE medication_form (
  form_id INTEGER PRIMARY KEY AUTO_INCREMENT,
  form_name VARCHAR(50) NOT NULL UNIQUE
);


CREATE TABLE medication (
  med_id INTEGER PRIMARY KEY,
  med_name VARCHAR(150) NOT NULL,
  notes VARCHAR(255) DEFAULT NULL
);


CREATE TABLE medication_variant (
  variant_id INTEGER PRIMARY KEY AUTO_INCREMENT,
  med_id INTEGER NOT NULL,
  form_id INTEGER NOT NULL,
  strength VARCHAR(50) NOT NULL,
  
  UNIQUE (med_id, form_id, strength),
  CONSTRAINT fk_mv_med FOREIGN KEY (med_id) REFERENCES medication(med_id),
  CONSTRAINT fk_mv_form FOREIGN KEY (form_id) REFERENCES medication_form(form_id),
  CONSTRAINT chk_mv_strength CHECK (CHAR_LENGTH(strength) > 0)
);


CREATE TABLE appointment (
  appt_id INTEGER PRIMARY KEY,
  patient_id INTEGER NOT NULL,
  doctor_id INTEGER NOT NULL,

  starts_at DATETIME NOT NULL,
  ends_at DATETIME DEFAULT NULL,

  status VARCHAR(20) DEFAULT 'scheduled',
  reason VARCHAR(255),

  CONSTRAINT fk_appt_patient FOREIGN KEY(patient_id) REFERENCES patient(patient_id),
  CONSTRAINT fk_appt_doctor FOREIGN KEY(doctor_id) REFERENCES doctor(doctor_id),
  CONSTRAINT chk_appt_status CHECK (status IN ('scheduled','completed','cancelled')),
  CONSTRAINT chk_appt_time CHECK (ends_at IS NULL OR ends_at >= starts_at)
);


CREATE TABLE appointment_room (
  appt_id INTEGER NOT NULL,
  room_id INTEGER NOT NULL,
  
  PRIMARY KEY (appt_id, room_id),
  CONSTRAINT fk_ar_appt FOREIGN KEY (appt_id) REFERENCES appointment(appt_id),
  CONSTRAINT fk_ar_room FOREIGN KEY (room_id) REFERENCES clinic_room(room_id)
);


CREATE TABLE prescription (
  rx_id INTEGER PRIMARY KEY,
  appt_id INTEGER NOT NULL,
  variant_id INTEGER NOT NULL,

  dosage VARCHAR(100) DEFAULT NULL,
  route VARCHAR(50) DEFAULT 'oral',
  frequency VARCHAR(100) DEFAULT 'once daily',
  instructions VARCHAR(255) DEFAULT NULL,

  quantity INTEGER DEFAULT 0,

  CONSTRAINT fk_rx_appt FOREIGN KEY(appt_id) REFERENCES appointment(appt_id),
  CONSTRAINT fk_rx_variant FOREIGN KEY(variant_id) REFERENCES medication_variant(variant_id),
  CONSTRAINT chk_rx_quantity CHECK (quantity >= 0),
  CONSTRAINT chk_rx_route CHECK (route IN ('oral', 'intravenous', 'intramuscular', 'topical', 'inhalation', 'subcutaneous'))
);


CREATE TABLE billing (
  bill_id INTEGER PRIMARY KEY,
  appt_id INTEGER NOT NULL,

  amount DECIMAL(10,2) NOT NULL,
  payment_status VARCHAR(20) DEFAULT 'unpaid',
  payment_method VARCHAR(50) DEFAULT 'cash',

  billing_date DATE NOT NULL,

  CONSTRAINT fk_billing_appt FOREIGN KEY(appt_id) REFERENCES appointment(appt_id),
  CONSTRAINT chk_billing_amount CHECK (amount >= 0),
  CONSTRAINT chk_billing_status CHECK (payment_status IN ('paid','unpaid')),
  CONSTRAINT chk_billing_method CHECK (payment_method IN ('cash', 'card', 'insurance', 'check', 'online'))

);


CREATE TABLE lab_test (
  test_id INTEGER PRIMARY KEY,
  appt_id INTEGER NOT NULL,

  test_name VARCHAR(150) NOT NULL,
  status VARCHAR(30) DEFAULT 'pending',
  test_date DATE,

  CONSTRAINT fk_test_appt FOREIGN KEY(appt_id) REFERENCES appointment(appt_id),
  CONSTRAINT chk_test_status CHECK (status IN ('pending','completed'))
);


CREATE TABLE lab_test_result (
  result_id INTEGER PRIMARY KEY AUTO_INCREMENT,
  test_id INTEGER NOT NULL,
  result_detail VARCHAR(255),
  
  CONSTRAINT fk_ltr_test FOREIGN KEY (test_id) REFERENCES lab_test(test_id)
);

CREATE TABLE IF NOT EXISTS audit_log (
  log_id INTEGER PRIMARY KEY AUTO_INCREMENT,
  entity_name VARCHAR(64) NOT NULL,
  entity_id INTEGER DEFAULT NULL,
  action VARCHAR(16) NOT NULL,
  performed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  details VARCHAR(1024) DEFAULT NULL
);



