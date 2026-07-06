import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/theme/app_theme.dart';

/// ConnectivityBanner - Inaonekana juu ya skrini pale kifaa kinapokuwa
/// Offline, kumkumbusha mtumiaji kuwa data itasawazishwa (sync) moja kwa
/// moja mara mtandao utakaporudi (Firestore inashughulikia hili yenyewe).
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (mounted) setState(() => _isOffline = offline);
    });
  }

  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (mounted) setState(() => _isOffline = offline);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.warning,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Uko Offline - unaweza kuendelea kuuza, data itasawazishwa mtandao ukirudi',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
