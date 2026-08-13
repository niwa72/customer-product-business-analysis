# Data

The raw CSV files used in this analysis are **not committed to this repository** (dataset size /
avoiding redistribution of third-party synthetic data files). This folder documents what the data
is and how to reproduce the analysis.

## Source

**[Shopee TH: Customer Journey & Operations Dataset](https://www.kaggle.com/datasets/hninshwezinhlaing/shopee-th-customer-journey-and-operations-dataset)**,
published on Kaggle by Hnin Shwe Zin Hlaing.

This is synthetic e-commerce transaction data modeled on the Shopee Thailand context — not actual
Shopee transaction records — covering January 2022 – December 2025. It was built as a sample
dataset for practicing analysis methods and business reasoning, not to reproduce the platform's
real scale: 300,000 orders and 200 sellers over four years is far smaller than Shopee Thailand's
actual order and seller volume. Nothing in this project should be read as a claim about Shopee's
real business or about the Thai e-commerce market as a whole.

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
`products`, and `sellers`. The remaining tables were inspected during initial data validation but
are out of scope for this specific analysis:

- **`campaigns` / `product_campaign`** — per the dataset publisher's documentation, this table is
  a marketing event timeline (major sales like Songkran, 11.11, 12.12) intended for A/B testing
  campaign performance against organic baseline periods. This project's `order_items.is_campaign`
  flag was inspected during initial validation (and found to be inconsistently linked to
  `product_campaign_id` in ~76% of flagged rows — a data-quality limitation, not something this
  project attempted to fix), but a proper campaign-lift analysis using this table was intentionally
  left out of Project 2's customer/product/seller scope. It's a natural fit for a future project
  focused on growth interventions.
- **`shipments`, `reviews`, `website_sessions`, `session_activities`** — inspected for schema and
  referential integrity only; not used in this analysis.

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
