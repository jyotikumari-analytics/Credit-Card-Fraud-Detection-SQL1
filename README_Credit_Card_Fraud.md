# 💳 Credit Card Transaction Fraud Detection (SQL EDA)

This project demonstrates **SQL-based fraud analytics** on credit card transactions: high-value spikes, rapid-fire swipes, night-time anomalies, risky merchants, impossible travel, and chargeback rates. Built to showcase **banking-domain SQL skills** for Data Analyst roles.

---

## 📂 Schema
**Tables**
- `Customers(customer_id, name, segment, country)`
- `Cards(card_id, customer_id, card_type, open_date, status)`
- `Merchants(merchant_id, name, category, country, risk_flag)`
- `Transactions(txn_id, card_id, merchant_id, txn_ts, amount, currency, country, channel, status)`

---

## 🧪 Sample Data Highlights
- Risky merchants: `NightBar (bar)`, `CryptoEx (crypto)`
- Night-time + high-value swipes present
- Cross-country same-card usage within 2 hours (impossible travel)
- One chargeback for realistic dispute rate

---

## 🔎 Analytics & Expected Output

### A) High-value transactions (> 50,000)
```sql
SELECT * FROM vw_high_value;
```
**Expected rows**
| txn_id | card_id | customer     | merchant | amount  | txn_ts              |
|-------:|--------:|--------------|----------|--------:|---------------------|
| 10004  | 201     | Amit Kumar   | NightBar |  60000  | 2025-07-11 00:10:00 |
| 10005  | 202     | Jyoti Sharma | CryptoEx |  90000  | 2025-07-12 09:05:00 |
| 10009  | 203     | Rahul Verma  | CryptoEx | 200000  | 2025-07-13 22:30:00 |

---

### B) Rapid-fire transactions (≤ 5 minutes on same card)
```sql
SELECT * FROM vw_rapid_fire;
```
**Expected rows**
| txn_id | card_id | txn_ts              | amount | minutes_since_prev |
|-------:|--------:|---------------------|-------:|-------------------:|
| 10002  | 201     | 2025-07-10 10:05:00 |  15000 |                5.0 |
| 10008  | 203     | 2025-07-13 08:04:00 |    400 |                4.0 |

> 🔁 Postgres uses `EXTRACT(EPOCH FROM ...)`; in MySQL, use `TIMESTAMPDIFF(MINUTE, prev_ts, txn_ts)`.

---

### C) Night-time high-value (22:00–06:00 & amount > 20,000)
```sql
SELECT * FROM vw_night_high;
```
**Expected rows**
| txn_id | card_id | amount | txn_ts              |
|-------:|--------:|-------:|---------------------|
| 10003  | 201     |  45000 | 2025-07-10 23:45:00 |
| 10004  | 201     |  60000 | 2025-07-11 00:10:00 |
| 10009  | 203     | 200000 | 2025-07-13 22:30:00 |

---

### D) Risky merchants (merchant.risk_flag = 'Y')
```sql
SELECT * FROM vw_risky_merchants;
```
**Expected rows (subset)**
| txn_id | card_id | merchant | category | amount | txn_ts              |
|-------:|--------:|----------|----------|-------:|---------------------|
| 10003  | 201     | NightBar | bar      |  45000 | 2025-07-10 23:45:00 |
| 10004  | 201     | NightBar | bar      |  60000 | 2025-07-11 00:10:00 |
| 10005  | 202     | CryptoEx | crypto   |  90000 | 2025-07-12 09:05:00 |
| 10009  | 203     | CryptoEx | crypto   | 200000 | 2025-07-13 22:30:00 |

---

### E) Impossible travel (country changed within 120 minutes)
```sql
SELECT * FROM vw_impossible_travel;
```
**Expected rows**
| txn_id | card_id | country | prev_country | txn_ts              | minutes_since_prev |
|-------:|--------:|---------|--------------|---------------------|-------------------:|
| 10006  | 202     | UK      | IN           | 2025-07-12 11:00:00 |              115.0 |

---

### F) Chargeback rate by card
```sql
SELECT * FROM vw_chargeback_rate;
```
**Expected rows**
| card_id | chargeback_pct | total_txns |
|--------:|----------------:|-----------:|
| 201     |           25.0  |          4 |
| 202     |            0.0  |          2 |
| 203     |            0.0  |          3 |

---

### G) Merchant risk summary
```sql
SELECT * FROM vw_merchant_summary;
```
**Example (ordered by total_amount desc)**
| merchant_id | name             | category  | risk_flag | txn_count | total_amount |
|------------:|------------------|-----------|-----------|----------:|-------------:|
| 304         | CryptoEx         | crypto    | Y         |         2 |       290000 |
| 302         | NightBar         | bar       | Y         |         2 |       105000 |
| 301         | Flipkart         | ecommerce | N         |         2 |        27000 |
| 303         | HeathrowDutyFree | retail    | N         |         2 |          700 |
| 305         | AmazonUK         | ecommerce | N         |         1 |          500 |

---

## 🚀 How to Run
1. Run `Credit_Card_Fraud_SQL.sql` in PostgreSQL (or adapt notes for MySQL TIMESTAMPDIFF).
2. Query the prebuilt views listed above.
3. Export results to CSV/Excel if needed for screenshots.

---

## 🧰 Tech
SQL (PostgreSQL/MySQL). Uses **window functions, time diffs, aggregates, views**.

---

## 📁 Files
- `Credit_Card_Fraud_SQL.sql` – schema, sample data, views
- `README_Credit_Card_Fraud.md` – documentation and expected outputs

---
