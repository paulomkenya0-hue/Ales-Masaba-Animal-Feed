import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../data/repositories/backup_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/access_denied_view.dart';

/// BackupScreen - Hifadhi Nakala Mwenyewe, Historia ya Nakala, na Kurejesha
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

  Future<void> _createBackup() async {
    setState(() => _isWorking = true);
    try {
      await _repo.createBackup(type: 'Manual');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(SW.savedSuccess)));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${SW.error}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _shareBackup(String path) async {
    await Share.shareXFiles([XFile(path)], text: 'Nakala ya Hifadhidata - Ales Masaba Animal Feed');
  }

  Future<void> _confirmRestore(String path) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(SW.restore),
        content: const Text(
          'Una hakika? Hii itabadilisha data zote za sasa na data za nakala hii. '
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
                ElevatedButton.icon(
                  icon: const Icon(Icons.backup),
                  label: Text(_isWorking ? SW.loading : SW.manualBackup),
                  onPressed: _isWorking ? null : _createBackup,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nakala zinahifadhiwa ndani ya simu (Hifadhi ya Programu). '
                  'Tumia "Shiriki" kutuma kwa Google Drive, WhatsApp au Email kama nakala ya nje.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
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
                          final createdAt = DateTime.tryParse(log['created_at'] as String);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.insert_drive_file, color: AppColors.primaryGreen),
                              title: Text(createdAt != null ? _dateFmt.format(createdAt) : ''),
                              subtitle: Text(log['backup_type'] as String, style: const TextStyle(fontSize: 12)),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'share') _shareBackup(path);
                                  if (v == 'restore') _confirmRestore(path);
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
