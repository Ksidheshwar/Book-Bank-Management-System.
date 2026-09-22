"""
Book Bank Management System — Flask Web Application
Backend: Python 3 + Flask + mysql-connector-python
Database: MySQL 8.0 (book_bank)
Run: python app.py
Visit: http://localhost:5001
"""

from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
import mysql.connector
from mysql.connector import Error
from datetime import date
import os

app = Flask(__name__)
app.secret_key = "bookbank_secret_2026"

# ── DB CONFIG — change host/user/password to match your MySQL Workbench setup ──
DB_CONFIG = {
    "host":     "localhost",
    "port":     3306,
    "user":     "root",
    "password": "root",
    "database": "book_bank",
    "autocommit": False,
}

def get_db():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except Error as e:
        print(f"DB CONNECTION ERROR: {e}")
        return None

def query(sql, params=(), fetchone=False):
    """Run a SELECT and return rows."""
    conn = get_db()
    if not conn:
        return [] if not fetchone else None
    cur = conn.cursor(dictionary=True)
    cur.execute(sql, params)
    result = cur.fetchone() if fetchone else cur.fetchall()
    cur.close()
    conn.close()
    return result

def call_procedure(proc_name, in_params=(), out_count=2):
    """
    Call a stored procedure with IN params and read OUT params.
    Returns (out_params_dict, error_string)
    """
    conn = get_db()
    if not conn:
        return None, "Database connection failed."
    try:
        cur = conn.cursor()
        # Build user-defined variables for OUT params
        out_vars = [f"@out{i}" for i in range(out_count)]
        # Set dummy values first
        for v in out_vars:
            cur.execute(f"SET {v} = NULL")
        # Call procedure
        placeholders = ", ".join(["?" if p is None else "%s" for p in in_params])
        out_placeholders = ", ".join(out_vars)
        all_placeholders = (f"{placeholders}, " if in_params else "") + out_placeholders
        cur.execute(f"CALL {proc_name}({all_placeholders})", in_params)
        conn.commit()
        # Fetch OUT param values
        result = {}
        for i, v in enumerate(out_vars):
            cur.execute(f"SELECT {v} AS val")
            row = cur.fetchone()
            result[f"out{i}"] = row[0] if row else None
        cur.close()
        conn.close()
        return result, None
    except Error as e:
        conn.rollback()
        conn.close()
        return None, str(e)


@app.route("/")
def dashboard():
    def safe_query(sql):
        try:
            result = query(sql, fetchone=True)
            return result["c"] if result else 0
        except:
            return 0
    stats = {
        "total_books":    safe_query("SELECT COUNT(*) AS c FROM books WHERE is_active=1"),
        "total_members":  safe_query("SELECT COUNT(*) AS c FROM members WHERE is_active=1"),
        "active_borrows": safe_query("SELECT COUNT(*) AS c FROM transactions WHERE status='issued'"),
        "overdue":        safe_query("SELECT COUNT(*) AS c FROM vw_overdue_transactions"),
        "unpaid_fines":   safe_query("SELECT COALESCE(SUM(amount),0) AS c FROM fines WHERE status='unpaid'"),
        "total_fines_collected": safe_query("SELECT COALESCE(SUM(amount),0) AS c FROM fines WHERE status='paid'"),
    }
    overdue        = query("SELECT * FROM vw_overdue_transactions ORDER BY days_overdue DESC LIMIT 5") or []
    recent_borrows = query("SELECT * FROM vw_active_borrows ORDER BY due_date ASC LIMIT 5") or []
    top_books      = query("""SELECT b.title, b.author, COUNT(t.txn_id) AS times
                              FROM transactions t JOIN books b ON t.book_id=b.book_id
                              GROUP BY b.book_id ORDER BY times DESC LIMIT 5""") or []
    return render_template("dashboard.html", stats=stats, overdue=overdue,
                           recent_borrows=recent_borrows, top_books=top_books)

# ══════════════════════════════════════════════════════════════════════════════
# BOOKS
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/books")
def books():
    search = request.args.get("q", "").strip()
    category = request.args.get("category", "").strip()
    if search:
        rows = query("""SELECT * FROM vw_book_availability
                        WHERE (title LIKE %s OR author LIKE %s OR isbn LIKE %s)
                        ORDER BY category, title""",
                     (f"%{search}%", f"%{search}%", f"%{search}%"))
    elif category:
        rows = query("SELECT * FROM vw_book_availability WHERE category=%s ORDER BY title", (category,))
    else:
        rows = query("SELECT * FROM vw_book_availability ORDER BY category, title")
    categories = query("SELECT DISTINCT category FROM books WHERE is_active=1 ORDER BY category")
    return render_template("books.html", books=rows, search=search,
                           category=category, categories=categories)

@app.route("/books/add", methods=["GET", "POST"])
def add_book():
    if request.method == "POST":
        data = request.form
        conn = get_db()
        try:
            cur = conn.cursor()
            cur.execute("""INSERT INTO books
                          (isbn, title, author, category, publisher, pub_year, total_qty, available_qty)
                          VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
                        (data["isbn"], data["title"], data["author"], data["category"],
                         data.get("publisher",""), data.get("pub_year") or None,
                         int(data["total_qty"]), int(data["total_qty"])))
            conn.commit()
            flash(f"✅ Book '{data['title']}' added successfully!", "success")
        except Error as e:
            conn.rollback()
            flash(f"❌ Error: {e}", "danger")
        finally:
            cur.close(); conn.close()
        return redirect(url_for("books"))
    return render_template("book_form.html", book=None, action="Add")

@app.route("/books/edit/<int:book_id>", methods=["GET", "POST"])
def edit_book(book_id):
    book = query("SELECT * FROM books WHERE book_id=%s", (book_id,), fetchone=True)
    if not book:
        flash("Book not found.", "warning"); return redirect(url_for("books"))
    if request.method == "POST":
        data = request.form
        conn = get_db()
        try:
            cur = conn.cursor()
            cur.execute("""UPDATE books SET title=%s, author=%s, category=%s,
                          publisher=%s, pub_year=%s, total_qty=%s WHERE book_id=%s""",
                        (data["title"], data["author"], data["category"],
                         data.get("publisher",""), data.get("pub_year") or None,
                         int(data["total_qty"]), book_id))
            conn.commit()
            flash(f"✅ Book updated successfully!", "success")
        except Error as e:
            conn.rollback(); flash(f"❌ Error: {e}", "danger")
        finally:
            cur.close(); conn.close()
        return redirect(url_for("books"))
    return render_template("book_form.html", book=book, action="Edit")

@app.route("/books/deactivate/<int:book_id>")
def deactivate_book(book_id):
    conn = get_db()
    cur = conn.cursor()
    cur.execute("UPDATE books SET is_active=0 WHERE book_id=%s", (book_id,))
    conn.commit(); cur.close(); conn.close()
    flash("📕 Book deactivated.", "warning")
    return redirect(url_for("books"))


# ══════════════════════════════════════════════════════════════════════════════
# MEMBERS
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/members")
def members():
    search = request.args.get("q", "").strip()
    if search:
        rows = query("""SELECT * FROM members
                        WHERE name LIKE %s OR email LIKE %s OR department LIKE %s
                        ORDER BY name""",
                     (f"%{search}%", f"%{search}%", f"%{search}%"))
    else:
        rows = query("SELECT * FROM members ORDER BY member_id")
    return render_template("members.html", members=rows, search=search)

@app.route("/members/add", methods=["GET", "POST"])
def add_member():
    if request.method == "POST":
        data = request.form
        conn = get_db()
        if not conn:
            flash("❌ Database connection failed. Check your password in app.py.", "danger")
            return redirect(url_for("members"))
        cur = None
        try:
            cur = conn.cursor()
            cur.execute("""INSERT INTO members (name, email, phone, department, join_date)
                          VALUES (%s,%s,%s,%s,%s)""",
                        (data["name"], data["email"], data.get("phone",""),
                         data.get("department",""), date.today()))
            conn.commit()
            flash(f"✅ Member '{data['name']}' registered!", "success")
        except Error as e:
            conn.rollback()
            flash(f"❌ Error: {e}", "danger")
        finally:
            if cur: cur.close()
            conn.close()
        return redirect(url_for("members"))
    return render_template("member_form.html", member=None, action="Register")
@app.route("/members/edit/<int:member_id>", methods=["GET", "POST"])
def edit_member(member_id):
    member = query("SELECT * FROM members WHERE member_id=%s", (member_id,), fetchone=True)
    if not member:
        flash("Member not found.", "warning"); return redirect(url_for("members"))
    if request.method == "POST":
        data = request.form
        conn = get_db()
        try:
            cur = conn.cursor()
            cur.execute("""UPDATE members SET name=%s, email=%s, phone=%s, department=%s
                          WHERE member_id=%s""",
                        (data["name"], data["email"], data.get("phone",""),
                         data.get("department",""), member_id))
            conn.commit(); flash("✅ Member updated!", "success")
        except Error as e:
            conn.rollback(); flash(f"❌ Error: {e}", "danger")
        finally:
            cur.close(); conn.close()
        return redirect(url_for("members"))
    return render_template("member_form.html", member=member, action="Edit")

@app.route("/members/<int:member_id>")
def member_profile(member_id):
    member = query("SELECT * FROM members WHERE member_id=%s", (member_id,), fetchone=True)
    history = query("SELECT * FROM vw_member_history WHERE member_id=%s ORDER BY issue_date DESC", (member_id,))
    active  = query("SELECT * FROM vw_active_borrows WHERE member_name=(SELECT name FROM members WHERE member_id=%s)", (member_id,))
    fines   = query("SELECT * FROM fines WHERE member_id=%s ORDER BY created_at DESC", (member_id,))
    return render_template("member_profile.html", member=member, history=history,
                           active=active, fines=fines)

@app.route("/members/deactivate/<int:member_id>")
def deactivate_member(member_id):
    conn = get_db(); cur = conn.cursor()
    cur.execute("UPDATE members SET is_active=0 WHERE member_id=%s", (member_id,))
    conn.commit(); cur.close(); conn.close()
    flash("⚠️ Member deactivated.", "warning")
    return redirect(url_for("members"))


# ══════════════════════════════════════════════════════════════════════════════
# TRANSACTIONS — ISSUE / RETURN
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/transactions")
def transactions():
    rows = query("""
        SELECT t.txn_id, m.name AS member_name, b.title AS book_title,
               t.issue_date, t.due_date, t.return_date, t.status,
               CASE WHEN t.status='issued' AND t.due_date < CURDATE()
                    THEN DATEDIFF(CURDATE(), t.due_date) ELSE 0 END AS days_overdue
        FROM transactions t
        JOIN members m ON t.member_id=m.member_id
        JOIN books   b ON t.book_id=b.book_id
        ORDER BY t.txn_id DESC""")
    return render_template("transactions.html", transactions=rows)

@app.route("/issue", methods=["GET", "POST"])
def issue_book():
    members_list = query("SELECT member_id, name, department FROM members WHERE is_active=1 ORDER BY name")
    books_list   = query("SELECT book_id, title, author, available_qty FROM books WHERE is_active=1 AND available_qty>0 ORDER BY title")
    if request.method == "POST":
        member_id = int(request.form["member_id"])
        book_id   = int(request.form["book_id"])
        result, err = call_procedure("sp_issue_book", (member_id, book_id), out_count=2)
        if err:
            flash(f"❌ {err}", "danger")
        else:
            msg = result.get("out1", "")
            if msg and msg.startswith("SUCCESS"):
                flash(f"✅ {msg}", "success")
            else:
                flash(f"❌ {msg}", "danger")
        return redirect(url_for("transactions"))
    return render_template("issue_form.html", members=members_list, books=books_list)

@app.route("/return/<int:txn_id>", methods=["POST"])
def return_book(txn_id):
    result, err = call_procedure("sp_return_book", (txn_id,), out_count=1)
    if err:
        flash(f"❌ {err}", "danger")
    else:
        msg = result.get("out0", "")
        if msg and "SUCCESS" in msg:
            flash(f"✅ {msg}", "success")
        else:
            flash(f"❌ {msg}", "danger")
    return redirect(url_for("transactions"))


# ══════════════════════════════════════════════════════════════════════════════
# FINES
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/fines")
def fines():
    rows = query("SELECT * FROM vw_fine_summary ORDER BY fine_id DESC")
    total_unpaid = query("SELECT COALESCE(SUM(amount),0) AS t FROM fines WHERE status='unpaid'", fetchone=True)["t"]
    return render_template("fines.html", fines=rows, total_unpaid=total_unpaid)

@app.route("/fines/pay/<int:fine_id>", methods=["POST"])
def pay_fine(fine_id):
    result, err = call_procedure("sp_pay_fine", (fine_id,), out_count=1)
    if err:
        flash(f"❌ {err}", "danger")
    else:
        msg = result.get("out0","")
        flash(f"✅ {msg}" if "SUCCESS" in str(msg) else f"❌ {msg}",
              "success" if "SUCCESS" in str(msg) else "danger")
    return redirect(url_for("fines"))


# ══════════════════════════════════════════════════════════════════════════════
# RESERVATIONS
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/reservations")
def reservations():
    rows = query("SELECT * FROM vw_pending_reservations ORDER BY reserved_on ASC")
    return render_template("reservations.html", reservations=rows)

@app.route("/reserve", methods=["GET","POST"])
def reserve_book():
    members_list = query("SELECT member_id, name FROM members WHERE is_active=1 ORDER BY name")
    books_list   = query("SELECT book_id, title, author FROM books WHERE is_active=1 AND available_qty=0 ORDER BY title")
    if request.method == "POST":
        member_id = int(request.form["member_id"])
        book_id   = int(request.form["book_id"])
        result, err = call_procedure("sp_reserve_book", (member_id, book_id), out_count=1)
        if err:
            flash(f"❌ {err}", "danger")
        else:
            msg = result.get("out0","")
            flash(f"✅ {msg}" if "SUCCESS" in str(msg) else f"ℹ️ {msg}",
                  "success" if "SUCCESS" in str(msg) else "info")
        return redirect(url_for("reservations"))
    return render_template("reserve_form.html", members=members_list, books=books_list)


# ══════════════════════════════════════════════════════════════════════════════
# REPORTS
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/reports")
def reports():
    overdue   = query("SELECT * FROM vw_overdue_transactions ORDER BY days_overdue DESC")
    monthly   = query("""SELECT DATE_FORMAT(paid_on,'%Y-%m') AS month,
                                COUNT(*) AS count, SUM(amount) AS total
                         FROM fines WHERE status='paid'
                         GROUP BY month ORDER BY month DESC LIMIT 12""")
    top_books = query("""SELECT b.title, b.author, b.category,
                                COUNT(t.txn_id) AS times_borrowed
                         FROM transactions t JOIN books b ON t.book_id=b.book_id
                         GROUP BY b.book_id ORDER BY times_borrowed DESC LIMIT 10""")
    dept_stats= query("""SELECT m.department,
                                COUNT(DISTINCT m.member_id) AS members,
                                COUNT(t.txn_id) AS borrows,
                                COALESCE(SUM(f.amount),0) AS fines_rs
                         FROM members m
                         LEFT JOIN transactions t ON m.member_id=t.member_id
                         LEFT JOIN fines f ON t.txn_id=f.txn_id
                         GROUP BY m.department ORDER BY borrows DESC""")
    never_borrowed = query("""SELECT b.book_id, b.title, b.author, b.category, b.total_qty
                              FROM books b WHERE b.is_active=1
                              AND b.book_id NOT IN (SELECT DISTINCT book_id FROM transactions)
                              ORDER BY b.category, b.title""")
    return render_template("reports.html", overdue=overdue, monthly=monthly,
                           top_books=top_books, dept_stats=dept_stats,
                           never_borrowed=never_borrowed)


# ══════════════════════════════════════════════════════════════════════════════
# API — JSON endpoints for live search
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/api/books/search")
def api_search_books():
    q = request.args.get("q", "")
    rows = query("""SELECT book_id, title, author, category, available_qty
                    FROM books WHERE is_active=1
                    AND (title LIKE %s OR author LIKE %s OR isbn LIKE %s)
                    LIMIT 10""",
                 (f"%{q}%", f"%{q}%", f"%{q}%"))
    return jsonify(rows)

@app.route("/api/members/search")
def api_search_members():
    q = request.args.get("q", "")
    rows = query("""SELECT member_id, name, department, email
                    FROM members WHERE is_active=1
                    AND (name LIKE %s OR email LIKE %s)
                    LIMIT 10""", (f"%{q}%", f"%{q}%"))
    return jsonify(rows)


if __name__ == "__main__":
    app.run(debug=True, port=5001)

# ── Jinja2 extras ────────────────────────────────────────────────────────────
from datetime import datetime

@app.context_processor
def inject_globals():
    return {
        "now": datetime.now().strftime("%d %b %Y"),
    }

# Register enumerate as a Jinja2 filter
app.jinja_env.globals["enumerate"] = enumerate
