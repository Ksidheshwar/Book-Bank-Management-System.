
-- Module : Triggers

USE book_bank;

DELIMITER $$

-- ============================================================
-- TRIGGER 1: trg_after_issue
-- Fires AFTER INSERT on transactions (status = 'issued').
-- Action: Decrements available_qty in books by 1.
-- This keeps stock in sync automatically without the procedure
-- having to do an extra UPDATE.
-- ============================================================
DROP TRIGGER IF EXISTS trg_after_issue$$

CREATE TRIGGER trg_after_issue
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
  -- Only decrement when a new issue is created (not a returned row)
  IF NEW.status = 'issued' THEN
    UPDATE books
    SET available_qty = available_qty - 1
    WHERE book_id = NEW.book_id;
  END IF;
END$$


-- ============================================================
-- TRIGGER 2: trg_after_return
-- Fires AFTER UPDATE on transactions when status changes to 'returned'.
-- Actions:
--   A) Increments available_qty in books by 1.
--   B) Flags the oldest 'waiting' reservation for this book
--      as 'available' (FIFO queue).
-- Note: Fine calculation is handled by sp_return_book procedure,
--       not here, to keep trigger logic focused on stock/reservations.
-- ============================================================
DROP TRIGGER IF EXISTS trg_after_return$$

CREATE TRIGGER trg_after_return
AFTER UPDATE ON transactions
FOR EACH ROW
BEGIN
  DECLARE v_oldest_reservation_id INT DEFAULT NULL;

  -- Only fire when status changes from 'issued' to 'returned'
  IF OLD.status = 'issued' AND NEW.status = 'returned' THEN

    -- A) Restore available stock
    UPDATE books
    SET available_qty = available_qty + 1
    WHERE book_id = NEW.book_id;

    -- B) Find the oldest waiting reservation for this book (FIFO)
    SELECT reservation_id INTO v_oldest_reservation_id
    FROM reservations
    WHERE book_id = NEW.book_id
      AND status  = 'waiting'
    ORDER BY reserved_on ASC
    LIMIT 1;

    -- If a reservation exists, flag it as 'available'
    IF v_oldest_reservation_id IS NOT NULL THEN
      UPDATE reservations
      SET status = 'available'
      WHERE reservation_id = v_oldest_reservation_id;
    END IF;

  END IF;
END$$


-- ============================================================
-- TRIGGER 3: trg_prevent_txn_delete
-- Fires BEFORE DELETE on transactions.
-- Blocks any attempt to delete transaction records to preserve
-- the audit trail (NFR-06).
-- ============================================================
DROP TRIGGER IF EXISTS trg_prevent_txn_delete$$

CREATE TRIGGER trg_prevent_txn_delete
BEFORE DELETE ON transactions
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'SECURITY: Deletion of transaction records is not permitted. Transactions are permanent audit records.';
END$$


-- ============================================================
-- TRIGGER 4: trg_prevent_fine_delete
-- Fires BEFORE DELETE on fines.
-- Blocks deletion of fine records (same audit trail policy).
-- ============================================================
DROP TRIGGER IF EXISTS trg_prevent_fine_delete$$

CREATE TRIGGER trg_prevent_fine_delete
BEFORE DELETE ON fines
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'SECURITY: Deletion of fine records is not permitted. Fine records are permanent audit records.';
END$$


-- ============================================================
-- TRIGGER 5: trg_validate_issue_qty
-- Fires BEFORE INSERT on transactions.
-- Double-checks available_qty > 0 at the DB level (safety net
-- in case someone bypasses the stored procedure).
-- ============================================================
DROP TRIGGER IF EXISTS trg_validate_issue_qty$$

CREATE TRIGGER trg_validate_issue_qty
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
  DECLARE v_qty INT DEFAULT 0;

  IF NEW.status = 'issued' THEN
    SELECT available_qty INTO v_qty
    FROM books WHERE book_id = NEW.book_id;

    IF v_qty <= 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: Cannot issue book — no copies available.';
    END IF;
  END IF;
END$$

DELIMITER ;

-- ============================================================
-- Verify all triggers created
-- ============================================================
SELECT trigger_name, event_manipulation, event_object_table, action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'book_bank'
ORDER BY event_object_table, action_timing;

SELECT 'All triggers created successfully.' AS message;
