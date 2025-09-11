import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  Future<Map<String, List<String>>> _fetchSettings() async {
    final doc = await FirebaseFirestore.instance.collection('settings').doc('lPzjtYWL3JQrjNrWZjb2').get();
    final data = doc.data();
    return {
      'location': List<String>.from(data?['locations'] ?? ["error"]),
      'who': List<String>.from(data?['who'] ?? ["error"]),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text("Overview")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('injections')
                  .orderBy('time', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                DateTime? lastInjectionTime;
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  final ts = data['time'];
                  if (ts is Timestamp) {
                    lastInjectionTime = ts.toDate();
                  } else if (ts is DateTime) {
                    lastInjectionTime = ts;
                  }
                }

                final now = DateTime.now();
                Duration remaining = Duration.zero;
                if (lastInjectionTime != null) {
                  final nextTime = lastInjectionTime.add(const Duration(hours: 24));
                  remaining = nextTime.difference(now);
                  if (remaining.isNegative) remaining = Duration.zero;
                }

                double progress = 0;
                if (lastInjectionTime != null) {
                  final elapsed = now.difference(lastInjectionTime).inSeconds;
                  progress = (elapsed / (24 * 3600)).clamp(0, 1);
                }

                String nextTimeText = lastInjectionTime != null
                    ? "${lastInjectionTime.add(const Duration(hours: 24)).year}-"
                      "${lastInjectionTime.add(const Duration(hours: 24)).month.toString().padLeft(2, '0')}-"
                      "${lastInjectionTime.add(const Duration(hours: 24)).day.toString().padLeft(2, '0')} "
                      "${lastInjectionTime.add(const Duration(hours: 24)).hour.toString().padLeft(2, '0')}:"
                      "${lastInjectionTime.add(const Duration(hours: 24)).minute.toString().padLeft(2, '0')}"
                    : "-";

                String timeText;
                if (remaining == Duration.zero) {
                  timeText = "Dabar";
                } else {
                  final h = remaining.inHours;
                  final m = remaining.inMinutes % 60;
                  timeText = "Už ${h}h ${m}m";
                }

                return Center(
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: 1 - progress,
                            strokeWidth: 6,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("Sekantis suleidimas", style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text(nextTimeText, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text(timeText, style: const TextStyle(fontSize: 24)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('injections')
                  .orderBy('time', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                int count = 0;
                String avgText = "-";
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  count = snapshot.data!.docs.length;
                  final docs = snapshot.data!.docs;
                  List<DateTime> times = docs
                      .take(4)
                      .map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final ts = data['time'];
                        if (ts is Timestamp) return ts.toDate();
                        if (ts is DateTime) return ts;
                        return null;
                      })
                      .whereType<DateTime>()
                      .toList();
                  if (times.length >= 2) {
                    List<int> diffs = [];
                    for (int i = 0; i < times.length - 1; i++) {
                      diffs.add(times[i].difference(times[i + 1]).inMinutes.abs());
                    }
                    if (diffs.isNotEmpty) {
                      final avg = diffs.reduce((a, b) => a + b) / diffs.length;
                      final h = (avg ~/ 60) - 24;
                      final m = avg % 60;
                      avgText = "${h}h ${m}m";
                    }
                  }
                }
                return Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: ListTile(
                          title: const Text("Suleidimų skaičius"),
                          subtitle: Text("$count/84"),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        child: ListTile(
                          title: const Text("Vidutinis laikas"),
                          subtitle: Text(avgText),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // fetch last injection
                final lastInjection = await FirebaseFirestore.instance
                    .collection('injections')
                    .orderBy('time', descending: true)
                    .limit(1)
                    .get();

                double? lastWeight;
                double? lastDosage;

                if (lastInjection.docs.isNotEmpty) {
                  final data = lastInjection.docs.first.data();
                  lastWeight = (data['weight'] as num?)?.toDouble();
                  lastDosage = (data['dosage'] as num?)?.toDouble();
                }

                final settings = await _fetchSettings();
                _showAddMedicineDialog(context, lastWeight, lastDosage, settings['location']!, settings['who']!);
              },
              child: const Text("Įrašyti suleidimą"),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMedicineDialog(BuildContext context, double? defaultWeight, double? defaultDosage, List<String> locations, List<String> whoList) {
    final weightController = TextEditingController(text: defaultWeight?.toString() ?? '');
    final dosageController = TextEditingController(text: defaultDosage?.toString() ?? '');
    String location = locations.isNotEmpty ? locations.first : "Kairė koja";
    String whoInjected = whoList.isNotEmpty ? whoList.first : "Dovydas";
    DateTime selectedTime = DateTime.now();

    Future<void> _pickDateTime() async {
      final date = await showDatePicker(
        context: context,
        initialDate: selectedTime,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (date == null) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedTime),
      );
      if (time == null) return;

      selectedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Įrašas"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text("Laikas: "),
                    TextButton(
                      onPressed: _pickDateTime,
                      child: Text(
                        "${selectedTime.year}-${selectedTime.month.toString().padLeft(2, '0')}-${selectedTime.day.toString().padLeft(2, '0')} "
                        "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Svoris (kg)"),
                ),
                TextField(
                  controller: dosageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Dozė (ml)"),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: location,
                  decoration: const InputDecoration(labelText: "Suleidimo vieta"),
                  items: locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc))).toList(),
                  onChanged: (value) {
                    if (value != null) location = value;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: whoInjected,
                  decoration: const InputDecoration(labelText: "Kas suleido"),
                  items: whoList.map((who) => DropdownMenuItem(value: who, child: Text(who))).toList(),
                  onChanged: (value) {
                    if (value != null) whoInjected = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Atšaukti"),
            ),
            ElevatedButton(
              onPressed: () async {
                final weight = double.tryParse(weightController.text);
                final dosage = double.tryParse(dosageController.text);

                if (weight != null && dosage != null && location.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('injections').add({
                    'time': selectedTime,
                    'weight': weight,
                    'dosage': dosage,
                    'location': location,
                    'who': whoInjected,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Medicine logged successfully")),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please fill all fields")),
                  );
                }
              },
              child: const Text("Išsaugoti"),
            ),
          ],
        );
      },
    );
  }
}
