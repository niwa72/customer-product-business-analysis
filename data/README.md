# Data

The raw CSV files used in this analysis are **not committed to this repository** (dataset size /
avoiding redistribution of third-party synthetic data files). This folder documents what the data
is and how to reproduce the analysis.

## Source

Synthetic Shopee Thailand e-commerce transaction data, covering January 2022 – December 2025.
The dataset represents activity on **one platform (Shopee Thailand)** — it is not a representative
sample of the Thai e-commerce market as a whole, and no country-level claims are made from it
anywhere in this project.

## Tables

| Table | Rows | Grain |
|---|---:|---|
| `customers` | 60,000 | 1 row / customer |
| `orders` | 300,000 | 1 row / order |
| `order_items` | 480,481 | 1 row / line item |
| `products` | 4,880 | 1 row / product |
| `sellers` | 200 | 1 row / seller |
| `campaigns` | 20 | 1 row / campaign |
| `product_campaign` | 21,894 | product × campaign |
| `shipments` | 360,187 | 1 row / completed item |
| `reviews` | 360,187 | 1 row / completed item |
| `website_sessions` | 500,000 | 1 row / session |
| `session_activities` | 2,696,482 | 1 row / page view |

This project's analysis (`/sql`, `/analysis`) only uses `customers`, `orders`, `order_items`,
`products`, and `sellers`. The remaining tables (campaigns, shipments, reviews, sessions) were
inspected during initial data validation but are out of scope for this specific analysis.

## Reproducing locally

1. Place the five CSV files above in this `data/` folder (or point your own database import at
   them).
2. Import into MySQL (or another relational database) using each table's column headers as the
   schema — see the comments at the top of `../sql/01_data_validation.sql` for the expected columns.
3. Run the SQL files in order: `01_data_validation.sql` → `02_customer_analysis.sql` →
   `03_category_analysis.sql` → `04_seller_analysis.sql`. Files 02–04 depend on tables created by
   earlier files in the sequence.
4. `../analysis/customer_product_analysis.ipynb` reads the same five CSVs directly with pandas and
   independently reproduces the key numbers from the SQL files — no database connection required
   to run the notebook.
