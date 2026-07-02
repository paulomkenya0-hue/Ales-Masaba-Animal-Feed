import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

/// BackupRepository - Husimamia Hifadhi Nakala na Kurejesha kwa kuhamisha faili
/// halisi la SQLite (.db). Hii ndiyo njia salama zaidi 100% offline.
class BackupRepository {
  final dbHelper = DatabaseHelper.instance;

  /// Hutengeneza nakala ya hifadhidata kwenye folda ya "Backups" ndani ya hifadhi ya programu.
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

  /// Tarehe ya nakala ya mwisho - hutumika kuonyesha "Hujahifadhi kwa siku 7"
  Future<DateTime?> getLastBackupDate() async {
    final db = await dbHelper.database;
    final rows = await db.query('backup_logs', orderBy: 'created_at DESC', limit: 1);
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['created_at'] as String);
  }

  Future<bool> isBackupOverdue() async {
    final lastBackup = await getLastBackupDate();
    if (lastBackup == null) return true;
    return DateTime.now().difference(lastBackup).inDays >= 7;
  }
}
