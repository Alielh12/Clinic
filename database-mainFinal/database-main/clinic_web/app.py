from flask import Flask, render_template, request, redirect
from db import get_connection

app = Flask(__name__)

# ---------------- HOME PAGE ----------------

@app.route("/")
def home():
    return render_template("home.html")

# ------------- PATIENT LIST PAGE -------------

@app.route("/patients")
def patients():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT patient_id, full_name, email, phone FROM patient")
    data = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template("patients.html", patients=data)

# ------------ ADD PATIENT PAGE ---------------

@app.route("/add_patient", methods=["GET", "POST"])
def add_patient():
    if request.method == "POST":
        full_name = request.form["full_name"]
        email = request.form["email"]
        phone = request.form["phone"]

        conn = get_connection()
        cursor = conn.cursor()

        # Generate new ID
        cursor.execute("SELECT MAX(patient_id) + 1 FROM patient")
        new_id = cursor.fetchone()[0] or 1

        query = """
        INSERT INTO patient (patient_id, full_name, email, phone)
        VALUES (%s, %s, %s, %s)
        """

        cursor.execute(query, (new_id, full_name, email, phone))
        conn.commit()

        cursor.close()
        conn.close()

        return redirect("/patients")

    return render_template("add_patient.html")

# ------------- APPOINTMENTS PAGE -------------

@app.route("/appointments")
def appointments():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT a.appt_id, 
               p.full_name AS patient_name,
               d.full_name AS doctor_name,
               a.starts_at,
               a.ends_at,
               a.status,
               a.reason
        FROM appointment a
        JOIN patient p ON a.patient_id = p.patient_id
        JOIN doctor d ON a.doctor_id = d.doctor_id
        ORDER BY a.starts_at DESC
    """)

    data = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("appointments.html", appointments=data)

# ---------- ADD APPOINTMENT PAGE -------------
@app.route("/add_appointment", methods=["GET", "POST"])
def add_appointment():
    conn = get_connection()
    cursor = conn.cursor()

    # Load the dropdown fields BEFORE the try/except
    cursor.execute("SELECT patient_id, full_name FROM patient")
    patients = cursor.fetchall()

    cursor.execute("SELECT doctor_id, full_name FROM doctor")
    doctors = cursor.fetchall()

    if request.method == "POST":
        patient_id = request.form["patient_id"]
        doctor_id = request.form["doctor_id"]
        starts_at = request.form["starts_at"]
        ends_at = request.form["ends_at"]
        reason = request.form["reason"]

        cursor.execute("SELECT COALESCE(MAX(appt_id), 100) + 1 FROM appointment")
        new_id = cursor.fetchone()[0]

        insert_query = """
            INSERT INTO appointment (appt_id, patient_id, doctor_id, starts_at, ends_at, status, reason)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """

        try:
            cursor.execute(insert_query, (
                new_id, patient_id, doctor_id, starts_at, ends_at, "scheduled", reason
            ))
            conn.commit()
            cursor.close()
            conn.close()
            return redirect("/appointments")

        except Exception as e:
            # Clean & extract only the MySQL trigger message
            error_message = str(e).split(":")[-1].strip()

            conn.rollback()
            cursor.close()
            conn.close()

            return render_template(
                "add_appointment.html",
                patients=patients,
                doctors=doctors,
                error=error_message
            )

    # Form GET load
    cursor.close()
    conn.close()
    return render_template("add_appointment.html", patients=patients, doctors=doctors)

# ------------- BILLING PAGE ----------------

@app.route("/billing")
def billing():
    conn = get_connection()
    cursor = conn.cursor()

    # Get all bills with patient and doctor info
    cursor.execute("""
        SELECT b.bill_id, b.appt_id, p.full_name AS patient_name,
               d.full_name AS doctor_name, a.starts_at, b.amount, 
               b.payment_status, b.payment_method, b.billing_date
        FROM billing b
        JOIN appointment a ON a.appt_id = b.appt_id
        JOIN patient p ON p.patient_id = a.patient_id
        JOIN doctor d ON d.doctor_id = a.doctor_id
        ORDER BY b.billing_date DESC
    """)
    bills = cursor.fetchall()

    # Get billing summary
    cursor.execute("""
        SELECT 
            COALESCE(SUM(amount), 0) AS total,
            COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN amount ELSE 0 END), 0) AS paid,
            COALESCE(SUM(CASE WHEN payment_status = 'unpaid' THEN amount ELSE 0 END), 0) AS unpaid
        FROM billing
    """)
    summary = cursor.fetchone()
    total_revenue = summary[0] if summary else 0
    amount_paid = summary[1] if summary else 0
    amount_unpaid = summary[2] if summary else 0

    # Get accounts receivable (unpaid bills by patient)
    cursor.execute("""
        SELECT p.patient_id, p.full_name,
               COUNT(b.bill_id) AS unpaid_count,
               COALESCE(SUM(b.amount), 0) AS total_due
        FROM patient p
        LEFT JOIN appointment a ON a.patient_id = p.patient_id
        LEFT JOIN billing b ON b.appt_id = a.appt_id AND b.payment_status = 'unpaid'
        GROUP BY p.patient_id, p.full_name
        HAVING total_due > 0
        ORDER BY total_due DESC
    """)
    unpaid_bills = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("billing.html", bills=bills, total_revenue=total_revenue, 
                         amount_paid=amount_paid, amount_unpaid=amount_unpaid, 
                         unpaid_bills=unpaid_bills)

# ----------- ADD BILL PAGE ----------------

@app.route("/add_bill", methods=["GET", "POST"])
def add_bill():
    conn = get_connection()
    cursor = conn.cursor()

    # Get all appointments without bills
    cursor.execute("""
        SELECT a.appt_id, p.full_name AS patient_name, d.full_name AS doctor_name, a.starts_at
        FROM appointment a
        JOIN patient p ON p.patient_id = a.patient_id
        JOIN doctor d ON d.doctor_id = a.doctor_id
        WHERE a.appt_id NOT IN (SELECT appt_id FROM billing)
        ORDER BY a.starts_at DESC
    """)
    appointments = cursor.fetchall()

    if request.method == "POST":
        appt_id = request.form["appt_id"]
        amount = request.form["amount"]
        payment_method = request.form["payment_method"]
        payment_status = request.form["payment_status"]

        # Generate new bill ID
        cursor.execute("SELECT COALESCE(MAX(bill_id), 2000) + 1 FROM billing")
        new_bill_id = cursor.fetchone()[0]

        insert_query = """
        INSERT INTO billing (bill_id, appt_id, amount, payment_status, payment_method, billing_date)
        VALUES (%s, %s, %s, %s, %s, CURDATE())
        """

        try:
            cursor.execute(insert_query, (new_bill_id, appt_id, amount, payment_status, payment_method))
            conn.commit()
            cursor.close()
            conn.close()
            return redirect("/billing")
        except Exception as e:
            conn.rollback()
            cursor.close()
            conn.close()
            return render_template("add_bill.html", appointments=appointments, error=str(e))

    cursor.close()
    conn.close()
    return render_template("add_bill.html", appointments=appointments)

# ----------- EDIT BILL PAGE ----------------

@app.route("/edit_bill/<int:bill_id>", methods=["GET", "POST"])
def edit_bill(bill_id):
    conn = get_connection()
    cursor = conn.cursor()

    if request.method == "POST":
        amount = request.form["amount"]
        payment_status = request.form["payment_status"]
        payment_method = request.form["payment_method"]

        update_query = """
        UPDATE billing 
        SET amount = %s, payment_status = %s, payment_method = %s
        WHERE bill_id = %s
        """

        try:
            cursor.execute(update_query, (amount, payment_status, payment_method, bill_id))
            conn.commit()
            cursor.close()
            conn.close()
            return redirect("/billing")
        except Exception as e:
            conn.rollback()
            cursor.close()
            conn.close()
            # Re-fetch and show error
            return redirect(f"/edit_bill/{bill_id}")

    # Get bill details
    cursor.execute("""
        SELECT b.bill_id, a.appt_id, p.patient_id, p.full_name, p.email, p.phone,
               d.full_name AS doctor_name, a.starts_at, a.reason,
               b.amount, b.payment_status, b.payment_method, b.billing_date
        FROM billing b
        JOIN appointment a ON a.appt_id = b.appt_id
        JOIN patient p ON p.patient_id = a.patient_id
        JOIN doctor d ON d.doctor_id = a.doctor_id
        WHERE b.bill_id = %s
    """, (bill_id,))
    bill = cursor.fetchone()

    cursor.close()
    conn.close()

    if not bill:
        return redirect("/billing")

    return render_template("edit_bill.html", bill=bill)

# ----------- BILL DETAILS PAGE ----------------

@app.route("/bill_details/<int:bill_id>")
def bill_details(bill_id):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT b.bill_id, a.appt_id, p.patient_id, p.full_name, p.email, p.phone, p.address,
               d.full_name AS doctor_name, d.email AS doctor_email, a.starts_at, a.reason,
               b.amount, b.payment_method, b.billing_date,
               CASE WHEN b.payment_status = 'paid' THEN 'PAID' ELSE 'PENDING' END AS status
        FROM billing b
        JOIN appointment a ON a.appt_id = b.appt_id
        JOIN patient p ON p.patient_id = a.patient_id
        JOIN doctor d ON d.doctor_id = a.doctor_id
        WHERE b.bill_id = %s
    """, (bill_id,))
    bill = cursor.fetchone()

    cursor.close()
    conn.close()

    if not bill:
        return redirect("/billing")

    return render_template("bill_details.html", bill=bill)

# ------------- MEDICATIONS PAGE ----------------

@app.route("/medications")
def medications():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT m.med_id, m.med_name, mf.form_name, mv.strength, m.notes
        FROM medication m
        LEFT JOIN medication_variant mv ON mv.med_id = m.med_id
        LEFT JOIN medication_form mf ON mf.form_id = mv.form_id
        ORDER BY m.med_name
    """)
    medications = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("medications.html", medications=medications)

# ----------- ADD MEDICATION PAGE ----------------

@app.route("/add_medication", methods=["GET", "POST"])
def add_medication():
    conn = get_connection()
    cursor = conn.cursor()

    if request.method == "POST":
        med_name = request.form["med_name"]
        form_type = request.form["form_type"]
        strength = request.form["strength"]
        notes = request.form.get("notes", "")

        # Generate new medication ID
        cursor.execute("SELECT COALESCE(MAX(med_id), 0) + 1 FROM medication")
        new_med_id = cursor.fetchone()[0]

        # Insert medication
        cursor.execute("""
            INSERT INTO medication (med_id, med_name, notes)
            VALUES (%s, %s, %s)
        """, (new_med_id, med_name, notes))

        # Get or create form
        cursor.execute("SELECT form_id FROM medication_form WHERE form_name = %s", (form_type,))
        form_result = cursor.fetchone()
        
        if form_result:
            form_id = form_result[0]
        else:
            cursor.execute("INSERT INTO medication_form (form_name) VALUES (%s)", (form_type,))
            form_id = cursor.lastrowid

        # Create medication variant
        cursor.execute("SELECT COALESCE(MAX(variant_id), 0) + 1 FROM medication_variant")
        new_variant_id = cursor.fetchone()[0]
        
        cursor.execute("""
            INSERT INTO medication_variant (variant_id, med_id, form_id, strength)
            VALUES (%s, %s, %s, %s)
        """, (new_variant_id, new_med_id, form_id, strength))

        conn.commit()
        cursor.close()
        conn.close()

        return redirect("/medications")

    cursor.close()
    conn.close()
    return render_template("add_medication.html")

# ------- ASSIGN MEDICATION TO PATIENT PAGE --------

@app.route("/assign_medication/<int:med_id>", methods=["GET", "POST"])
def assign_medication(med_id):
    conn = get_connection()
    cursor = conn.cursor()

    # Get medication info
    cursor.execute("""
        SELECT m.med_name, mv.strength 
        FROM medication m
        LEFT JOIN medication_variant mv ON mv.med_id = m.med_id
        WHERE m.med_id = %s LIMIT 1
    """, (med_id,))
    med_info = cursor.fetchone()

    # Get appointments without prescriptions
    cursor.execute("""
        SELECT a.appt_id, p.full_name, d.full_name, a.starts_at
        FROM appointment a
        JOIN patient p ON p.patient_id = a.patient_id
        JOIN doctor d ON d.doctor_id = a.doctor_id
        WHERE a.appt_id NOT IN (SELECT appt_id FROM prescription)
        ORDER BY a.starts_at DESC
    """)
    appointments = cursor.fetchall()

    if request.method == "POST":
        appointment_id = request.form["appointment_id"]
        dosage = request.form["dosage"]
        route = request.form["route"]
        frequency = request.form["frequency"]
        quantity = request.form["quantity"]
        instructions = request.form.get("instructions", "")

        # Get medication variant ID
        cursor.execute("""
            SELECT variant_id FROM medication_variant WHERE med_id = %s LIMIT 1
        """, (med_id,))
        variant_result = cursor.fetchone()
        
        if variant_result:
            variant_id = variant_result[0]

            # Generate new prescription ID
            cursor.execute("SELECT COALESCE(MAX(rx_id), 1000) + 1 FROM prescription")
            new_rx_id = cursor.fetchone()[0]

            # Insert prescription
            cursor.execute("""
                INSERT INTO prescription (rx_id, appt_id, variant_id, dosage, route, frequency, instructions, quantity)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (new_rx_id, appointment_id, variant_id, dosage, route, frequency, instructions, quantity))

            conn.commit()
            cursor.close()
            conn.close()

            return redirect("/medications")

    cursor.close()
    conn.close()

    if not med_info:
        return redirect("/medications")

    return render_template("assign_medication.html", med_name=med_info[0], med_strength=med_info[1], 
                         appointments=appointments)

# ------------- ROOMS PAGE ----------------

@app.route("/rooms")
def rooms():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT r.room_id, r.room_name, r.room_type, r.notes,
               COUNT(ar.appt_id) AS appointments_count
        FROM clinic_room r
        LEFT JOIN appointment_room ar ON ar.room_id = r.room_id
        GROUP BY r.room_id, r.room_name, r.room_type, r.notes
        ORDER BY r.room_id
    """)
    rooms = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("rooms.html", rooms=rooms)

# ----------- ADD ROOM PAGE ----------------

@app.route("/add_room", methods=["GET", "POST"])
def add_room():
    conn = get_connection()
    cursor = conn.cursor()

    if request.method == "POST":
        room_name = request.form["room_name"]
        room_type = request.form["room_type"]
        notes = request.form.get("notes", "")

        # Generate new room ID
        cursor.execute("SELECT COALESCE(MAX(room_id), 0) + 1 FROM clinic_room")
        new_room_id = cursor.fetchone()[0]

        cursor.execute("""
            INSERT INTO clinic_room (room_id, room_name, room_type, notes)
            VALUES (%s, %s, %s, %s)
        """, (new_room_id, room_name, room_type, notes))

        conn.commit()
        cursor.close()
        conn.close()

        return redirect("/rooms")

    cursor.close()
    conn.close()
    return render_template("add_room.html")

# ------- ASSIGN ROOM TO APPOINTMENT PAGE --------

@app.route("/assign_room/<int:room_id>", methods=["GET", "POST"])
def assign_room(room_id):
    conn = get_connection()
    cursor = conn.cursor()

    # Get room info
    cursor.execute("SELECT room_name FROM clinic_room WHERE room_id = %s", (room_id,))
    room_result = cursor.fetchone()
    room_name = room_result[0] if room_result else "Unknown"

    # Get appointments without rooms
    cursor.execute("""
        SELECT a.appt_id, p.full_name, d.full_name, a.starts_at
        FROM appointment a
        JOIN patient p ON p.patient_id = a.patient_id
        JOIN doctor d ON d.doctor_id = a.doctor_id
        WHERE a.appt_id NOT IN (SELECT appt_id FROM appointment_room)
        ORDER BY a.starts_at DESC
    """)
    appointments = cursor.fetchall()

    if request.method == "POST":
        appointment_id = request.form["appointment_id"]

        cursor.execute("""
            INSERT INTO appointment_room (appt_id, room_id)
            VALUES (%s, %s)
        """, (appointment_id, room_id))

        conn.commit()
        cursor.close()
        conn.close()

        return redirect("/rooms")

    cursor.close()
    conn.close()

    return render_template("assign_room.html", room_name=room_name, appointments=appointments)

# ------- ROOM SCHEDULE PAGE --------

@app.route("/room_schedule/<int:room_id>")
def room_schedule(room_id):
    conn = get_connection()
    cursor = conn.cursor()

    # Get room name
    cursor.execute("SELECT room_name FROM clinic_room WHERE room_id = %s", (room_id,))
    room_result = cursor.fetchone()
    room_name = room_result[0] if room_result else "Unknown"

    # Get appointments in this room
    cursor.execute("""
        SELECT a.appt_id, p.full_name, d.full_name, a.starts_at, a.ends_at, a.status
        FROM appointment a
        JOIN appointment_room ar ON ar.appt_id = a.appt_id
        JOIN patient p ON p.patient_id = a.patient_id
        JOIN doctor d ON d.doctor_id = a.doctor_id
        WHERE ar.room_id = %s
        ORDER BY a.starts_at DESC
    """, (room_id,))
    schedule = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("room_schedule.html", room_name=room_name, schedule=schedule)

# ----------- SEARCH PAGE ----------------

@app.route("/search", methods=["GET", "POST"])
def search():
    conn = get_connection()
    cursor = conn.cursor()

    patient_results = []
    appt_results = []
    patient_searched = False
    appt_searched = False
    patient_search_term = ""

    if request.method == "POST":
        action = request.form.get("action", "")

        if action == "search_patients":
            patient_name = request.form.get("patient_name", "").strip()
            if patient_name:
                patient_search_term = patient_name
                patient_searched = True
                cursor.execute("""
                    SELECT patient_id, full_name, email, phone
                    FROM patient
                    WHERE full_name LIKE %s
                    ORDER BY full_name
                """, (f"%{patient_name}%",))
                patient_results = cursor.fetchall()

        elif action == "search_appointments":
            search_type = request.form.get("search_type", "")
            search_value = request.form.get("search_value", "").strip()
            
            appt_searched = True
            if search_type == "doctor" and search_value:
                cursor.execute("""
                    SELECT a.appt_id, p.full_name, d.full_name, a.starts_at, a.status
                    FROM appointment a
                    JOIN patient p ON p.patient_id = a.patient_id
                    JOIN doctor d ON d.doctor_id = a.doctor_id
                    WHERE d.full_name LIKE %s
                    ORDER BY a.starts_at DESC
                """, (f"%{search_value}%",))
                appt_results = cursor.fetchall()
            
            elif search_type == "date" and search_value:
                cursor.execute("""
                    SELECT a.appt_id, p.full_name, d.full_name, a.starts_at, a.status
                    FROM appointment a
                    JOIN patient p ON p.patient_id = a.patient_id
                    JOIN doctor d ON d.doctor_id = a.doctor_id
                    WHERE DATE(a.starts_at) = %s
                    ORDER BY a.starts_at DESC
                """, (search_value,))
                appt_results = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("search.html", patient_results=patient_results, appt_results=appt_results,
                         patient_searched=patient_searched, appt_searched=appt_searched,
                         patient_search_term=patient_search_term)

# ------- SEARCH PATIENTS --------

@app.route("/search_patients", methods=["POST"])
def search_patients():
    conn = get_connection()
    cursor = conn.cursor()

    patient_name = request.form.get("patient_name", "").strip()
    patient_results = []

    if patient_name:
        cursor.execute("""
            SELECT patient_id, full_name, email, phone
            FROM patient
            WHERE full_name LIKE %s
            ORDER BY full_name
        """, (f"%{patient_name}%",))
        patient_results = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("search.html", patient_results=patient_results, patient_searched=True,
                         patient_search_term=patient_name, appt_results=[], appt_searched=False)

# ------- SEARCH APPOINTMENTS --------

@app.route("/search_appointments", methods=["POST"])
def search_appointments():
    conn = get_connection()
    cursor = conn.cursor()

    search_type = request.form.get("search_type", "")
    search_value = request.form.get("search_value", "").strip()
    appt_results = []

    if search_type == "doctor" and search_value:
        cursor.execute("""
            SELECT a.appt_id, p.full_name, d.full_name, a.starts_at, a.status
            FROM appointment a
            JOIN patient p ON p.patient_id = a.patient_id
            JOIN doctor d ON d.doctor_id = a.doctor_id
            WHERE d.full_name LIKE %s
            ORDER BY a.starts_at DESC
        """, (f"%{search_value}%",))
        appt_results = cursor.fetchall()
    
    elif search_type == "date" and search_value:
        cursor.execute("""
            SELECT a.appt_id, p.full_name, d.full_name, a.starts_at, a.status
            FROM appointment a
            JOIN patient p ON p.patient_id = a.patient_id
            JOIN doctor d ON d.doctor_id = a.doctor_id
            WHERE DATE(a.starts_at) = %s
            ORDER BY a.starts_at DESC
        """, (search_value,))
        appt_results = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("search.html", appt_results=appt_results, appt_searched=True,
                         patient_results=[], patient_searched=False)

# ----------- DASHBOARD PAGE ----------------

@app.route("/dashboard")
def dashboard():
    conn = get_connection()
    cursor = conn.cursor()

    # Total patients
    cursor.execute("SELECT COUNT(*) FROM patient")
    total_patients = cursor.fetchone()[0]

    # Total appointments
    cursor.execute("SELECT COUNT(*) FROM appointment")
    total_appointments = cursor.fetchone()[0]

    # Today's appointments
    cursor.execute("""
        SELECT COUNT(*) FROM appointment 
        WHERE DATE(starts_at) = CURDATE()
    """)
    today_appointments = cursor.fetchone()[0]

    # Scheduled vs completed
    cursor.execute("""
        SELECT COUNT(*) FROM appointment WHERE status = 'scheduled'
    """)
    scheduled_count = cursor.fetchone()[0]

    cursor.execute("""
        SELECT COUNT(*) FROM appointment WHERE status = 'completed'
    """)
    completed_count = cursor.fetchone()[0]

    # Available rooms (rooms with no appointments today)
    cursor.execute("""
        SELECT COUNT(*) FROM clinic_room r
        WHERE r.room_id NOT IN (
            SELECT DISTINCT ar.room_id
            FROM appointment_room ar
            JOIN appointment a ON a.appt_id = ar.appt_id
            WHERE DATE(a.starts_at) = CURDATE()
        )
    """)
    available_rooms = cursor.fetchone()[0]

    # Total medications
    cursor.execute("SELECT COUNT(*) FROM medication")
    total_medications = cursor.fetchone()[0]

    # Total doctors
    cursor.execute("SELECT COUNT(*) FROM doctor")
    total_doctors = cursor.fetchone()[0]

    # Total rooms
    cursor.execute("SELECT COUNT(*) FROM clinic_room")
    total_rooms = cursor.fetchone()[0]

    # Unpaid bills
    cursor.execute("""
        SELECT COUNT(*) FROM billing WHERE payment_status = 'unpaid'
    """)
    unpaid_bills = cursor.fetchone()[0]

    # Upcoming appointments (next 7 days)
    cursor.execute("""
        SELECT a.starts_at, p.full_name, d.full_name, a.reason, a.status
        FROM appointment a
        JOIN patient p ON p.patient_id = a.patient_id
        JOIN doctor d ON d.doctor_id = a.doctor_id
        WHERE DATE(a.starts_at) >= CURDATE()
        AND DATE(a.starts_at) <= DATE_ADD(CURDATE(), INTERVAL 7 DAY)
        ORDER BY a.starts_at ASC
        LIMIT 20
    """)
    upcoming_appointments = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("dashboard.html", total_patients=total_patients, 
                         total_appointments=total_appointments, today_appointments=today_appointments,
                         scheduled_count=scheduled_count, completed_count=completed_count,
                         available_rooms=available_rooms, total_medications=total_medications,
                         total_doctors=total_doctors, total_rooms=total_rooms, 
                         unpaid_bills=unpaid_bills, upcoming_appointments=upcoming_appointments)


@app.route("/delete_patient/<int:patient_id>")
def delete_patient(patient_id):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("DELETE FROM patient WHERE patient_id = %s", (patient_id,))
        conn.commit()

    except Exception as e:
        conn.rollback()
        cursor.close()
        conn.close()
        # If trigger or FK fails, show error
        return render_template("patients.html", error=str(e))

    cursor.close()
    conn.close()
    return redirect("/patients")


@app.route("/delete_appointment/<int:appt_id>")
def delete_appointment(appt_id):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        # Remove dependent records first to avoid FK constraint errors
        cursor.execute("DELETE FROM billing WHERE appt_id = %s", (appt_id,))
        cursor.execute("DELETE FROM prescription WHERE appt_id = %s", (appt_id,))
        cursor.execute("DELETE FROM appointment_room WHERE appt_id = %s", (appt_id,))
        cursor.execute("DELETE FROM appointment WHERE appt_id = %s", (appt_id,))
        conn.commit()

    except Exception as e:
        conn.rollback()
        cursor.close()
        conn.close()
        return render_template("appointments.html", error=str(e))

    cursor.close()
    conn.close()
    return redirect("/appointments")


@app.route("/delete_bill/<int:bill_id>")
def delete_bill(bill_id):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("DELETE FROM billing WHERE bill_id = %s", (bill_id,))
        conn.commit()

    except Exception as e:
        conn.rollback()
        cursor.close()
        conn.close()
        return render_template("billing.html", error=str(e))

    cursor.close()
    conn.close()
    return redirect("/billing")


@app.route("/delete_medication/<int:med_id>")
def delete_medication(med_id):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        # Delete prescriptions referencing variants of this medication
        cursor.execute("SELECT variant_id FROM medication_variant WHERE med_id = %s", (med_id,))
        variants = cursor.fetchall()
        for v in variants:
            cursor.execute("DELETE FROM prescription WHERE variant_id = %s", (v[0],))

        # Delete variants then medication
        cursor.execute("DELETE FROM medication_variant WHERE med_id = %s", (med_id,))
        cursor.execute("DELETE FROM medication WHERE med_id = %s", (med_id,))
        conn.commit()

    except Exception as e:
        conn.rollback()
        cursor.close()
        conn.close()
        return render_template("medications.html", error=str(e))

    cursor.close()
    conn.close()
    return redirect("/medications")


@app.route("/delete_room/<int:room_id>")
def delete_room(room_id):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        # Remove any room assignments first
        cursor.execute("DELETE FROM appointment_room WHERE room_id = %s", (room_id,))
        cursor.execute("DELETE FROM clinic_room WHERE room_id = %s", (room_id,))
        conn.commit()

    except Exception as e:
        conn.rollback()
        cursor.close()
        conn.close()
        return render_template("rooms.html", error=str(e))

    cursor.close()
    conn.close()
    return redirect("/rooms")








# ---------------- RUN THE APP ----------------

if __name__ == "__main__":
    app.run(debug=True)
