-- =============================================
-- Project: Credit Card Transaction Fraud Detection (SQL EDA)
-- =============================================

-- Drop existing objects (rerun safety)
DROP TABLE IF EXISTS Transactions;
DROP TABLE IF EXISTS Cards;
DROP TABLE IF EXISTS Merchants;
DROP TABLE IF EXISTS Customers;

-- =============================================
-- 1) Schema
-- =============================================
CREATE TABLE Customers (
    customer_id INT PRIMARY KEY,
    name VARCHAR(100),
    segment VARCHAR(50),
    country CHAR(2) -- ISO country code
);

CREATE TABLE Cards (
    card_id INT PRIMARY KEY,
    customer_id INT,
    card_type VARCHAR(20),     -- Visa/Master/Amex
    open_date DATE,
    status VARCHAR(20),        -- Active/Blocked
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);

CREATE TABLE Merchants (
    merchant_id INT PRIMARY KEY,
    name VARCHAR(100),
    category VARCHAR(50),      -- e.g., ecommerce, bar, crypto, retail
    country CHAR(2),
    risk_flag CHAR(1)          -- 'Y' if high risk
);

CREATE TABLE Transactions (
    txn_id INT PRIMARY KEY,
    card_id INT,
    merchant_id INT,
    txn_ts TIMESTAMP,
    amount DECIMAL(12,2),
    currency CHAR(3),
    country CHAR(2),
    channel VARCHAR(10),       -- pos/ecom/atm
    status VARCHAR(20),        -- approved/declined/chargeback
    FOREIGN KEY (card_id) REFERENCES Cards(card_id),
    FOREIGN KEY (merchant_id) REFERENCES Merchants(merchant_id)
);

-- =============================================
-- 2) Sample Data
-- =============================================
INSERT INTO Customers VALUES
(1,'Amit Kumar','Retail','IN'),
(2,'Jyoti Sharma','Retail','IN'),
(3,'Rahul Verma','Premier','UK');

INSERT INTO Cards VALUES
(201,1,'VISA','2023-01-10','Active'),
(202,2,'MC','2023-02-15','Active'),
(203,3,'VISA','2022-12-01','Active');

INSERT INTO Merchants VALUES
(301,'Flipkart','ecommerce','IN','N'),
(302,'NightBar','bar','IN','Y'),
(303,'HeathrowDutyFree','retail','UK','N'),
(304,'CryptoEx','crypto','LT','Y'),
(305,'AmazonUK','ecommerce','UK','N');

-- txn_id, card_id, merchant_id, txn_ts, amount, currency, country, channel, status
INSERT INTO Transactions VALUES
(10001,201,301,'2025-07-10 10:00:00',12000,'INR','IN','ecom','approved'),
(10002,201,301,'2025-07-10 10:05:00',15000,'INR','IN','ecom','approved'),
(10003,201,302,'2025-07-10 23:45:00',45000,'INR','IN','pos','approved'),
(10004,201,302,'2025-07-11 00:10:00',60000,'INR','IN','pos','chargeback'),
(10005,202,304,'2025-07-12 09:05:00',90000,'INR','IN','ecom','approved'),
(10006,202,305,'2025-07-12 11:00:00',500,'GBP','UK','ecom','approved'),
(10007,203,303,'2025-07-13 08:00:00',300,'GBP','UK','pos','approved'),
(10008,203,303,'2025-07-13 08:04:00',400,'GBP','UK','pos','approved'),
(10009,203,304,'2025-07-13 22:30:00',200000,'EUR','LT','ecom','approved');

-- =============================================
-- 3) Analytic Queries / Views
-- =============================================

-- A) High-value transactions (threshold configurable)
CREATE OR REPLACE VIEW vw_high_value AS
SELECT t.txn_id, t.card_id, cst.name AS customer, m.name AS merchant, t.amount, t.txn_ts
FROM Transactions t
JOIN Cards cd   ON cd.card_id = t.card_id
JOIN Customers cst ON cst.customer_id = cd.customer_id
JOIN Merchants m ON m.merchant_id = t.merchant_id
WHERE t.amount > 50000;

-- B) Rapid-fire transactions (<= 5 minutes between consecutive txns on same card)
-- Postgres syntax; for MySQL replace EXTRACT(EPOCH FROM (t.txn_ts - prev_ts))/60 with TIMESTAMPDIFF(MINUTE, prev_ts, t.txn_ts)
CREATE OR REPLACE VIEW vw_rapid_fire AS
WITH ordered AS (
  SELECT t.*,
         LAG(t.txn_ts) OVER (PARTITION BY t.card_id ORDER BY t.txn_ts) AS prev_ts
  FROM Transactions t
)
SELECT txn_id, card_id, txn_ts, amount,
       EXTRACT(EPOCH FROM (txn_ts - prev_ts))/60 AS minutes_since_prev
FROM ordered
WHERE prev_ts IS NOT NULL
  AND EXTRACT(EPOCH FROM (txn_ts - prev_ts))/60 <= 5;

-- C) Night-time high-value (22:00–06:00) and amount > 20000
CREATE OR REPLACE VIEW vw_night_high AS
SELECT t.txn_id, t.card_id, t.amount, t.txn_ts
FROM Transactions t
WHERE (EXTRACT(HOUR FROM t.txn_ts) >= 22 OR EXTRACT(HOUR FROM t.txn_ts) < 6)
  AND t.amount > 20000;

-- D) Risky merchants (risk_flag = 'Y')
CREATE OR REPLACE VIEW vw_risky_merchants AS
SELECT t.txn_id, t.card_id, m.name AS merchant, m.category, t.amount, t.txn_ts
FROM Transactions t
JOIN Merchants m ON m.merchant_id = t.merchant_id
WHERE m.risk_flag = 'Y';

-- E) Impossible travel (country changed within 120 minutes on same card)
CREATE OR REPLACE VIEW vw_impossible_travel AS
WITH ordered AS (
  SELECT t.*,
         LAG(t.country) OVER (PARTITION BY t.card_id ORDER BY t.txn_ts) AS prev_country,
         LAG(t.txn_ts)  OVER (PARTITION BY t.card_id ORDER BY t.txn_ts) AS prev_ts
  FROM Transactions t
)
SELECT txn_id, card_id, country, prev_country, txn_ts,
       EXTRACT(EPOCH FROM (txn_ts - prev_ts))/60 AS minutes_since_prev
FROM ordered
WHERE prev_country IS NOT NULL
  AND country <> prev_country
  AND EXTRACT(EPOCH FROM (txn_ts - prev_ts))/60 <= 120;

-- F) Chargeback rate by card
CREATE OR REPLACE VIEW vw_chargeback_rate AS
SELECT t.card_id,
       COUNT(*) FILTER (WHERE t.status = 'chargeback')::DECIMAL / COUNT(*) * 100 AS chargeback_pct,
       COUNT(*) AS total_txns
FROM Transactions t
GROUP BY t.card_id;

-- G) Merchant risk summary
CREATE OR REPLACE VIEW vw_merchant_summary AS
SELECT m.merchant_id, m.name, m.category, m.risk_flag,
       COUNT(t.txn_id) AS txn_count,
       SUM(t.amount) AS total_amount
FROM Merchants m
LEFT JOIN Transactions t ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_id, m.name, m.category, m.risk_flag
ORDER BY total_amount DESC NULLS LAST;
