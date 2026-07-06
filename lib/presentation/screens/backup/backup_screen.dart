import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../data/repositories/backup_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/access_denied_view.dart';

/// BackupScreen - Hifadhi Nakala Mwenyewe, Historia ya Nakala, na Kurejesha.
/// AINA MBILI: (1) Data ya Biashara (Firestore -> JSON) - MUHIMU ZAIDI,
/// (2) Cache ya Kifaa Hiki (SQLite -> .db) - mipangilio/watumiaji wa ndani.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _repo = BackupRepository();
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _history = await _repo.getBackupHistory();
    setState(() => _loading = false);
  }

  Future<void> _createFirestoreBackup() async {
    setState(() => _isWorking = true);
    try {
      final path = await _repo.createFirestoreBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(SW.savedSuccess)));
      }
      await _load();
      if (mounted) await _shareBackup(path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${SW.error}: $e')));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _createDeviceBackup() async {
    setState(() => _isWorking = true);
    try {
      await _repo.createBackup(type: 'Kifaa (SQLite)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(SW.savedSuccess)));
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${SW.error}: $e')));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _shareBackup(String path) async {
    await Share.shareXFiles([XFile(path)], text: 'Nakala - Ales Masaba Animal Feed');
  }

  Future<void> _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'db'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    if (path.endsWith('.json')) {
      await _confirmRestoreFirestore(path);
    } else {
      await _confirmRestoreDevice(path);
    }
  }

  Future<void> _confirmRestoreFirestore(String path) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(SW.restore),
        content: const Text(
          'Hii itaandika/kusasisha data ya biashara (bidhaa, mauzo, wateja, madeni, matumizi) '
          'kutoka kwenye faili hili kwenda Firestore. Data iliyopo haitafutwa - itasasishwa tu au kuongezwa.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(SW.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isWorking = true);
              try {
                await _repo.restoreFirestoreBackup(path);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data imerejeshwa kikamilifu Firestore.')),
                  );
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${SW.error}: $e')));
              } finally {
                if (mounted) setState(() => _isWorking = false);
              }
            },
            child: const Text(SW.confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestoreDevice(String path) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(SW.restore),
        content: const Text(
          'Una hakika? Hii itabadilisha cache ya kifaa hiki (watumiaji/mipangilio ya ndani). '
          'Programu itahitaji kufungwa na kufunguliwa tena baada ya kurejesha.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(SW.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isWorking = true);
              try {
                await _repo.restoreBackup(path);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Imerejeshwa. Tafadhali funga na fungua programu tena.')),
                  );
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${SW.error}: $e')));
              } finally {
                if (mounted) setState(() => _isWorking = false);
              }
            },
            child: const Text(SW.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isSuperAdmin) {
      return const Scaffold(body: AccessDeniedView());
    }
    return Scaffold(
      appBar: AppBar(title: const Text(SW.backup)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Data ya Biashara (Firestore)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text(
                  'Bidhaa, Mauzo, Wateja, Madeni, na Matumizi - hii ndiyo nakala muhimu zaidi.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(_isWorking ? SW.loading : 'Fanya Nakala ya Data Sasa'),
                  onPressed: _isWorking ? null : _createFirestoreBackup,
                ),
                const SizedBox(height: 20),
                Text('Cache ya Kifaa Hiki (SQLite)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text(
                  'Mipangilio na watumiaji waliohifadhiwa kwenye kifaa hiki pekee (si data ya biashara).',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.phone_android),
                  label: Text(_isWorking ? SW.loading : SW.manualBackup),
                  onPressed: _isWorking ? null : _createDeviceBackup,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Agiza Nakala Kutoka Faili'),
                  onPressed: _isWorking ? null : _importFromFile,
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Historia ya Nakala', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? const Center(child: Text(SW.noData))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _history.length,
                        itemBuilder: (context, i) {
                          final log = _history[i];
                          final path = log['file_path'] as String;
                          final type = log['backup_type'] as String;
                          final isFirestore = type == 'Firestore';
                          final createdAt = DateTime.tryParse(log['created_at'] as String);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                isFirestore ? Icons.cloud_outlined : Icons.phone_android,
                                color: AppColors.primaryGreen,
                              ),
                              title: Text(createdAt != null ? _dateFmt.format(createdAt) : ''),
                              subtitle: Text(type, style: const TextStyle(fontSize: 12)),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'share') _shareBackup(path);
                                  if (v == 'restore') {
                                    isFirestore ? _confirmRestoreFirestore(path) : _confirmRestoreDevice(path);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'share', child: Text('Shiriki')),
                                  const PopupMenuItem(value: 'restore', child: Text(SW.restore)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
