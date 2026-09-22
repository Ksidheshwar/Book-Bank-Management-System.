
-- Module : Stored Procedures

DELIMITER $$

-- ============================================================
-- PROCEDURE 1: sp_issue_book
-- Issues a book to a member after validating all business rules.
-- Validation order:
--   1. Member must exist and be active
--   2. Member must have < 3 active borrows
--   3. Member must have no unpaid fines
--   4. Book must exist and be active
--   5. Book must have available_qty > 0
-- On success: inserts a transaction row (trigger handles qty decrement)
-- ============================================================
DROP PROCEDURE IF EXISTS sp_issue_book$$

CREATE PROCEDURE sp_issue_book (
  IN  p_member_id  INT,
  IN  p_book_id    INT,
  OUT p_txn_id     INT,
  OUT p_message    VARCHAR(200)
)
BEGIN
  DECLARE v_is_active_member  TINYINT DEFAULT 0;
  DECLARE v_active_borrows    INT     DEFAULT 0;
  DECLARE v_unpaid_fines      INT     DEFAULT 0;
  DECLARE v_is_active_book    TINYINT DEFAULT 0;
  DECLARE v_available_qty     INT     DEFAULT 0;

  -- Initialise OUT params
  SET p_txn_id  = NULL;  
  -- 1. Validate member

  SET p_message = '';

  START TRANSACTION;

  SELECT is_active INTO v_is_active_member
  FROM members WHERE member_id = p_member_id;

  IF v_is_active_member IS NULL THEN
    ROLLBACK;
    SET p_message = ' Member not found.';
    LEAVE sp_issue_book;   -- jump to end label
  END IF;

  IF v_is_active_member = 0 THEN
    ROLLBACK;
    SET p_message = 'ERROR: Member account is deactivated.';
    LEAVE sp_issue_book;
  END IF;

  -- 2. Check active borrow count (max 3)
  SELECT COUNT(*) INTO v_active_borrows
  FROM transactions
  WHERE member_id = p_member_id AND status = 'issued';

  IF v_active_borrows >= 3 THEN
    ROLLBACK;
    SET p_message = 'ERROR: Member already has 3 active borrows. Return a book first.';
    LEAVE sp_issue_book;
  END IF;

  -- 3. Check unpaid fines
  SELECT COUNT(*) INTO v_unpaid_fines
  FROM fines
  WHERE member_id = p_member_id AND status = 'unpaid';

  IF v_unpaid_fines > 0 THEN
    ROLLBACK;
    SET p_message = 'ERROR: Member has unpaid fines. Please clear dues before borrowing.';
    LEAVE sp_issue_book;
  END IF;

  -- 4. Validate book
  SELECT is_active, available_qty
  INTO v_is_active_book, v_available_qty
  FROM books WHERE book_id = p_book_id;

  IF v_is_active_book IS NULL THEN
    ROLLBACK;
    SET p_message = ' Book not found.';
    LEAVE sp_issue_book;
  END IF;

  IF v_is_active_book = 0 THEN
    ROLLBACK;
    SET p_message = 'ERROR: Book has been deactivated from the catalog.';
    LEAVE sp_issue_book;
  END IF;

  -- 5. Check availability
  IF v_available_qty <= 0 THEN
    ROLLBACK;
    SET p_message = 'ERROR: Book is not available. Consider reserving it.';
    LEAVE sp_issue_book;
  END IF;

  -- All validations passed — insert transaction
  -- due_date = issue_date + 30 days
  INSERT INTO transactions (member_id, book_id, issue_date, due_date, status)
  VALUES (p_member_id, p_book_id, CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL 30 DAY), 'issued');

  SET p_txn_id  = LAST_INSERT_ID();
  SET p_message = CONCAT('SUCCESS: Book issued. Transaction ID = ', p_txn_id,
                         '. Due date: ', DATE_ADD(CURRENT_DATE, INTERVAL 30 DAY));

  COMMIT;

END$$  

-- PROCEDURE 2: sp_return_book

DROP PROCEDURE IF EXISTS sp_return_book$$

CREATE PROCEDURE sp_return_book (
  IN  p_txn_id   INT,
  OUT p_message  VARCHAR(300)
)
BEGIN
  DECLARE v_status      VARCHAR(20);
  DECLARE v_due_date    DATE;
  DECLARE v_member_id   INT;
  DECLARE v_book_id     INT;
  DECLARE v_days_late   INT DEFAULT 0;
  DECLARE v_fine_amount DECIMAL(8,2) DEFAULT 0.00;

  SET p_message = '';

  START TRANSACTION;

  -- Fetch transaction details
  SELECT status, due_date, member_id, book_id
  INTO v_status, v_due_date, v_member_id, v_book_id
  FROM transactions WHERE txn_id = p_txn_id FOR UPDATE;

  IF v_status IS NULL THEN
    ROLLBACK;
    SET p_message = 'ERROR: Transaction not found.';
    LEAVE sp_return_book;
  END IF;

  IF v_status = 'returned' THEN
    ROLLBACK;
    SET p_message = 'ERROR: Book has already been returned for this transaction.';
    LEAVE sp_return_book;
  END IF;

  -- Mark as returned
  UPDATE transactions
  SET return_date = CURRENT_DATE,
      status      = 'returned'
  WHERE txn_id = p_txn_id;

  -- Calculate fine if overdue
  SET v_days_late = DATEDIFF(CURRENT_DATE, v_due_date);

  IF v_days_late > 0 THEN
    SET v_fine_amount = v_days_late * 2.00;  -- Rs. 2 per day

    INSERT INTO fines (txn_id, member_id, amount, status)
    VALUES (p_txn_id, v_member_id, v_fine_amount, 'unpaid');

    SET p_message = CONCAT('SUCCESS: Book returned. Overdue by ', v_days_late,
                           ' day(s). Fine generated: Rs.', v_fine_amount,
                           '. Please pay to borrow again.');
  ELSE
    SET p_message = CONCAT('SUCCESS: Book returned on time. No fine. Thank you!');
  END IF;

  COMMIT;
  -- NOTE: trg_after_return fires here: increments available_qty and flags reservations

END$$


-- ============================================================
-- PROCEDURE 3: sp_pay_fine
-- Records payment of a fine for a member.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_pay_fine$$

CREATE PROCEDURE sp_pay_fine (
  IN  p_fine_id  INT,
  OUT p_message  VARCHAR(200)
)
BEGIN
  DECLARE v_status    VARCHAR(20);
  DECLARE v_amount    DECIMAL(8,2);

  SET p_message = '';

  SELECT status, amount INTO v_status, v_amount
  FROM fines WHERE fine_id = p_fine_id;

  IF v_status IS NULL THEN
    SET p_message = 'ERROR: Fine record not found.';
    LEAVE sp_pay_fine;
  END IF;

  IF v_status = 'paid' THEN
    SET p_message = 'ERROR: This fine has already been paid.';
    LEAVE sp_pay_fine;
  END IF;

  UPDATE fines
  SET status  = 'paid',
      paid_on = NOW()
  WHERE fine_id = p_fine_id;

  SET p_message = CONCAT('SUCCESS: Fine of Rs.', v_amount, ' marked as paid. Member can now borrow again.');

END$$


-- ============================================================
-- PROCEDURE 4: sp_reserve_book
-- Places a reservation for a member when a book is unavailable.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_reserve_book$$

CREATE PROCEDURE sp_reserve_book (
  IN  p_member_id  INT,
  IN  p_book_id    INT,
  OUT p_message    VARCHAR(200)
)
BEGIN
  DECLARE v_available_qty    INT     DEFAULT 0;
  DECLARE v_is_active_member TINYINT DEFAULT 0;
  DECLARE v_existing_res     INT     DEFAULT 0;

  SET p_message = '';

  -- Validate member
  SELECT is_active INTO v_is_active_member
  FROM members WHERE member_id = p_member_id;

  IF v_is_active_member IS NULL OR v_is_active_member = 0 THEN
    SET p_message = 'ERROR: Member not found or deactivated.';
    LEAVE sp_reserve_book;
  END IF;

  -- Check book availability (reservation only valid when qty = 0)
  SELECT available_qty INTO v_available_qty
  FROM books WHERE book_id = p_book_id;

  IF v_available_qty IS NULL THEN
    SET p_message = 'ERROR: Book not found.';
    LEAVE sp_reserve_book;
  END IF;

  IF v_available_qty > 0 THEN
    SET p_message = 'INFO: Book is currently available. Please issue it directly instead of reserving.';
    LEAVE sp_reserve_book;
  END IF;

  -- Check for existing active reservation by this member for same book
  SELECT COUNT(*) INTO v_existing_res
  FROM reservations
  WHERE member_id = p_member_id
    AND book_id   = p_book_id
    AND status IN ('waiting', 'available');

  IF v_existing_res > 0 THEN
    SET p_message = 'ERROR: Member already has an active reservation for this book.';
    LEAVE sp_reserve_book;
  END IF;

  INSERT INTO reservations (member_id, book_id, reserved_on, status)
  VALUES (p_member_id, p_book_id, NOW(), 'waiting');

  SET p_message = CONCAT('SUCCESS: Reservation placed. Reservation ID = ',
                         LAST_INSERT_ID(), '. You will be notified when the book is available.');

END$$


-- ============================================================
-- PROCEDURE 5: sp_search_books
-- Searches the catalog by keyword (title or author partial match).
-- ============================================================
DROP PROCEDURE IF EXISTS sp_search_books$$

CREATE PROCEDURE sp_search_books (
  IN p_keyword VARCHAR(100)
)
BEGIN
  SELECT
    book_id,
    isbn,
    title,
    author,
    category,
    total_qty,
    available_qty,
    CASE WHEN available_qty > 0 THEN 'Available' ELSE 'Not Available' END AS availability
  FROM books
  WHERE is_active = 1
    AND (title LIKE CONCAT('%', p_keyword, '%')
      OR author LIKE CONCAT('%', p_keyword, '%'))
  ORDER BY title;
END$$


-- ============================================================
-- PROCEDURE 6: sp_member_summary
-- Returns a member's current status: borrows, fines, reservations.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_member_summary$$

CREATE PROCEDURE sp_member_summary (
  IN p_member_id INT
)
BEGIN
  -- Member info
  SELECT member_id, name, email, department, is_active FROM members
  WHERE member_id = p_member_id;

  -- Active borrows
  SELECT
    t.txn_id,
    b.title,
    t.issue_date,
    t.due_date,
    DATEDIFF(CURRENT_DATE, t.due_date) AS days_overdue
  FROM transactions t
  JOIN books b ON t.book_id = b.book_id
  WHERE t.member_id = p_member_id AND t.status = 'issued';

  -- Unpaid fines
  SELECT fine_id, txn_id, amount, status FROM fines
  WHERE member_id = p_member_id AND status = 'unpaid';

  -- Active reservations
  SELECT reservation_id, book_id, reserved_on, status FROM reservations
  WHERE member_id = p_member_id AND status IN ('waiting', 'available');
END$$

DELIMITER ;

SELECT 'All stored procedures created successfully.' AS message;
