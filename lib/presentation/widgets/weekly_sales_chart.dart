import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/strings_sw.dart';
import '../../data/repositories/sales_repository.dart';

/// WeeklySalesChart - Chati ya mauzo ya siku 7 zilizopita, kwa picha rahisi kuelewa
class WeeklySalesChart extends StatefulWidget {
  const WeeklySalesChart({super.key});

  @override
  State<WeeklySalesChart> createState() => _WeeklySalesChartState();
}

class _WeeklySalesChartState extends State<WeeklySalesChart> {
  final _repo = SalesRepository();
  List<double> _values = [];
  List<String> _labels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final values = <double>[];
    final labels = <String>[];

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final next = day.add(const Duration(days: 1));
      final total = await _repo.getTotalSales(day, next);
      values.add(total);
      labels.add(DateFormat('E', 'sw').format(day));
    }

    if (mounted) {
      setState(() {
        _values = values;
        _labels = labels;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
    }

    final maxVal = _values.isEmpty ? 1.0 : (_values.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1.0, double.infinity);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(SW.weeklySales, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  maxY: maxVal,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= _labels.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_labels[i], style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: List.generate(_values.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: _values[i],
                          color: AppColors.primaryGreen,
                          width: 18,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
