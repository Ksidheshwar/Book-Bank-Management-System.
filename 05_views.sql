-- ============================================================
-- BOOK BANK MANAGEMENT SYSTEM
-- Module : Views & Analytical Queries
-- File   : 05_views.sql
-- Run after: 04_triggers.sql
-- ============================================================

USE book_bank;

-- ============================================================
-- VIEW 1: vw_book_availability
-- Shows current stock status for all active books.
-- Use: SELECT * FROM vw_book_availability;
--      SELECT * FROM vw_book_availability WHERE availability = 'Not Available';
-- ============================================================
DROP VIEW IF EXISTS vw_book_availability$$;

CREATE VIEW vw_book_availability AS
SELECT
  b.book_id,
  b.isbn,
  b.title,
  b.author,
  b.category,
  b.publisher,
  b.total_qty,
  b.available_qty,
  (b.total_qty - b.available_qty)           AS copies_on_loan,
  CASE
    WHEN b.available_qty > 0 THEN 'Available'
    ELSE 'Not Available'
  END                                        AS availability
FROM books b
WHERE b.is_active = 1
ORDER BY b.category, b.title;


-- ============================================================
-- VIEW 2: vw_overdue_transactions
-- Lists all currently overdue books (issued but past due date).
-- Use: SELECT * FROM vw_overdue_transactions;
--      SELECT * FROM vw_overdue_transactions ORDER BY days_overdue DESC;
-- ============================================================
DROP VIEW IF EXISTS vw_overdue_transactions;

CREATE VIEW vw_overdue_transactions AS
SELECT
  t.txn_id,
  m.member_id,
  m.name                                      AS member_name,
  m.email,
  m.department,
  b.book_id,
  b.title                                     AS book_title,
  b.isbn,
  t.issue_date,
  t.due_date,
  DATEDIFF(CURRENT_DATE, t.due_date)          AS days_overdue,
  DATEDIFF(CURRENT_DATE, t.due_date) * 2.00  AS estimated_fine_rs
FROM transactions t
JOIN members m ON t.member_id = m.member_id
JOIN books   b ON t.book_id   = b.book_id
WHERE t.status    = 'issued'
  AND t.due_date  < CURRENT_DATE
ORDER BY days_overdue DESC;


-- ============================================================
-- VIEW 3: vw_member_history
-- Full borrowing history per member with fine status.
-- Use: SELECT * FROM vw_member_history WHERE member_id = 1;
--      SELECT * FROM vw_member_history WHERE fine_status = 'unpaid';
-- ============================================================
DROP VIEW IF EXISTS vw_member_history;

CREATE VIEW vw_member_history AS
SELECT
  m.member_id,
  m.name                                         AS member_name,
  m.department,
  t.txn_id,
  b.title                                        AS book_title,
  b.isbn,
  t.issue_date,
  t.due_date,
  t.return_date,
  t.status                                       AS txn_status,
  COALESCE(f.amount, 0.00)                       AS fine_amount,
  COALESCE(f.status, 'no fine')                  AS fine_status,
  f.paid_on
FROM transactions t
JOIN members m ON t.member_id = m.member_id
JOIN books   b ON t.book_id   = b.book_id
LEFT JOIN fines f ON f.txn_id = t.txn_id
ORDER BY m.member_id, t.issue_date DESC;


-- ============================================================
-- VIEW 4: vw_active_borrows
-- All books currently out on loan with due dates.
-- Use: SELECT * FROM vw_active_borrows;
-- ============================================================
DROP VIEW IF EXISTS vw_active_borrows;

CREATE VIEW vw_active_borrows AS
SELECT
  t.txn_id,
  m.name          AS member_name,
  m.department,
  b.title         AS book_title,
  b.isbn,
  t.issue_date,
  t.due_date,
  DATEDIFF(t.due_date, CURRENT_DATE) AS days_remaining,
  CASE
    WHEN DATEDIFF(t.due_date, CURRENT_DATE) < 0  THEN 'Overdue'
    WHEN DATEDIFF(t.due_date, CURRENT_DATE) <= 3 THEN 'Due Soon'
    ELSE 'On Time'
  END AS borrow_health
FROM transactions t
JOIN members m ON t.member_id = m.member_id
JOIN books   b ON t.book_id   = b.book_id
WHERE t.status = 'issued'
ORDER BY t.due_date ASC;


-- ============================================================
-- VIEW 5: vw_pending_reservations
-- All reservations currently waiting or flagged available.
-- Use: SELECT * FROM vw_pending_reservations;
-- ============================================================
DROP VIEW IF EXISTS vw_pending_reservations;

CREATE VIEW vw_pending_reservations AS
SELECT
  r.reservation_id,
  m.name       AS member_name,
  m.email,
  b.title      AS book_title,
  b.isbn,
  r.reserved_on,
  r.status     AS reservation_status,
  DATEDIFF(NOW(), r.reserved_on) AS days_waiting
FROM reservations r
JOIN members m ON r.member_id = m.member_id
JOIN books   b ON r.book_id   = b.book_id
WHERE r.status IN ('waiting', 'available')
ORDER BY r.reserved_on ASC;


-- ============================================================
-- VIEW 6: vw_fine_summary
-- Summary of all fines — useful for admin reporting.
-- ============================================================
DROP VIEW IF EXISTS vw_fine_summary;

CREATE VIEW vw_fine_summary AS
SELECT
  f.fine_id,
  m.name         AS member_name,
  m.department,
  b.title        AS book_title,
  t.due_date,
  t.return_date,
  DATEDIFF(t.return_date, t.due_date) AS days_late,
  f.amount       AS fine_rs,
  f.status       AS payment_status,
  f.paid_on
FROM fines f
JOIN transactions t ON f.txn_id    = t.txn_id
JOIN members      m ON f.member_id = m.member_id
JOIN books        b ON t.book_id   = b.book_id
ORDER BY f.created_at DESC;


-- ============================================================
-- ANALYTICAL QUERIES
-- Run these directly after loading seed data to see reports.
-- ============================================================

-- Q1: Monthly fine collection report
SELECT
  DATE_FORMAT(paid_on, '%Y-%m')  AS month,
  COUNT(*)                        AS fines_paid,
  SUM(amount)                     AS total_collected_rs
FROM fines
WHERE status = 'paid'
GROUP BY DATE_FORMAT(paid_on, '%Y-%m')
ORDER BY month;


-- Q2: Most borrowed books (top 5)
SELECT
  b.title,
  b.author,
  COUNT(t.txn_id) AS times_borrowed
FROM transactions t
JOIN books b ON t.book_id = b.book_id
GROUP BY b.book_id, b.title, b.author
ORDER BY times_borrowed DESC
LIMIT 5;


-- Q3: Members with most borrowing activity
SELECT
  m.name,
  m.department,
  COUNT(t.txn_id)                                    AS total_borrows,
  SUM(CASE WHEN t.status = 'issued'   THEN 1 ELSE 0 END) AS active_borrows,
  SUM(CASE WHEN t.status = 'returned' THEN 1 ELSE 0 END) AS returned,
  COALESCE(SUM(f.amount), 0)                         AS total_fines_rs
FROM members m
LEFT JOIN transactions t ON m.member_id = t.member_id
LEFT JOIN fines        f ON m.member_id = f.member_id
GROUP BY m.member_id, m.name, m.department
ORDER BY total_borrows DESC;


-- Q4: Books never borrowed (dead stock report)
SELECT b.book_id, b.isbn, b.title, b.author, b.category, b.total_qty
FROM books b
WHERE b.is_active = 1
  AND b.book_id NOT IN (SELECT DISTINCT book_id FROM transactions)
ORDER BY b.category, b.title;


-- Q5: Department-wise borrow statistics
SELECT
  m.department,
  COUNT(DISTINCT m.member_id)   AS total_members,
  COUNT(t.txn_id)               AS total_borrows,
  SUM(COALESCE(f.amount, 0))    AS total_fines_rs
FROM members m
LEFT JOIN transactions t ON m.member_id = t.member_id
LEFT JOIN fines        f ON t.txn_id    = f.txn_id
GROUP BY m.department
ORDER BY total_borrows DESC;


-- ============================================================
-- Verify all views created
-- ============================================================
SELECT table_name AS view_name
FROM information_schema.views
WHERE table_schema = 'book_bank'
ORDER BY table_name;

SELECT 'All views and analytical queries ready.' AS message;
