import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Suleidimų istorija")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('injections')
            .orderBy('time', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No records found"));
          }

          final docs = snapshot.data!.docs;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal, // allow table scrolling
            child: DataTable(
              columns: const [
                DataColumn(label: Text("Data")),
                DataColumn(label: Text("Vieta")),
                DataColumn(label: Text("Kas suleido")),
                DataColumn(label: Text("Svoris (kg)")),
                DataColumn(label: Text("Dozė (ml)")),
              ],
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final dateTime = (data['time'] as Timestamp).toDate();
                final dateStr =
                    "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";

                return DataRow(cells: [
                  DataCell(Text(dateStr)),
                  DataCell(Text("${data['location'] ?? '-'}")),
                  DataCell(Text("${data['who'] ?? '-'}")),
                  DataCell(Text("${data['weight'] ?? '-'}")),
                  DataCell(Text("${data['dosage'] ?? '-'}")),
                ]);
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
