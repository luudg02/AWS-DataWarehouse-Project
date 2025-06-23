# Hướng dẫn thực thi script SQL trên Amazon Athena

Script SQL của bạn đã được điều chỉnh để chạy trên Amazon Athena. Do Athena yêu cầu thực thi từng câu lệnh SQL riêng biệt, dưới đây là trình tự các bước để thực thi script đúng cách:

## Bước 1: Tạo database mới

```sql
CREATE DATABASE IF NOT EXISTS dw;
```

## Bước 2: Tạo các bảng fact

Thực hiện từng lệnh CREATE EXTERNAL TABLE lần lượt:

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS dw.fact_transaction (
    transaction_id INT,
    customer_id INT,
    transaction_date_id INT,
    channel_id INT,
    account_id INT,
    transaction_type_id INT,
    location_id INT,
    currency_id INT,
    loan_id INT,
    investment_type_id INT,
    transaction_amount DECIMAL(18, 2),
    transaction_status VARCHAR(50)
)
STORED AS PARQUET
LOCATION 's3://luvutu-s3/fact_transaction/';
```

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS dw.fact_daily_balance (
    balance_id INT,
    date_id INT,
    account_id INT,
    opening_balance DECIMAL(18, 2),
    closing_balance DECIMAL(18, 2)
)
STORED AS PARQUET
LOCATION 's3://luvutu-s3/fact_daily_balance/';
```

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS dw.fact_customer_interaction (
    balance_id INT,
    date_id INT,
    account_id INT,
    channel_id INT,
    interaction_type VARCHAR(50),
    interaction_rating INT
)
STORED AS PARQUET
LOCATION 's3://luvutu-s3/fact_customer_interaction/';
```

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS dw.fact_loan_payment (
    payment_id INT,
    date_id INT,
    loan_id INT,
    customer_id INT,
    payment_amount DECIMAL(18, 2),
    payment_status VARCHAR(50)
)
STORED AS PARQUET
LOCATION 's3://luvutu-s3/fact_loan_payment/';
```

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS dw.fact_investment (
    investment_id INT,
    date_id INT,
    investment_type_id INT,
    account_id INT,
    investment_amount DECIMAL(18, 2),
    return_amount DECIMAL(18, 2)
)
STORED AS PARQUET
LOCATION 's3://luvutu-s3/fact_investment/';
```

## Bước 3: Thực hiện INSERT để điền dữ liệu vào các bảng fact

Thực hiện từng lệnh INSERT riêng biệt:

### Điền dữ liệu vào fact_transaction

```sql
INSERT INTO dw.fact_transaction
SELECT
    CAST(100000 + d.date_id + c.customer_id AS INT) as transaction_id,
    c.customer_id,
    d.date_id,
    ch.channel_id,
    a.account_id,
    tt.transaction_type_id,
    l.location_id,
    cu.currency_id,
    ln.loan_id,
    it.investment_type_id,
    CAST(5000 + (a.account_balance % 5000) AS DECIMAL(18,2)) as transaction_amount,
    CASE
        WHEN (c.customer_id % 5) > 1 THEN 'Completed'
        ELSE 'Pending'
    END as transaction_status
FROM
    "luvutu-database"."customers" c
    CROSS JOIN "luvutu-database"."dates" d
    CROSS JOIN "luvutu-database"."channels" ch
    JOIN "luvutu-database"."accounts" a ON c.customer_id = a.customer_id
    CROSS JOIN "luvutu-database"."transaction_types" tt
    CROSS JOIN "luvutu-database"."locations" l
    CROSS JOIN "luvutu-database"."currencies" cu
    LEFT JOIN "luvutu-database"."loans" ln ON ln.loan_id = CASE WHEN tt.transaction_type_id = 4 THEN MOD(c.customer_id, 50) + 1 ELSE NULL END
    LEFT JOIN "luvutu-database"."investment_types" it ON it.investment_type_id = CASE WHEN tt.transaction_type_id = 3 THEN MOD(c.customer_id, 7) + 1 ELSE NULL END
WHERE
    MOD(d.date_id + c.customer_id, 100) = 1
LIMIT 1000;
```

### Điền dữ liệu vào fact_daily_balance

```sql
INSERT INTO dw.fact_daily_balance
SELECT
    200000 + a.account_id + d.date_id as balance_id,
    d.date_id,
    a.account_id,
    a.account_balance - CAST(MOD(a.account_id * d.date_id, 1000) AS DECIMAL(18,2)) as opening_balance,
    a.account_balance as closing_balance
FROM
    "luvutu-database"."accounts" a
    CROSS JOIN "luvutu-database"."dates" d
WHERE
    MOD(d.date_id + a.account_id, 100) = 2
LIMIT 1000;
```

### Điền dữ liệu vào fact_customer_interaction

```sql
INSERT INTO dw.fact_customer_interaction
SELECT
    300000 + a.account_id + d.date_id + ch.channel_id as balance_id,
    d.date_id,
    a.account_id,
    ch.channel_id,
    CASE
        WHEN MOD(a.account_id * d.date_id, 3) = 0 THEN 'Inquiry'
        WHEN MOD(a.account_id * d.date_id, 3) = 1 THEN 'Complaint'
        ELSE 'Feedback'
    END as interaction_type,
    MOD(a.account_id + d.date_id, 5) + 1 as interaction_rating
FROM
    "luvutu-database"."accounts" a
    CROSS JOIN "luvutu-database"."dates" d
    CROSS JOIN "luvutu-database"."channels" ch
WHERE
    MOD(d.date_id + a.account_id + ch.channel_id, 100) = 3
LIMIT 500;
```

### Điền dữ liệu vào fact_loan_payment

```sql
INSERT INTO dw.fact_loan_payment
SELECT
    400000 + l.loan_id + d.date_id + c.customer_id as payment_id,
    d.date_id,
    l.loan_id,
    c.customer_id,
    CAST(l.loan_amount * (MOD(l.loan_id * d.date_id, 10) / 100.0) AS DECIMAL(18,2)) as payment_amount,
    CASE
        WHEN MOD(l.loan_id + d.date_id, 20) > 1 THEN 'Paid'
        ELSE 'Late'
    END as payment_status
FROM
    "luvutu-database"."loans" l
    CROSS JOIN "luvutu-database"."dates" d
    CROSS JOIN "luvutu-database"."customers" c
WHERE
    MOD(l.loan_id + d.date_id + c.customer_id, 20) = 0
LIMIT 200;
```

### Điền dữ liệu vào fact_investment

```sql
INSERT INTO dw.fact_investment
SELECT
    500000 + it.investment_type_id + d.date_id + a.account_id as investment_id,
    d.date_id,
    it.investment_type_id,
    a.account_id,
    CAST(10000 + (a.account_balance % 40000) AS DECIMAL(18,2)) as investment_amount,
    CAST(12000 + (a.account_balance % 48000) AS DECIMAL(18,2)) as return_amount
FROM
    "luvutu-database"."investment_types" it
    CROSS JOIN "luvutu-database"."dates" d
    CROSS JOIN "luvutu-database"."accounts" a
WHERE
    a.account_type = 'Investment'
    AND MOD(it.investment_type_id + d.date_id + a.account_id, 20) = 0
LIMIT 300;
```

## Bước 4: Tạo các view phân tích

### View phân tích giao dịch theo tháng

```sql
CREATE OR REPLACE VIEW dw.vw_monthly_transaction_summary AS
SELECT
    d.year,
    d.month,
    tt.description as transaction_type,
    COUNT(*) as transaction_count,
    SUM(ft.transaction_amount) as total_amount
FROM
    dw.fact_transaction ft
JOIN
    "luvutu-database"."dates" d ON ft.transaction_date_id = d.date_id
JOIN
    "luvutu-database"."transaction_types" tt ON ft.transaction_type_id = tt.transaction_type_id
GROUP BY
    d.year, d.month, tt.description;
```

### View tổng hợp thông tin tài khoản khách hàng

```sql
CREATE OR REPLACE VIEW dw.vw_customer_account_summary AS
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT a.account_id) as account_count,
    SUM(a.account_balance) as total_balance,
    AVG(a.credit_score) as avg_credit_score
FROM
    "luvutu-database"."customers" c
JOIN
    "luvutu-database"."accounts" a ON c.customer_id = a.customer_id
GROUP BY
    c.customer_id, c.first_name, c.last_name;
```

### View phân tích hiệu quả kênh

```sql
CREATE OR REPLACE VIEW dw.vw_channel_effectiveness AS
SELECT
    ch.channel_name,
    COUNT(*) as interaction_count,
    AVG(fci.interaction_rating) as avg_rating
FROM
    dw.fact_customer_interaction fci
JOIN
    "luvutu-database"."channels" ch ON fci.channel_id = ch.channel_id
GROUP BY
    ch.channel_name;
```

### View phân tích hiệu suất đầu tư

```sql
CREATE OR REPLACE VIEW dw.vw_investment_performance AS
SELECT
    it.investment_type_name,
    COUNT(*) as investment_count,
    SUM(fi.investment_amount) as total_invested,
    SUM(fi.return_amount) as total_return,
    SUM(fi.return_amount - fi.investment_amount) as total_profit,
    (SUM(fi.return_amount) / NULLIF(SUM(fi.investment_amount), 0) - 1) * 100 as roi_percentage
FROM
    dw.fact_investment fi
JOIN
    "luvutu-database"."investment_types" it ON fi.investment_type_id = it.investment_type_id
GROUP BY
    it.investment_type_name;
```

## Lưu ý quan trọng

1. **Thay đổi tên database**: Thay thế `luvutu-database` trong mọi câu lệnh nếu tên database thực tế của bạn khác.

2. **Đường dẫn S3**: Đảm bảo đường dẫn `s3://luvutu-s3/...` tồn tại và bạn có quyền ghi vào đó.

3. **Hàm MOD thay cho RAND()**: Vì Athena không hỗ trợ hàm RAND() như một số hệ quản trị CSDL khác, tôi đã sử dụng hàm MOD để tạo các giá trị giả ngẫu nhiên nhưng có tính xác định.

4. **Theo dõi tiến trình**: Athena thực hiện các truy vấn bất đồng bộ, nên có thể mất vài phút để một truy vấn hoàn tất, đặc biệt đối với các lệnh INSERT với join phức tạp.

5. **Quyền truy cập**: Đảm bảo người dùng Athena của bạn có quyền CREATE DATABASE, CREATE TABLE, và INSERT trên vị trí S3 được chỉ định.
