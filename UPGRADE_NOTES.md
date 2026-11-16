# Ales Masaba Animal Feed — Upgrade Notes

## 1. Audit findings (what the code was doing)

**Stack:** Flutter (Provider), Firebase Auth + Cloud Firestore for all business data
(products, customers, sales, credit_sales, expenses, users). SQLite (`sqflite`) is only
used for the *settings* row, backup logs and a legacy local `users` cache.
Roles: `super_admin` and `cashier`, enforced in the UI **and** in `firestore.rules`.

**What already existed:** cart with several items, one `sales` doc holding an `items`
array, Cash/Credit, credit repayments in `credit_sales/{id}/payments`, PDF receipt
(print/share/save), reports with PDF/Excel/CSV export, Swahili strings in `strings_sw.dart`.

**Bugs / gaps found**

| # | Finding | Severity |
|---|---------|----------|
| 1 | Cashier dashboard called owner-only/unfiltered queries; Firestore rules reject them, the exception was uncaught, so `isLoading` stayed `true` (infinite spinner). | High |
| 2 | `MySalesReportScreen`, receipt-number counter and credit list ran unfiltered queries as a cashier. Rules do not filter results, they reject the whole query. | High |
| 3 | No idempotency: a retried checkout created a *new* sale doc → stock deducted twice. | High |
| 4 | Receipt number came from a non-atomic `count()+1` → duplicates possible with two devices. | Medium |
| 5 | `recordPayment` did not stop overpayment; any active user could write any `amount_paid` (rules). Double-tap = double payment. | High |
| 6 | Sales were all-or-nothing: Cash (full) or Credit (nothing paid). No partial payment, no mobile money, no reference, no cashier on the payment. | Feature gap |
| 7 | No stock-movement history; editing quantity in the product form silently overwrote stock. | Feature gap |
| 8 | Any cashier could type any price (even 1 TZS) and cashiers could write `quantity` upward via rules. | Medium |
| 9 | Receipt showed full total as "debt" and had no cashier / amount paid / change. | Medium |
| 10 | `credit_screen.dart` was a byte-for-byte duplicate of `credit_list_screen.dart`. | Low |
| 11 | Seed account `admin / admin123` is created in local SQLite. | Security – change on first login |
| 12 | Business settings (name, phone, logo) live in each phone's local SQLite → receipts differ per device. | Medium (not fixed) |
| 13 | "Profit" = sales − expenses (no cost of goods). Label is misleading. | Low (not fixed) |

## 2. What was changed

* **Models:** `SaleModel` gains `amountPaid`, `balance`, `paymentStatus`, `paymentReference`,
  `changeGiven`, `cashierName`, `branchName`, `clientRequestId`. Old documents load correctly
  (no `amount_paid` → Cash = fully paid, Mkopo = 0). New `StockMovementModel`.
* **`SalesRepository.createSale`:** ONE Firestore transaction writes the sale (with all items),
  stock deductions, stock movements, receipt counter, credit record + initial payment, customer
  and activity log. Sale doc id = `clientRequestId` → a retry returns the existing sale and does
  **not** deduct stock again. Stock never goes below 0. Overstock sale is allowed only for
  `super_admin` and the shortfall is written to the movement.
* **`CreditRepository.recordPayment`:** overpayment rejected inside the transaction, request-id
  de-duplication, method (Cash / Pesa ya Simu) + reference + cashier, updates the sale's balance too.
* **POS (`new_sale_screen.dart`):** product search, multi-item cart, edit/remove lines, live totals,
  cashier price floor (= wholesale price; owner unrestricted), stock check, payment sheet with
  Cash / Mobile money / Credit, amount paid, change or balance shown live, double-tap guard.
* **Receipt:** PDF preview inside the app + print / share / save; includes receipt no., date/time,
  cashier, customer, items, totals, paid, balance or change, payment method/reference.
* **Inventory:** `adjustStock` (purchase, adjustment, damage) with history screen
  (`Historia ya Hifadhi`, owner only); product add/edit also writes movements.
* **Swahili assistant** (`Msaidizi`): rule-based, reads real Firestore data, no paid API.
  Cashiers only get *their own* sales/debts; yearly and business-wide figures are owner-only.
* **Dashboards:** role-aware loading (fixes #1), yearly sales, cashier performance, branch sales.
* **Exports:** Excel/CSV now include seller, amount paid, balance.
* **`firestore.rules` + `firestore.indexes.json`:** see deploy steps.

## 3. Deploy steps (required)

1. Firebase Console → Firestore → **Rules** → paste `firestore.rules` → Publish.
   (Required: new `stock_movements` and `counters` collections, tighter credit/sales updates,
   and the `resource == null` read rule that lets cashiers' transactions check for duplicates.)
2. Create the index `sales: user_id ASC + sale_date DESC` (or deploy `firestore.indexes.json`,
   or just tap the link Firestore prints in the log the first time a cashier opens a report).
3. `flutter pub get && flutter analyze && flutter test` then build the APK.

## 4. Not done / decisions for you

* **Not compiled here.** The sandbox cannot download the Flutter SDK, so nothing was built or
  run. Code was reviewed by hand; expect to fix a few analyzer messages on first `flutter analyze`.
* Firestore transactions need a connection: **a sale cannot be saved fully offline** (that is what
  guarantees no double deduction). The existing connectivity banner stays.
* "Prevent sales over stock unless authorized" vs "prevent negative stock": implemented as
  owner-only override that floors stock at 0 and logs the shortfall.
* Not implemented: unit conversion (e.g. bag → kg), multiple branches with per-branch stock
  (branch name is recorded on each sale and reported, stock is still one pool), moving settings to
  Firestore (#12), removing the `admin123` seed (#11), cost-based profit (#13), repayment receipts,
  thermal 58/80 mm layout, Material 3 re-theme of the untouched screens, string extraction of the
  new Swahili texts into `strings_sw.dart`.
* Tapping the same "Lipa" twice offline-then-online is safe; but two *different* devices selling the
  last bag at the same moment is resolved by the transaction (second one gets "Hifadhi haitoshi").

## 5. Manual test checklist

1. Cashier: log in → dashboard loads (no spinner) → new sale with 3 products (Juma example:
   60,000 total, pay 50,000 Cash) → receipt shows balance 10,000 → appears in Orodha ya Mkopo.
2. Pay 10,000 via Simu with a reference → debt disappears; try 1 TZS extra → rejected.
3. Turn airplane mode on mid-checkout, retry: only one receipt, stock deducted once.
4. Cashier tries a price below wholesale → blocked. Owner can.
5. Owner: Historia ya Hifadhi shows the sale movements; add stock; try to reduce below 0 → rejected.
6. Assistant as cashier: "Madeni yote ni kiasi gani?" → only own debts; "Mauzo ya mwaka" → owner-only message.
