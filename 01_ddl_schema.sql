-- ============================================================
-- BOOK BANK MANAGEMENT SYSTEM
-- Module : DDL — Database Schema
-- File   : 01_ddl_schema.sql
-- DB     : MySQL 8.0+
-- Run    : SOURCE 01_ddl_schema.sql;
-- ============================================================

-- Step 1: Create and select the database
CREATE DATABASE IF NOT EXISTS book_bank
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE book_bank;

-- ============================================================
-- TABLE 1: books
-- Stores the master catalog of all books in the bank.
-- ============================================================
CREATE TABLE IF NOT EXISTS books (
  book_id       INT             NOT NULL AUTO_INCREMENT,
  isbn          VARCHAR(13)     NOT NULL,
  title         VARCHAR(200)    NOT NULL,
  author        VARCHAR(100)    NOT NULL,
  category      VARCHAR(60)     NOT NULL,
  publisher     VARCHAR(100)    DEFAULT NULL,
  pub_year      YEAR            DEFAULT NULL,
  total_qty     INT             NOT NULL DEFAULT 1,
  available_qty INT             NOT NULL DEFAULT 1,
  is_active     TINYINT(1)      NOT NULL DEFAULT 1,
  created_at    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT pk_books       PRIMARY KEY (book_id),
  CONSTRAINT uq_books_isbn  UNIQUE      (isbn),

  -- Ensure stock values are always non-negative
  CONSTRAINT chk_total_qty     CHECK (total_qty     >= 0),
  CONSTRAINT chk_available_qty CHECK (available_qty >= 0),
  CONSTRAINT chk_qty_logic     CHECK (available_qty <= total_qty)
) ENGINE=InnoDB;


-- ============================================================
-- TABLE 2: members
-- Stores student/member registration details.
-- ============================================================
CREATE TABLE IF NOT EXISTS members (
  member_id   INT           NOT NULL AUTO_INCREMENT,
  name        VARCHAR(100)  NOT NULL,
  email       VARCHAR(100)  NOT NULL,
  phone       VARCHAR(15)   DEFAULT NULL,
  department  VARCHAR(60)   DEFAULT NULL,
  join_date   DATE          NOT NULL DEFAULT (CURRENT_DATE),
  is_active   TINYINT(1)    NOT NULL DEFAULT 1,
  created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT pk_members      PRIMARY KEY (member_id),
  CONSTRAINT uq_member_email UNIQUE      (email)
) ENGINE=InnoDB;


-- ============================================================
-- TABLE 3: transactions
-- Records every book issue and return event.
-- ============================================================
CREATE TABLE IF NOT EXISTS transactions (
  txn_id      INT       NOT NULL AUTO_INCREMENT,
  member_id   INT       NOT NULL,
  book_id     INT       NOT NULL,
  issue_date  DATE      NOT NULL DEFAULT (CURRENT_DATE),
  due_date    DATE      NOT NULL,                          -- issue_date + 30 days (set by procedure)
  return_date DATE      DEFAULT NULL,                     -- NULL until book is returned
  status      ENUM('issued', 'returned') NOT NULL DEFAULT 'issued',
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT pk_transactions PRIMARY KEY (txn_id),
  CONSTRAINT fk_txn_member   FOREIGN KEY (member_id) REFERENCES members (member_id) ON DELETE RESTRICT,
  CONSTRAINT fk_txn_book     FOREIGN KEY (book_id)   REFERENCES books   (book_id)   ON DELETE RESTRICT,
  CONSTRAINT chk_due_after_issue CHECK (due_date >= issue_date)
) ENGINE=InnoDB;


-- ============================================================
-- TABLE 4: fines
-- Stores overdue fines linked to transactions.
-- One transaction can generate at most one fine.
-- ============================================================
CREATE TABLE IF NOT EXISTS fines (
  fine_id    INT            NOT NULL AUTO_INCREMENT,
  txn_id     INT            NOT NULL,
  member_id  INT            NOT NULL,
  amount     DECIMAL(8, 2)  NOT NULL,
  status     ENUM('unpaid', 'paid') NOT NULL DEFAULT 'unpaid',
  paid_on    DATETIME       DEFAULT NULL,
  created_at TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT pk_fines       PRIMARY KEY (fine_id),
  CONSTRAINT uq_fine_txn    UNIQUE      (txn_id),          -- one fine per transaction
  CONSTRAINT fk_fine_txn    FOREIGN KEY (txn_id)    REFERENCES transactions (txn_id)  ON DELETE RESTRICT,
  CONSTRAINT fk_fine_member FOREIGN KEY (member_id) REFERENCES members      (member_id) ON DELETE RESTRICT,
  CONSTRAINT chk_fine_amount CHECK (amount > 0)
) ENGINE=InnoDB;


-- ============================================================
-- TABLE 5: reservations
-- Queue of members waiting for an unavailable book.
-- ============================================================
CREATE TABLE IF NOT EXISTS reservations (
  reservation_id INT      NOT NULL AUTO_INCREMENT,
  member_id      INT      NOT NULL,
  book_id        INT      NOT NULL,
  reserved_on    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status         ENUM('waiting', 'available', 'cancelled', 'fulfilled')
                          NOT NULL DEFAULT 'waiting',
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT pk_reservations PRIMARY KEY (reservation_id),
  CONSTRAINT fk_res_member   FOREIGN KEY (member_id) REFERENCES members (member_id) ON DELETE RESTRICT,
  CONSTRAINT fk_res_book     FOREIGN KEY (book_id)   REFERENCES books   (book_id)   ON DELETE RESTRICT,
  -- A member may hold only one active reservation per book
  CONSTRAINT uq_active_res   UNIQUE (member_id, book_id)
) ENGINE=InnoDB;


-- ============================================================
-- INDEXES
-- Created separately for clarity; cover the most-queried columns.
-- ============================================================

-- books
CREATE INDEX idx_books_title    ON books  (title);
CREATE INDEX idx_books_author   ON books  (author);
CREATE INDEX idx_books_category ON books  (category);
CREATE INDEX idx_books_active   ON books  (is_active);

-- members
CREATE INDEX idx_members_dept   ON members (department);
CREATE INDEX idx_members_active ON members (is_active);

-- transactions
CREATE INDEX idx_txn_member     ON transactions (member_id);
CREATE INDEX idx_txn_book       ON transactions (book_id);
CREATE INDEX idx_txn_due_date   ON transactions (due_date);
CREATE INDEX idx_txn_status     ON transactions (status);

-- fines
CREATE INDEX idx_fines_member   ON fines (member_id);
CREATE INDEX idx_fines_status   ON fines (status);

-- reservations
CREATE INDEX idx_res_book       ON reservations (book_id);
CREATE INDEX idx_res_status     ON reservations (status);

-- ============================================================
-- DONE
-- ============================================================
SELECT 'DDL complete — book_bank schema created successfully.' AS message;
