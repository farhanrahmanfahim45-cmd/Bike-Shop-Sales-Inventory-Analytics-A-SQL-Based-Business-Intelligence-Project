Bike Shop Sales & Inventory Analytics: A SQL-Based Business Intelligence Project
A complete relational database design and SQL analysis project built on a multi-store bike retail dataset. This project covers schema design, data loading, and 60+ analytical SQL queries spanning sales performance, inventory management, staff/store performance, customer behavior, and operational efficiency.
Project Overview
This project simulates a real-world business intelligence task: given raw transactional data from a 3-store bike retail chain, design a proper relational database and extract actionable insights for sales, inventory, staffing, and customer strategy decisions.
Dataset: 9 CSV files covering brands, categories, customers, order items, orders, products, staff, stock, and stores (~1,600 orders, ~4,700 order line items, ~1,445 customers, spanning 2016–2018).
Tools used: MySQL 8.0, MySQL Workbench, SQL (CTEs, window functions, subqueries, multi-table joins)
Schema
The database consists of 9 tables with enforced primary/foreign key relationships:
```
brands ──┐
         ├──> products ──┬──> order\_items ──> orders ──┬──> customers
categories┘              │                              ├──> stores
                          └──> stocks ──> stores          └──> staffs (self-referencing via manager\_id)
```
See `01\_schema.sql` for full DDL.
Files in this repo
File	Description
`01\_schema.sql`	Full relational schema with primary/foreign keys
`02\_product\_inventory\_analysis.sql`	Best-sellers vs. slow-movers, price distribution, model-year trends
`03\_operational\_efficiency.sql`	Order status breakdown, fulfillment time analysis
`04\_staff\_store\_performance.sql`	Staff sales performance, manager rollups, store comparisons
`05\_customer\_behavior.sql`	Repeat vs. one-time customers, geographic patterns, customer lifetime value
`06\_sales\_performance\_revenue\_patterns.sql`	Revenue trends over time, revenue by dimension, discount impact analysis
Key Findings
Revenue concentration: One store generates ~69% of total company revenue — a potential concentration risk worth addressing.
Customer loyalty: Only ~9% of customers are repeat buyers, but they generate a meaningfully higher average revenue per customer than one-time buyers.
Discounting has limited effect on volume: Average quantity sold per line item stays flat (~1.5 units) regardless of discount size — discounting isn't driving meaningfully larger basket sizes in this dataset.
Fulfillment delays: ~30% of completed orders shipped after their promised delivery date, varying notably by store and staff member.
Inventory mismatches: Several products show high stock-to-sales ratios, indicating capital tied up in slow-moving inventory.
How to run this project
Create a MySQL database: `CREATE DATABASE bikeshop; USE bikeshop;`
Run `01\_schema.sql` to create all tables
Import the 9 CSV files into their corresponding tables (via MySQL Workbench's Table Data Import Wizard, or `LOAD DATA INFILE`), in this dependency order:
`brands → categories → stores → customers → staffs → products → stocks → orders → order\_items`
Run any of the analysis `.sql` files to reproduce the findings
Skills Demonstrated
Relational database design & normalization
Writing complex SQL: CTEs, window functions (`RANK()`, `NTILE()`, `LAG()`), correlated subqueries, multi-table joins
Data quality troubleshooting (foreign key constraints, orphaned records, NULL handling)
Business-oriented data analysis and insight generation
Author
Add your name, LinkedIn, and GitHub profile link here
