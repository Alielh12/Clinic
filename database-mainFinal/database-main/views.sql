use Clinic 

--####################################################
-- Clinic Views
--####################################################

-- 1) Total billing and number of invoices per patient
CREATE OR REPLACE VIEW vw_billing_per_patient AS
SELECT
  p.patient_id,
  p.full_name,
  COALESCE(SUM(b.amount), 0) AS total_billed,
  COUNT(b.bill_id) AS invoices_count
FROM patient p
LEFT JOIN appointment a ON a.patient_id = p.patient_id
LEFT JOIN billing b ON b.appt_id = a.appt_id
GROUP BY p.patient_id, p.full_name;

-- 2) Total billing per doctor (how much revenue each doctor generated)
CREATE OR REPLACE VIEW vw_billing_per_doctor AS
SELECT
  d.doctor_id,
  d.full_name,
  COALESCE(SUM(b.amount), 0) AS total_billed,
  COUNT(b.bill_id) AS invoices_count
FROM doctor d
LEFT JOIN appointment a ON a.doctor_id = d.doctor_id
LEFT JOIN billing b ON b.appt_id = a.appt_id
GROUP BY d.doctor_id, d.full_name;

-- 3) Average appointment duration (in minutes) per doctor
CREATE OR REPLACE VIEW vw_avg_appt_duration_per_doctor AS
SELECT
  d.doctor_id,
  d.full_name,
  AVG(TIMESTAMPDIFF(MINUTE, a.starts_at, a.ends_at)) AS avg_duration_min
FROM doctor d
JOIN appointment a ON a.doctor_id = d.doctor_id
WHERE a.ends_at IS NOT NULL
GROUP BY d.doctor_id, d.full_name;

-- 4) Prescription counts per medication (aggregated at medication level)
CREATE OR REPLACE VIEW vw_prescriptions_per_medication AS
SELECT
  m.med_id,
  m.med_name,
  COUNT(p.rx_id) AS prescriptions_count
FROM medication m
LEFT JOIN medication_variant mv ON mv.med_id = m.med_id
LEFT JOIN prescription p ON p.variant_id = mv.variant_id
GROUP BY m.med_id, m.med_name;

-- 5) Patients per insurance plan
CREATE OR REPLACE VIEW vw_patients_per_plan AS
SELECT
  ip.plan_id,
  ip.provider_name,
  COUNT(p.patient_id) AS patients_count
FROM insurance_plan ip
LEFT JOIN patient p ON p.plan_id = ip.plan_id
GROUP BY ip.plan_id, ip.provider_name;

-- 6) Lab tests summary by status
CREATE OR REPLACE VIEW vw_lab_tests_by_status AS
SELECT
  lt.status,
  COUNT(lt.test_id) AS tests_count,
  MIN(lt.test_date) AS earliest_test,
  MAX(lt.test_date) AS latest_test
FROM lab_test lt
GROUP BY lt.status;

#* 7) Room utilization: number of appointments and average duration per room *#
CREATE OR REPLACE VIEW vw_room_utilization AS
SELECT
  r.room_id,
  r.room_name,
  COUNT(ar.appt_id) AS appointments_count,
  AVG(TIMESTAMPDIFF(MINUTE, a.starts_at, a.ends_at)) AS avg_duration_min
FROM clinic_room r
LEFT JOIN appointment_room ar ON ar.room_id = r.room_id
LEFT JOIN appointment a ON a.appt_id = ar.appt_id AND a.ends_at IS NOT NULL
GROUP BY r.room_id, r.room_name;



-- Example: patients whose total billing exceeds 300
SELECT * FROM vw_billing_per_patient WHERE total_billed > 300;



-- Example: top 5 doctors by revenue
SELECT * FROM vw_billing_per_doctor ORDER BY total_billed DESC LIMIT 5;



-- Example: doctors with average appointment longer than 20 minutes
SELECT * FROM vw_avg_appt_duration_per_doctor WHERE avg_duration_min > 20;


-- Example: medications prescribed more than 2 times
SELECT * FROM vw_prescriptions_per_medication HAVING prescriptions_count > 2;




-- 8) Ranking doctors by total billing using a window function
-- First ensure aggregated totals exist (use the view created above), then rank
-- Note: window functions operate on the result set; some MySQL versions require
-- subquery/CTE. This example uses the view and a simple select-windows query.
-- Example query (not a view):
 SELECT doctor_id, full_name, total_billed,
        RANK() OVER (ORDER BY total_billed DESC) AS billing_rank
 FROM vw_billing_per_doctor;

-- 9) Example HAVING + GROUP BY: doctors with more than 3 invoices and total billing > 500
 SELECT doctor_id, full_name, invoices_count, total_billed
 FROM vw_billing_per_doctor
 HAVING invoices_count > 3 AND total_billed > 500;
