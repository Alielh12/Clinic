use Clinic

INSERT INTO insurance_plan VALUES
 (1, 'CNSS', 'Basic Coverage', 'Covers general consultations'),
 (2, 'AXA Assurance', 'Premium Health', 'Covers medications & tests'),
 (3, 'Mutuelle Marocaine', 'Standard Plan', 'Covers 70% of costs');

INSERT INTO clinic_room VALUES
 (1, 'Room A', 'Consultation', 'Ground floor'),
 (2, 'Room B', 'Pediatrics', 'Child-friendly room'),
 (3, 'Lab 1', 'Laboratory', 'Diagnostic testing');

INSERT INTO specialty VALUES
 (1, 'General Practitioner'),
 (2, 'Pediatrics'),
 (3, 'Cardiology'),
 (4, 'Dermatology'),
 (5, 'Orthopedics');

INSERT INTO patient (patient_id, full_name, dob, email, phone, address, plan_id) VALUES
  (1, 'Fatima Zahra', '1990-04-12', 'fatima.z@example.com', '+212600000001', 'Ifrane, Morocco', 1),
  (2, 'Youssef El',   '1985-09-03', 'y.el@example.com',       '+212600000002', 'Fes, Morocco', 2),
  (3, 'Amina Ben',    '2001-01-26', 'amina.b@example.com',    '+212600000003', 'Rabat, Morocco', 3),
  (4, 'Karim Alaoui', '1978-07-15', 'karim.a@example.com', '+212600000004', 'Marrakech, Morocco', 1),
  (5, 'Laila Tazi', '1995-12-08', 'laila.t@example.com', '+212600000005', 'Casablanca, Morocco', 2),
  (6, 'Ahmed Bennani', '1982-03-22', 'ahmed.b@example.com', '+212600000006', 'Tangier, Morocco', 3);

INSERT INTO doctor VALUES
  (1, 'Dr. Amine B', 'amine.b@clinic.com', '+212600000010'),
  (2, 'Dr. Sara K',  'sara.k@clinic.com',  '+212600000011'),
  (3, 'Dr. Omar L',  'omar.l@clinic.com',  '+212600000012'),
  (4, 'Dr. Nadia R', 'nadia.r@clinic.com', '+212600000013'),
  (5, 'Dr. Hassan M','hassan.m@clinic.com', '+212600000014');

INSERT INTO doctor_specialty VALUES
  (1, 1),
  (2, 2),
  (3, 3),
  (4, 4),
  (5, 5);

INSERT INTO medication_form VALUES
 (1, 'tablet'),
 (2, 'capsule');

INSERT INTO medication VALUES
  (1, 'Paracetamol', 'Analgesic'),
  (2, 'Amoxicillin', 'Antibiotic'),
  (3, 'Ibuprofen', 'NSAID'),
  (4, 'Aspirin', 'Analgesic'),
  (5, 'Cetirizine', 'Antihistamine'),
  (6, 'Omeprazole', 'PPI');

INSERT INTO medication_variant VALUES
 (1, 1, 1, '500mg'),
 (2, 2, 2, '500mg'),
 (3, 3, 1, '200mg'),
 (4, 4, 1, '100mg'),
 (5, 5, 1, '10mg'),
 (6, 6, 2, '20mg');

INSERT INTO appointment VALUES
  (101, 1, 1, '2025-11-05 09:00:00', '2025-11-05 09:20:00', 'scheduled', 'Fever and cough'),
  (102, 2, 2, '2025-11-06 10:00:00', '2025-11-06 10:15:00', 'scheduled', 'Vaccination'),
  (103, 3, 3, '2025-11-07 11:30:00', '2025-11-07 11:50:00', 'scheduled', 'Chest pain follow-up'),
  (104, 1, 2, '2025-11-08 14:00:00', '2025-11-08 14:30:00', 'scheduled', 'Child check-up'),
  (105, 4, 1, '2025-11-09 08:30:00', '2025-11-09 08:45:00', 'completed', 'Routine physical'),
  (106, 5, 3, '2025-11-10 16:00:00', '2025-11-10 16:20:00', 'scheduled', 'Blood pressure check'),
  (107, 2, 4, '2025-11-11 10:30:00', '2025-11-11 10:45:00', 'completed', 'Skin rash consultation'),
  (108, 6, 5, '2025-11-12 13:00:00', '2025-11-12 13:15:00', 'cancelled', 'Knee pain'),
  (109, 3, 1, '2025-11-13 09:30:00', '2025-11-13 09:50:00', 'scheduled', 'Follow-up on medication'),
  (110, 4, 2, '2025-11-14 11:00:00', '2025-11-14 11:25:00', 'completed', 'Vaccination booster');

INSERT INTO appointment_room VALUES
  (101, 1),
  (102, 2),
  (103, 3),
  (104, 2),
  (105, 1),
  (106, 3),
  (107, 1),
  (108, 1),
  (109, 3),
  (110, 2);

INSERT INTO prescription VALUES
 (1001, 101, 1, '1 tablet', 'oral', 'every 6 hours', 'After meals', 12),
 (1002, 101, 2, '1 capsule', 'oral', 'twice a day', 'Finish full course', 20),
 (1003, 103, 3, '1 tablet', 'oral', 'every 8 hours', 'With food', 15),
 (1004, 104, 5, '1 tablet', 'oral', 'once daily', 'In the evening', 10),
 (1005, 105, 1, '2 tablets', 'oral', 'every 4 hours', 'As needed for pain', 24),
 (1006, 106, 4, '1 tablet', 'oral', 'once daily', 'With water', 30),
 (1007, 107, 6, '1 capsule', 'oral', 'once daily', 'Before breakfast', 14),
 (1008, 109, 2, '1 capsule', 'oral', 'three times a day', 'Finish course', 21),
 (1009, 109, 3, '1 tablet', 'oral', 'every 6 hours', 'With food', 18),
 (1010, 110, 5, '1 tablet', 'oral', 'once daily', 'For allergy relief', 7);

INSERT INTO billing VALUES
  (2001, 101, 350.00, 'paid', 'card', '2025-11-05'),
  (2002, 102, 150.00, 'unpaid', 'cash', '2025-11-06'),
  (2003, 103, 600.00, 'paid', 'insurance', '2025-11-07');

INSERT INTO lab_test VALUES
  (3001, 103, 'Blood Test', 'completed', '2025-11-07'),
  (3002, 106, 'ECG', 'completed', '2025-11-10');

INSERT INTO lab_test_result VALUES
  (1, 3001, 'Normal levels'),
  (2, 3002, 'Abnormal rhythm');