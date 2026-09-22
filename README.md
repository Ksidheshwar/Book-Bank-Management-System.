# 📚 Book Bank Management System — Web App

A full-stack web application built with **Python Flask + MySQL** for managing a college book bank.

## Tech Stack
| Layer | Technology |
|---|---|
| Backend | Python 3.10+ / Flask 3.0 |
| Database | MySQL 8.0 |
| Frontend | HTML5 / Bootstrap 5.3 / Bootstrap Icons |
| DB Driver | mysql-connector-python |

---

## Setup Instructions

### Step 1 — MySQL Setup
Run these SQL files in MySQL Workbench **in order**:
```
01_ddl_schema.sql
02_dml_seed_data_fixed.sql
03_procedures.sql
04_triggers.sql
05_views.sql
06_dml_500_books.sql   ← optional (500 books)
```

### Step 2 — Configure DB password in app.py
Open `app.py` and update line 20:
```python
DB_CONFIG = {
    "host":     "localhost",
    "user":     "root",
    "password": "YOUR_MYSQL_PASSWORD_HERE",  # ← change this
    "database": "book_bank",
}
```

### Step 3 — Install Python dependencies
```bash
pip install flask mysql-connector-python
```

### Step 4 — Run the app
```bash
python app.py
```

### Step 5 — Open in browser
```
http://localhost:5000
```

---

## Features
- 📊 **Dashboard** — live stats, overdue alerts, top books
- 📚 **Books** — add, edit, search, filter by category, deactivate
- 👥 **Members** — register, edit, view profile, borrow history
- 📤 **Issue Book** — calls `sp_issue_book` with all validations
- 🔄 **Transactions** — view all, return books with one click
- 💰 **Fines** — view all fines, mark as paid
- 🔖 **Reservations** — place and track reservations
- 📈 **Reports** — overdue, top books, dept stats, monthly fines, dead stock

---

## Project Structure
```
bookbank_app/
├── app.py                  ← Flask routes + DB logic
├── requirements.txt
├── templates/
│   ├── base.html           ← Sidebar layout
│   ├── dashboard.html
│   ├── books.html
│   ├── book_form.html
│   ├── members.html
│   ├── member_form.html
│   ├── member_profile.html
│   ├── issue_form.html
│   ├── transactions.html
│   ├── fines.html
│   ├── reservations.html
│   ├── reserve_form.html
│   └── reports.html
```
