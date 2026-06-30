# Mwongozo wa Mpangilio wa Faili (Muundo wa Msimbo)

Hii ni maelezo ya jinsi faili za mradi huu zimepangwa, kwa nini zimepangwa hivyo,
na unapaswa kuweka wapi faili mpya unapoongeza kipengele kipya.

## Kanuni Kuu: "Clean Architecture" (Tabaka 3)

Mradi umegawanywa kwenye **tabaka tatu (3 layers)** zinazofanya kazi tofauti.
Kila tabaka halijui undani wa tabaka jingine - linawasiliana kupitia "interface" rahisi.
Hii inafanya iwe rahisi kubadilisha kitu kimoja (mfano UI) bila kuvuruga kingine (mfano database).

```
lib/
│
├── core/                     <- VITU VYA JUMLA (havibadiliki kila siku)
│   ├── constants/
│   │   └── strings_sw.dart   <- MANENO YOTE ya Kiswahili ya programu yapo HAPA TU
│   ├── theme/
│   │   └── app_theme.dart    <- Rangi (Kijani/Nyeupe/Kijivu) na mtindo wa Material 3
│   └── utils/
│       ├── receipt_generator.dart   <- Hutengeneza PDF ya risiti
│       ├── export_helper.dart       <- Hutengeneza Excel/CSV
│       └── biometric_helper.dart    <- Huwasiliana na alama ya kidole ya simu
│
├── data/                      <- TABAKA LA DATA (HAINA UI, HAINA WIDGETS)
│   ├── database/
│   │   └── database_helper.dart     <- Jedwali zote 13 za SQLite zimo HAPA TU
│   ├── models/                      <- "Sura" ya kila kitu (Product, Sale, Customer...)
│   │   └── product_model.dart       <- Kila faili = kitu kimoja cha database
│   └── repositories/                <- "Wafanyakazi" wanaosoma/kuandika database
│       └── product_repository.dart  <- Kila Model ina Repository yake
│
└── presentation/              <- TABAKA LA UI (KILA KITU MTUMIAJI ANACHOKIONA)
    ├── providers/             <- "Kumbukumbu hai" ya programu (Provider state mgmt)
    │   └── product_provider.dart    <- Huunganisha Repository na Screen
    ├── screens/               <- KILA SKRINI = FOLDA YAKE (imepangwa kwa moduli)
    │   ├── splash/
    │   ├── auth/              <- Login, PIN, Fingerprint
    │   ├── dashboard/
    │   ├── products/
    │   ├── sales/
    │   ├── credit/
    │   ├── expenses/
    │   ├── reports/
    │   ├── settings/
    │   ├── backup/
    │   ├── notifications/
    │   └── about/
    └── widgets/               <- Vipande vidogo vinavyotumika sehemu nyingi
        ├── weekly_sales_chart.dart
        ├── daily_closing_dialog.dart
        └── barcode_scanner_screen.dart
```

---

## Mfumo wa Mtiririko (Jinsi Tabaka Tatu Zinavyowasiliana)

```
SCREEN  --(inaita)-->  PROVIDER  --(inaita)-->  REPOSITORY  --(inaita)-->  DATABASE
(UI)                   (Hali)                   (Mantiki ya Data)         (SQLite)
```

Mfano halisi - unapobonyeza "Hifadhi" kwenye fomu ya Bidhaa:

1. **`add_edit_product_screen.dart`** (Screen) - inakusanya data kutoka kwenye fomu
2. Inaita `context.read<ProductProvider>().addProduct(product)` (Provider)
3. **`product_provider.dart`** (Provider) - inaita `_repo.addProduct(product)` (Repository)
4. **`product_repository.dart`** (Repository) - inaandika kwenye jedwali la `products`
5. **`database_helper.dart`** (Database) - hii ndiyo inayowasiliana na SQLite halisi

**Sheria muhimu:** Screen HAIPASWI kuwasiliana moja kwa moja na Database au Repository.
Lazima ipitie Provider. Hii inafanya iwe rahisi kupima (test) na kubadilisha.

---

## Unapoongeza KIPENGELE KIPYA - Fuata Hatua Hizi 5

Tuseme unataka kuongeza kipengele kipya, mfano "Wauzaji (Suppliers)":

### Hatua 1: Jedwali la Database
Fungua `lib/data/database/database_helper.dart`, ongeza `CREATE TABLE suppliers (...)` ndani ya method ya `_onCreate`.

### Hatua 2: Model
Tengeneza faili mpya `lib/data/models/supplier_model.dart` - darasa lenye `fromMap()` na `toMap()`.

### Hatua 3: Repository
Tengeneza `lib/data/repositories/supplier_repository.dart` - methods za `getAll()`, `add()`, `update()`, `delete()`.

### Hatua 4: Provider
Tengeneza `lib/presentation/providers/supplier_provider.dart` - `ChangeNotifier` inayotumia Repository,
kisha isajili kwenye `lib/main.dart` ndani ya `MultiProvider`.

### Hatua 5: Screen
Tengeneza folda `lib/presentation/screens/suppliers/` na uweke `supplier_list_screen.dart`
na `add_edit_supplier_screen.dart` ndani yake. Tumia maneno kutoka `SW.` (strings_sw.dart) kwa kila kitu
kinachoonekana - usiandike Kiingereza popote kwenye Screen.

---

## Sheria za Lugha (Kiswahili Pekee)

- Maandishi yote yanayoonekana kwa mtumiaji LAZIMA yatoke kwenye `lib/core/constants/strings_sw.dart`
- Usiandike `Text('Save')` - andika `Text(SW.save)`
- Ukiongeza neno jipya, liongeze kwenye `strings_sw.dart` KWANZA, kisha ulitumie kwenye Screen
- Majina ya variable/method/class ndani ya code (`productName`, `ProductModel`) yanaweza kuwa Kiingereza -
  hayo si "UI Strings", ni msimbo wa ndani tu ambao mtumiaji hauoni

---

## Majina ya Faili (Naming Convention)

| Aina ya Faili | Mfano | Sheria |
|---|---|---|
| Model | `product_model.dart` | `snake_case` + `_model.dart` |
| Repository | `product_repository.dart` | `snake_case` + `_repository.dart` |
| Provider | `product_provider.dart` | `snake_case` + `_provider.dart` |
| Screen | `product_list_screen.dart` | `snake_case` + `_screen.dart` |
| Widget ndogo | `weekly_sales_chart.dart` | `snake_case`, jina linaloeleza kazi yake |
| Darasa (Class) | `ProductModel`, `ProductRepository` | `PascalCase` daima |

---

## Mahali pa Kuhifadhi Faili Maalum

- **Aikoni ya programu:** `assets/icon/icon.png` (kimbiza `dart run flutter_launcher_icons` baada ya kubadilisha)
- **Mipangilio ya Android:** `android/app/src/main/AndroidManifest.xml`
- **Ruhusa (Permissions):** ndani ya `AndroidManifest.xml` (kamera, hifadhi, n.k.)
- **Workflow ya kujenga APK kwenye wingu:** `.github/workflows/build-apk.yml`
- **Vifurushi (Packages):** `pubspec.yaml`

---

## Maswali ya Haraka

**"Nataka kubadilisha rangi ya programu, niende wapi?"**
→ `lib/core/theme/app_theme.dart` - badilisha `AppColors.primaryGreen` na rangi nyingine.

**"Nataka kuongeza neno jipya la Kiswahili?"**
→ `lib/core/constants/strings_sw.dart` - ongeza `static const jinaLako = "Neno Lako";`

**"Nataka kuongeza jedwali jipya la database?"**
→ `lib/data/database/database_helper.dart` - ndani ya `_onCreate()`.

**"Skrini yangu haionekani, kuna error 'undefined class'?"**
→ Hakikisha umeongeza `import` sahihi juu ya faili, na jina la faili linafanana na jina la darasa (class).
