import 'package:flutter/material.dart';
import '../../data/repositories/settings_repository.dart';

/// SettingsProvider - Hali ya mipangilio ya biashara kwa UI nzima
class SettingsProvider extends ChangeNotifier {
  final _repo = SettingsRepository();
  Map<String, dynamic> _settings = {};
  bool isLoading = true;

  Map<String, dynamic> get settings => _settings;
  String get businessName => _settings['business_name'] as String? ?? 'Ales Masaba Animal Feed';
  String get currency => _settings['currency'] as String? ?? 'TZS';
  String get themeMode => _settings['theme_mode'] as String? ?? 'light';

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    _settings = await _repo.getSettings();
    isLoading = false;
    notifyListeners();
  }

  Future<void> update(Map<String, dynamic> values) async {
    await _repo.updateSettings(values);
    await load();
  }
}
