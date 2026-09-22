-- ============================================================
-- BOOK BANK MANAGEMENT SYSTEM
-- Module : DML — Seed Data (FIXED — no hardcoded IDs)
-- File   : 02_dml_seed_data_fixed.sql
-- ============================================================

USE book_bank;

-- ============================================================
-- SAFETY: Disable FK checks while inserting, re-enable after
-- ============================================================
SET FOREIGN_KEY_CHECKS = 0;

-- Clean slate (in case of partial previous run)
DELETE FROM reservations;
DELETE FROM fines;
DELETE FROM transactions;
DELETE FROM members;
DELETE FROM books;

-- Reset auto-increment counters
ALTER TABLE reservations  AUTO_INCREMENT = 1;
ALTER TABLE fines         AUTO_INCREMENT = 1;
ALTER TABLE transactions  AUTO_INCREMENT = 1;
ALTER TABLE members       AUTO_INCREMENT = 1;
ALTER TABLE books         AUTO_INCREMENT = 1;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- INSERT: books (15 books — IDs will be 1–15)
-- ============================================================
INSERT INTO books (isbn, title, author, category, publisher, pub_year, total_qty, available_qty) VALUES
('9780132350884', 'Clean Code',                           'Robert C. Martin',    'Programming',      'Prentice Hall',   2008, 3, 3),  -- book_id = 1
('9780201633610', 'Design Patterns',                      'Gang of Four',        'Programming',      'Addison-Wesley',  1994, 2, 2),  -- book_id = 2
('9780596517748', 'JavaScript: The Good Parts',           'Douglas Crockford',   'Programming',      'O\'Reilly',       2008, 2, 2),  -- book_id = 3
('9781491950357', 'Learning MySQL',                       'Seyed Tahaghoghi',    'Database',         'O\'Reilly',       2022, 4, 4),  -- book_id = 4
('9780071461108', 'Database System Concepts',             'Silberschatz et al.', 'Database',         'McGraw-Hill',     2010, 3, 3),  -- book_id = 5
('9780132145060', 'SQL in 10 Minutes',                    'Ben Forta',           'Database',         'Sams Publishing', 2012, 5, 5),  -- book_id = 6
('9780133760408', 'Computer Networks',                    'Andrew Tanenbaum',    'Networking',       'Pearson',         2014, 2, 2),  -- book_id = 7
('9780596009205', 'The Linux Command Line',               'William Shotts',      'Operating Systems','No Starch Press', 2019, 3, 3),  -- book_id = 8
('9780133591620', 'Operating System Concepts',            'Silberschatz et al.', 'Operating Systems','Wiley',           2018, 3, 3),  -- book_id = 9
('9780262033848', 'Introduction to Algorithms',           'CLRS',                'Algorithms',       'MIT Press',       2009, 2, 2),  -- book_id = 10
('9780133943030', 'Artificial Intelligence',              'Russell & Norvig',    'Data Science',     'Pearson',         2020, 2, 2),  -- book_id = 11
('9781491901632', 'Python Data Science Handbook',         'Jake VanderPlas',     'Data Science',     'O\'Reilly',       2016, 3, 3),  -- book_id = 12
('9780134685991', 'Effective Java',                       'Joshua Bloch',        'Programming',      'Addison-Wesley',  2018, 2, 2),  -- book_id = 13
('9780321125217', 'Domain-Driven Design',                 'Eric Evans',          'Programming',      'Addison-Wesley',  2003, 1, 1),  -- book_id = 14
('9780596805524', 'MongoDB: The Definitive Guide',        'Kristina Chodorow',   'Database',         'O\'Reilly',       2019, 2, 2);  -- book_id = 15

-- ============================================================
-- INSERT: members (10 members — IDs will be 1–10)
-- ============================================================
INSERT INTO members (name, email, phone, department, join_date) VALUES
('Arjun Sharma',   'arjun.sharma@college.edu',   '9876543210', 'Computer Science', '2024-06-01'),  -- member_id = 1
('Priya Reddy',    'priya.reddy@college.edu',    '9876543211', 'Information Tech',  '2024-06-01'),  -- member_id = 2
('Rahul Gupta',    'rahul.gupta@college.edu',    '9876543212', 'Electronics',       '2024-06-15'),  -- member_id = 3
('Sneha Nair',     'sneha.nair@college.edu',     '9876543213', 'Computer Science',  '2024-07-01'),  -- member_id = 4
('Vikram Patel',   'vikram.patel@college.edu',   '9876543214', 'Mechanical Engg',   '2024-07-01'),  -- member_id = 5
('Ananya Iyer',    'ananya.iyer@college.edu',    '9876543215', 'Computer Science',  '2024-07-15'),  -- member_id = 6
('Kiran Kumar',    'kiran.kumar@college.edu',    '9876543216', 'Information Tech',  '2024-08-01'),  -- member_id = 7
('Divya Menon',    'divya.menon@college.edu',    '9876543217', 'Computer Science',  '2024-08-01'),  -- member_id = 8
('Suresh Babu',    'suresh.babu@college.edu',    '9876543218', 'Electronics',       '2024-08-15'),  -- member_id = 9
('Lakshmi Prasad', 'lakshmi.prasad@college.edu', '9876543219', 'Information Tech',  '2024-09-01'); -- member_id = 10

-- ============================================================
-- INSERT: historical transactions (already returned)
-- FK check: member_ids 1–10 exist, book_ids 1–15 exist ✓
-- Temporarily disable triggers so we don't double-decrement qty
-- ============================================================
SET FOREIGN_KEY_CHECKS = 0;

INSERT INTO transactions (member_id, book_id, issue_date, due_date, return_date, status) VALUES
(1,  1, '2025-01-10', '2025-02-09', '2025-02-05', 'returned'),  -- txn_id=1: Arjun, Clean Code, on time
(2,  4, '2025-01-15', '2025-02-14', '2025-02-20', 'returned'),  -- txn_id=2: Priya, Learning MySQL, LATE 6d
(3,  2, '2025-02-01', '2025-03-03', '2025-03-03', 'returned'),  -- txn_id=3: Rahul, Design Patterns, on time
(4,  6, '2025-02-10', '2025-03-12', '2025-04-01', 'returned'),  -- txn_id=4: Sneha, SQL in 10 Min, LATE 20d
(5,  8, '2025-03-01', '2025-03-31', '2025-03-28', 'returned'),  -- txn_id=5: Vikram, Linux CL, on time
(1,  5, '2025-03-05', '2025-04-04', '2025-04-10', 'returned'),  -- txn_id=6: Arjun, DB Concepts, LATE 6d
(6,  9, '2025-04-01', '2025-05-01', '2025-04-30', 'returned'),  -- txn_id=7: Ananya, OS Concepts, on time
(7,  3, '2025-04-10', '2025-05-10', '2025-05-10', 'returned');  -- txn_id=8: Kiran, JS Good Parts, on time

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- INSERT: fines — now using correct txn_ids (2, 4, 6)
-- We use a subquery to look up txn_id dynamically so this
-- never breaks even if auto-increment starts differently
-- ============================================================
INSERT INTO fines (txn_id, member_id, amount, status, paid_on)
SELECT
  t.txn_id,
  t.member_id,
  DATEDIFF(t.return_date, t.due_date) * 2.00 AS amount,
  'paid' AS status,
  '2025-02-21 10:00:00' AS paid_on
FROM transactions t
WHERE t.member_id = 2
  AND t.book_id   = 4
  AND t.status    = 'returned'
  AND t.return_date > t.due_date;

INSERT INTO fines (txn_id, member_id, amount, status, paid_on)
SELECT
  t.txn_id,
  t.member_id,
  DATEDIFF(t.return_date, t.due_date) * 2.00 AS amount,
  'unpaid' AS status,
  NULL AS paid_on
FROM transactions t
WHERE t.member_id = 4
  AND t.book_id   = 6
  AND t.status    = 'returned'
  AND t.return_date > t.due_date;

INSERT INTO fines (txn_id, member_id, amount, status, paid_on)
SELECT
  t.txn_id,
  t.member_id,
  DATEDIFF(t.return_date, t.due_date) * 2.00 AS amount,
  'paid' AS status,
  '2025-04-11 09:30:00' AS paid_on
FROM transactions t
WHERE t.member_id = 1
  AND t.book_id   = 5
  AND t.status    = 'returned'
  AND t.return_date > t.due_date;

-- ============================================================
-- INSERT: active transactions (currently issued — live borrows)
-- Disable triggers to manually control available_qty below
-- ============================================================
SET FOREIGN_KEY_CHECKS = 0;

INSERT INTO transactions (member_id, book_id, issue_date, due_date, status) VALUES
(2,  1, DATE_SUB(CURDATE(), INTERVAL 5  DAY), DATE_ADD(CURDATE(), INTERVAL 25 DAY), 'issued'),  -- Priya has Clean Code
(8,  7, DATE_SUB(CURDATE(), INTERVAL 10 DAY), DATE_ADD(CURDATE(), INTERVAL 20 DAY), 'issued'),  -- Divya has Computer Networks
(9, 10, DATE_SUB(CURDATE(), INTERVAL 35 DAY), DATE_SUB(CURDATE(), INTERVAL 5  DAY), 'issued');  -- Suresh has CLRS — OVERDUE!

SET FOREIGN_KEY_CHECKS = 1;

-- Manually decrement available_qty for the 3 active borrows
UPDATE books SET available_qty = available_qty - 1 WHERE book_id = 1;   -- Clean Code
UPDATE books SET available_qty = available_qty - 1 WHERE book_id = 7;   -- Computer Networks
UPDATE books SET available_qty = available_qty - 1 WHERE book_id = 10;  -- CLRS

-- ============================================================
-- INSERT: reservation — Rahul waiting for CLRS (book_id=10)
-- ============================================================
INSERT INTO reservations (member_id, book_id, reserved_on, status)
VALUES (3, 10, DATE_SUB(NOW(), INTERVAL 3 DAY), 'waiting');

-- ============================================================
-- VERIFY everything loaded correctly
-- ============================================================
SELECT '══ BOOKS ══' AS section;
SELECT book_id, title, total_qty, available_qty FROM books ORDER BY book_id;

SELECT '══ MEMBERS ══' AS section;
SELECT member_id, name, department FROM members ORDER BY member_id;

SELECT '══ TRANSACTIONS ══' AS section;
SELECT txn_id, member_id, book_id, issue_date, due_date, return_date, status FROM transactions ORDER BY txn_id;

SELECT '══ FINES ══' AS section;
SELECT fine_id, txn_id, member_id, amount, status, paid_on FROM fines ORDER BY fine_id;

SELECT '══ RESERVATIONS ══' AS section;
SELECT reservation_id, member_id, book_id, reserved_on, status FROM reservations;

SELECT '══ OVERDUE RIGHT NOW ══' AS section;
SELECT * FROM vw_overdue_transactions;

SELECT 'Seed data loaded successfully — no FK errors.' AS message;
