import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../database/database_helper.dart';
import '../../core/services/firebase_service.dart';

/// Collections za Firestore zenye DATA YA BIASHARA (si 'users' - hizo
/// zinasimamiwa na Firebase Auth moja kwa moja na si sehemu ya nakala hii
/// kwa sababu za usalama - password hazihifadhiwi humu kamwe).
const _kBackupCollections = [
  'categories',
  'products',
  'customers',
  'sales',
  'credit_sales',
  'expenses',
];

/// BackupRepository - Husimamia Hifadhi Nakala na Kurejesha.
/// AINA MBILI za nakala:
///  1) Nakala ya DATA YA BIASHARA (Firestore -> faili la JSON) - hii ndiyo
///     muhimu zaidi sasa kwa kuwa bidhaa/mauzo/wateja vyote vipo Firestore.
///  2) Nakala ya kifaa hiki tu (SQLite -> faili la .db) - ina cache ya
///     mtumiaji/mipangilio ya kifaa hiki pekee, si data ya biashara.
class BackupRepository {
  final dbHelper = DatabaseHelper.instance;

  // ---------------------------------------------------------------------
  // FIRESTORE (Data ya Biashara) - JSON
  // ---------------------------------------------------------------------

  /// Hutengeneza nakala ya JSON ya data YOTE ya biashara kutoka Firestore
  /// (bidhaa, categories, wateja, mauzo, madeni+malipo, matumizi).
  /// Inarudisha njia (path) ya faili lililotengenezwa.
  Future<String> createFirestoreBackup() async {
    final Map<String, dynamic> data = {};

    for (final collection in _kBackupCollections) {
      final snap = await FirebaseService.firestore.collection(collection).get();
      data[collection] = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // credit_sales ina subcollection ya 'payments' - ihifadhi pia
      if (collection == 'credit_sales') {
        final payments = <Map<String, dynamic>>[];
        for (final doc in snap.docs) {
          final paySnap = await doc.reference.collection('payments').get();
          for (final p in paySnap.docs) {
            payments.add({'id': p.id, 'credit_sale_id': doc.id, ...p.data()});
          }
        }
        data['payments'] = payments;
      }
    }

    data['_backup_created_at'] = DateTime.now().toIso8601String();
    data['_backup_version'] = 1;

    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(join(docsDir.path, 'Backups'));
    if (!await backupDir.exists()) await backupDir.create(recursive: true);

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final backupPath = join(backupDir.path, 'amaf_data_backup_$timestamp.json');
    final file = File(backupPath);
    await file.writeAsString(jsonEncode(data));

    final db = await dbHelper.database;
    await db.insert('backup_logs', {
      'file_path': backupPath,
      'backup_type': 'Firestore',
      'created_at': DateTime.now().toIso8601String(),
    });

    return backupPath;
  }

  /// Hurejesha data kutoka faili la JSON kwenda Firestore. Hutumia 'merge'
  /// (SET na merge:true) kwa kila hati - HAIFUTI data iliyopo ambayo haipo
  /// kwenye faili la nakala, inaandika/inasasisha tu. Salama zaidi kuliko
  /// kufuta kila kitu kwanza.
  Future<void> restoreFirestoreBackup(String backupFilePath) async {
    final file = File(backupFilePath);
    if (!await file.exists()) throw Exception('Faili la nakala halipo');

    final Map<String, dynamic> data = jsonDecode(await file.readAsString());

    for (final collection in _kBackupCollections) {
      final items = data[collection] as List<dynamic>? ?? [];
      for (final item in items) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map.remove('id') as String;
        await FirebaseService.firestore.collection(collection).doc(id).set(map, SetOptions(merge: true));
      }
    }

    final payments = data['payments'] as List<dynamic>? ?? [];
    for (final item in payments) {
      final map = Map<String, dynamic>.from(item as Map);
      final id = map.remove('id') as String;
      final creditSaleId = map.remove('credit_sale_id') as String;
      await FirebaseService.firestore
          .collection('credit_sales')
          .doc(creditSaleId)
          .collection('payments')
          .doc(id)
          .set(map, SetOptions(merge: true));
    }
  }

  // ---------------------------------------------------------------------
  // SQLITE (Cache ya kifaa hiki) - .db
  // ---------------------------------------------------------------------

  /// Hutengeneza nakala ya hifadhidata kwenye folda ya \"Backups\" ndani ya hifadhi ya programu.
  /// Inarudisha njia (path) ya faili lililotengenezwa.
  Future<String> createBackup({String type = 'Manual'}) async {
    final db = await dbHelper.database;
    await db.execute('PRAGMA wal_checkpoint(FULL)'); // hakikisha data zote zimeandikwa kwenye faili kuu

    final dbPath = await getDatabasesPath();
    final sourceFile = File(join(dbPath, DatabaseHelper.dbName));

    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(join(docsDir.path, 'Backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final backupPath = join(backupDir.path, 'amaf_backup_$timestamp.db');
    await sourceFile.copy(backupPath);

    await db.insert('backup_logs', {
      'file_path': backupPath,
      'backup_type': type,
      'created_at': DateTime.now().toIso8601String(),
    });

    return backupPath;
  }

  /// Hurejesha hifadhidata kutoka faili la nakala. ANGALIZO: hii inabadilisha data zote za sasa.
  /// Programu inahitaji kuanzishwa upya (restart) baada ya operesheni hii.
  Future<void> restoreBackup(String backupFilePath) async {
    await dbHelper.close();

    final dbPath = await getDatabasesPath();
    final destinationPath = join(dbPath, DatabaseHelper.dbName);
    final backupFile = File(backupFilePath);

    if (!await backupFile.exists()) {
      throw Exception('Faili la nakala halipo');
    }

    await backupFile.copy(destinationPath);
  }

  Future<List<Map<String, dynamic>>> getBackupHistory() async {
    final db = await dbHelper.database;
    return await db.query('backup_logs', orderBy: 'created_at DESC');
  }

  /// Tarehe ya nakala ya mwisho YA DATA YA BIASHARA (Firestore) - hutumika
  /// kuonyesha "Hujahifadhi data ya biashara kwa siku 7"
  Future<DateTime?> getLastBackupDate() async {
    final db = await dbHelper.database;
    final rows = await db.query('backup_logs',
        where: 'backup_type = ?', whereArgs: ['Firestore'], orderBy: 'created_at DESC', limit: 1);
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['created_at'] as String);
  }

  Future<bool> isBackupOverdue() async {
    final lastBackup = await getLastBackupDate();
    if (lastBackup == null) return true;
    return DateTime.now().difference(lastBackup).inDays >= 7;
  }
}
