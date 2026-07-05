-- =========================================================
-- BIKE SHOP RELATIONAL DATABASE - SCHEMA
-- =========================================================
PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS stocks;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS staffs;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS stores;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS brands;

CREATE TABLE brands (
    brand_id    INTEGER PRIMARY KEY,
    brand_name  TEXT NOT NULL
);

CREATE TABLE categories (
    category_id    INTEGER PRIMARY KEY,
    category_name  TEXT NOT NULL
);

CREATE TABLE stores (
    store_id    INTEGER PRIMARY KEY,
    store_name  TEXT NOT NULL,
    phone       TEXT,
    email       TEXT,
    street      TEXT,
    city        TEXT,
    state       TEXT,
    zip_code    TEXT
);

CREATE TABLE customers (
    customer_id  INTEGER PRIMARY KEY,
    first_name   TEXT NOT NULL,
    last_name    TEXT NOT NULL,
    phone        TEXT,
    email        TEXT,
    street       TEXT,
    city         TEXT,
    state        TEXT,
    zip_code     TEXT
);

CREATE TABLE staffs (
    staff_id    INTEGER PRIMARY KEY,
    first_name  TEXT NOT NULL,
    last_name   TEXT NOT NULL,
    email       TEXT,
    phone       TEXT,
    active      INTEGER,
    store_id    INTEGER,
    manager_id  INTEGER,
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (manager_id) REFERENCES staffs(staff_id)
);

CREATE TABLE products (
    product_id    INTEGER PRIMARY KEY,
    product_name  TEXT NOT NULL,
    brand_id      INTEGER,
    category_id   INTEGER,
    model_year    INTEGER,
    list_price    REAL,
    FOREIGN KEY (brand_id) REFERENCES brands(brand_id),
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

CREATE TABLE stocks (
    store_id    INTEGER,
    product_id  INTEGER,
    quantity    INTEGER,
    PRIMARY KEY (store_id, product_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE orders (
    order_id      INTEGER PRIMARY KEY,
    customer_id   INTEGER,
    order_status  INTEGER,
    order_date    TEXT,
    required_date TEXT,
    shipped_date  TEXT,
    store_id      INTEGER,
    staff_id      INTEGER,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (staff_id) REFERENCES staffs(staff_id)
);

CREATE TABLE order_items (
    order_id    INTEGER,
    item_id     INTEGER,
    product_id  INTEGER,
    quantity    INTEGER,
    list_price  REAL,
    discount    REAL,
    PRIMARY KEY (order_id, item_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
