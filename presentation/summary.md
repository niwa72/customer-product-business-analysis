# Customer & Product Business Analysis — One-Page Summary

**Business question:** Which customer behaviors, product categories, and seller characteristics
should receive priority to increase customer value?

**Data:** Shopee Thailand transaction data (synthetic), 2022–2025. 300,000 orders, 55,822
customers with at least one completed purchase, 200 sellers.

**Workflow:** SQL for core business analysis · Python for validation and visualization · AI
(Claude) as an analytical copilot for drafting and iteration, with data validation, method
selection, and interpretation kept human-controlled throughout. See the main
[README](../README.md) for the full AI-assisted workflow breakdown and three worked examples.

---

## Key Findings

**1. Purchase frequency showed the strongest and most consistent association with customer value.**
Customers with 6+ completed orders were ~32% of the customer base but generated ~55.7% of realized
revenue. Average revenue per customer rose consistently across every frequency band (฿12,366 →
฿124,741), not concentrated in a single high-value group.

**2. High-value customers did not show a distinctive category or product preference.**
Category- and product-level tests (down to individual products with ≥100 buyers) both returned
over-index ratios close to 1.0 — no meaningful concentration.

**3. A seemingly large FBS vs Standard seller performance gap was a catalog-size artifact.**
FBS sellers carry exactly 16 products each, Standard sellers exactly 28 — a deterministic
difference in this dataset. Revenue per product was nearly identical (~฿634K vs ~฿624K) once
normalized; the raw gap (~฿10.1M vs ~฿17.5M per seller) was measuring catalog size, not logistics
performance.

---

## Recommendations

| # | Recommendation | Evidence strength |
|---|---|---|
| 1 | Prioritize purchase-frequency growth among regular/occasional customers over category-specific targeting | Strong |
| 2 | Targeted re-engagement (not a broad campaign) for 547 high-frequency customers inactive 180+ days (~฿48.2M historical value) | Strong (small, well-defined group) |
| 3 | Investigate why Company sellers show ~18–20% higher revenue efficiency than Individual sellers | Moderate — worth investigating, not yet actionable |
| 4 | Do not base logistics decisions on raw FBS vs Standard revenue | Strong (defensive finding) |

---

## Limitations

Observational analysis — findings describe associations, not causal effects. Customer segments
are analytical business rules built for this project, not an existing CRM system. Dataset is
synthetic and represents one platform, not the Thai e-commerce market as a whole.

**Full analysis:** [README](../README.md) · [SQL](../sql/) · [Notebook](../analysis/customer_product_analysis.ipynb) · [Dashboard](../dashboard/index.html)
