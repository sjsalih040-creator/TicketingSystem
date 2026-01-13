import 'package:flutter/material.dart';
import '../models/ticket.dart';

class ReportsScreen extends StatelessWidget {
  final List<Ticket> allTickets;

  const ReportsScreen({super.key, required this.allTickets});

  @override
  Widget build(BuildContext context) {
    // Grouping by Warehouse
    Map<String, int> warehouseStats = {};
    for (var t in allTickets) {
      String wName = t.warehouseName ?? 'غير معروف';
      warehouseStats[wName] = (warehouseStats[wName] ?? 0) + 1;
    }

    int open = allTickets.where((t) => t.status == 0).length;
    int inProgress = allTickets.where((t) => t.status == 1).length;
    int resolved = allTickets.where((t) => t.status == 2).length;
    int closed = allTickets.where((t) => t.status == 3).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير المستودع'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نظرة عامة على الحالات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatusSummary(context, open, inProgress, resolved, closed),
            const SizedBox(height: 32),
            const Text(
              'توزيع التذاكر حسب المستودع',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...warehouseStats.entries.map((e) => _buildWarehouseRow(e.key, e.value, allTickets.length)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSummary(BuildContext context, int open, int prog, int res, int closed) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildSummaryItem('تذاكر مفتوحة', open, Colors.orange),
          const Divider(),
          _buildSummaryItem('قيد المعالجة', prog, Colors.blue),
          const Divider(),
          _buildSummaryItem('تذاكر محلولة', res, Colors.green),
          const Divider(),
          _buildSummaryItem('تذاكر مغلقة', closed, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 16)),
            ],
          ),
          Text(value.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWarehouseRow(String name, int count, int total) {
    double percent = total > 0 ? (count / total) : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('$count تذكرة', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrange),
            borderRadius: BorderRadius.circular(10),
            minHeight: 8,
          ),
        ],
      ),
    );
  }
}
