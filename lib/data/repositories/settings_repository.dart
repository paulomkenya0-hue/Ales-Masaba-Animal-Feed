import '../database/database_helper.dart';

/// SettingsRepository - Husoma na kuhifadhi mipangilio ya biashara (jedwali la settings)
class SettingsRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<Map<String, dynamic>> getSettings() async {
    final db = await dbHelper.database;
    final rows = await db.query('settings', limit: 1);
    if (rows.isEmpty) {
      final id = await db.insert('settings', {'business_name': 'Ales Masaba Animal Feed', 'currency': 'TZS'});
      return {'id': id, 'business_name': 'Ales Masaba Animal Feed', 'currency': 'TZS'};
    }
    return rows.first;
  }

  Future<void> updateSettings(Map<String, dynamic> values) async {
    final db = await dbHelper.database;
    final current = await getSettings();
    await db.update('settings', values, where: 'id = ?', whereArgs: [current['id']]);
  }
}
