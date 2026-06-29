# Ales Masaba Animal Feed — Programu ya Kusimamia Biashara (Offline)

Programu ya Android iliyoandikwa kwa Flutter, lugha **Kiswahili pekee**, inayofanya kazi 100% bila intaneti kwa kutumia SQLite.

---

## JINSI YA KUJENGA APP KWA SIMU PEKEE (Bila Kompyuta)

Kwa kuwa hauna kompyuta, njia rahisi zaidi ni kutumia **huduma za wingu (cloud)** zinazojenga APK kwa niaba yako. Chagua moja:

### Njia ya 1 (Rahisi Zaidi): FlutLab.io

1. Fungua kivinjari (Chrome) kwenye simu, ingia **flutlab.io**, fungua akaunti bure.
2. Bonyeza "New Project" → "Import" → pakia folda hii (zip uliyopata) au nakili faili moja moja.
3. FlutLab ina kihariri (editor) kinachofanya kazi vizuri kwenye simu - unaweza kuhariri faili za `.dart` moja kwa moja huko.
4. Bonyeza kitufe cha "Build" → chagua "APK" → subiri dakika chache → pakua APK moja kwa moja kwenye simu yako.
5. Hakuna usanidi wa Android Studio au Flutter SDK unaohitajika kwenye simu.

### Njia ya 2: GitHub + github.dev (VS Code kwenye Kivinjari)

1. Tengeneza akaunti ya **github.com** (bure), tengeneza "New Repository".
2. Pakia faili zote za mradi huu kwenye repository (unaweza kutumia kipengele cha "Add file → Upload files" cha GitHub, kinafanya kazi vizuri kwenye simu).
3. Fungua link: `github.dev/JINA_LAKO/JINA_LA_REPO` (badilisha "github.com" na "github.dev" kwenye URL) - hii inafungua VS Code kamili kwenye kivinjari cha simu yako.
4. Hariri faili unazotaka, kisha "Commit" mabadiliko.
5. Mradi huu una faili tayari: `.github/workflows/build-apk.yml` - inayojenga APK KIOTOMATIKO kila unapo-commit.
6. Baada ya commit, fungua tabo ya "Actions" kwenye repo yako → subiri ujenzi (build) kukamilika (~5-8 dakika) → pakua APK kutoka sehemu ya "Artifacts".

### Njia ya 3 (Mahiri Zaidi): Codemagic

1. Ingia **codemagic.io** kwa akaunti ya GitHub.
2. Unganisha repository yako - Codemagic inatambua Flutter moja kwa moja na kujenga APK.
3. Pakua APK kutoka kwenye dashibodi ya Codemagic kupitia kivinjari cha simu.

> Akaunti chaguomsingi ya kuingia ndani ya programu: **Jina la Mtumiaji:** `admin` **Nenosiri:** `admin123` (badilisha mara ya kwanza, kwa usalama).

---

## Muundo wa Msimbo (Clean Architecture)

```
lib/
  core/            -> rangi, mandhari, maneno ya Kiswahili, PDF generator, biometric helper
  data/
    database/      -> database_helper.dart (jedwali zote 13 za SQLite)
    models/        -> Product, Customer, Sale, CreditSale, Expense, n.k.
    repositories/  -> mantiki ya database (CRUD, transactions, backup, settings)
  presentation/
    providers/     -> hali ya programu (Provider state management)
    screens/       -> UI ya kila moduli
    widgets/       -> chati, daily closing dialog
```

---

## Vipengele Vilivyokamilika (Awamu ya 1 + Awamu ya 2)

**Awamu ya 1:**
- Database kamili (jedwali zote 13), Login na ulinzi wa majaribio 5, Dashibodi, Bidhaa (CRUD), Mauzo (Cash/Mkopo), Mkopo (malipo), Matumizi, Ripoti za msingi

**Awamu ya 2 (Mpya):**
- Risiti za PDF halisi - Chapisha (Print), Shiriki (WhatsApp/Email), Hifadhi PDF - skrini mpya `ReceiptScreen` inaonekana papo hapo baada ya mauzo
- Hifadhi Nakala / Restore halisi - inakopi faili la database, inahifadhi historia, inaweza kushirikiwa (share) kwa Google Drive/WhatsApp kama nakala ya nje
- Alama ya Kidole (Fingerprint) - kuwasha/kuzima kwenye Mipangilio, kuingia bila nenosiri baada ya kuthibitishwa na kifaa
- Badilisha Nenosiri - skrini kamili
- Mipangilio halisi - jina la biashara, anuani, sarafu, kodi - sasa zinahifadhiwa kwenye database, si UI tu
- Chati ya Mauzo ya Wiki kwenye Dashibodi (fl_chart)
- Funga Hesabu za Leo (Daily Closing) - muhtasari kamili: mauzo, fedha taslimu, mkopo, matumizi, faida
- Arifa ya Backup - "Hujahifadhi nakala kwa siku 7" inaonekana kwenye Dashibodi kiotomatiki
- GitHub Actions - mfumo wa kujenga APK kiotomatiki kwenye wingu

---

## Bado Inahitaji Kujengwa (Awamu ya 3)

1. Uhamishaji wa Ripoti kwa Excel na CSV (package ya `excel` tayari ipo kwenye pubspec.yaml)
2. PIN ya nambari (mbadala wa nenosiri, tofauti na fingerprint) - jedwali na mantiki ya msingi tayari ipo (`pin_hash`, `verifyPin`), inahitaji UI ya kuweka/kuthibitisha PIN
3. Arifa za ndani zinazohifadhiwa DB (jedwali la `notifications` lipo, linahitaji UI ya kuonyesha orodha kamili)
4. Aikoni rasmi ya programu na nembo ya biashara (sasa ni icon ya jumla ya Flutter)
5. Multi-user roles (Admin/Manager/Cashier), Bluetooth printer, Barcode/QR scanner - vifurushi vingine (`mobile_scanner`) tayari vimewekwa kwenye pubspec lakini havijaunganishwa na UI

Nikitumia muda zaidi, naweza kuendelea na hizi - nikuanzie wapi?

## Maelezo ya Usalama

- Manenosiri yamehifadhiwa kwa SHA-256 hash.
- `AndroidManifest.xml` HAINA ruhusa ya `INTERNET` - programu ni offline kweli.
- Mauzo yanatumia SQLite transactions kuzuia data isiyo sahihi.
- Alama ya kidole inathibitishwa na mfumo wa simu yenyewe (local_auth), si programu hii.
