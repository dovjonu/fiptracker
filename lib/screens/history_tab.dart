import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  Future<Map<String, List<String>>> _fetchSettings() async {
    final doc = await FirebaseFirestore.instance.collection('settings').doc('lPzjtYWL3JQrjNrWZjb2').get();
    final data = doc.data();
    return {
      'locations': List<String>.from(data?['locations'] ?? ["error"]),
      'who': List<String>.from(data?['who'] ?? ["error"]),
    };
  }

  Future<void> _exportAsCSV(BuildContext context) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('injections')
          .orderBy('time', descending: true)
          .get();

      final docs = query.docs;

      // CSV header
      final csvRows = <List<String>>[
        ['Data', 'Vieta', 'Kas suleido', 'Svoris (kg)', 'Dozė (ml)']
      ];

      // CSV rows
      for (final doc in docs) {
        final data = doc.data();
        final dateTime = (data['time'] as Timestamp).toDate();
        final dateStr =
            "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} "
            "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
        csvRows.add([
          dateStr,
          "${data['location'] ?? ''}",
          "${data['who'] ?? ''}",
          "${data['weight'] ?? ''}",
          "${data['dosage'] ?? ''}",
        ]);
      }

      // Convert to CSV string
      final csvString = const ListToCsvConverter().convert(csvRows);

      // Request storage permission if needed (especially on Android)
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isPermanentlyDenied) {
          // Show dialog to open app settings
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Leidimas būtinas"),
              content: const Text("Norėdami išsaugoti CSV, suteikite leidimą rašyti įrenginyje programėlės nustatymuose."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Atšaukti"),
                ),
                ElevatedButton(
                  onPressed: () {
                    openAppSettings();
                    Navigator.pop(context);
                  },
                  child: const Text("Atidaryti nustatymus"),
                ),
              ],
            ),
          );
          return;
        }
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Nėra leidimo rašyti į įrenginį: " + status.toString())),
          );
          return;
        }
      }

      // Get directory to save file
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        // On Android, getExternalStorageDirectory() returns something like /storage/emulated/0/Android/data/<package>/files
        // To save to Downloads, you can use:
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          directory = downloadsDir;
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final file = File('${directory!.path}/injections_export.csv');
      await file.writeAsString(csvString);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("CSV išsaugotas: ${file.path}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Klaida eksportuojant CSV: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<String>>>(
      future: _fetchSettings(),
      builder: (context, settingsSnapshot) {
        if (settingsSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (settingsSnapshot.hasError || !settingsSnapshot.hasData) {
          return Scaffold(body: Center(child: Text("Klaida kraunant nustatymus")));
        }
        final locations = settingsSnapshot.data!['locations']!;
        final whoList = settingsSnapshot.data!['who']!;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Suleidimų istorija"),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'export_csv') {
                    await _exportAsCSV(context);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'export_csv',
                    child: const Text("Eksportuoti kaip CSV failą"),
                  ),
                ],
              ),
            ],
          ),
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
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false, // <-- Add this line
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
                          "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} "
                          "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";

                      return DataRow(
                        cells: [
                          DataCell(Text(dateStr)),
                          DataCell(Text("${data['location'] ?? '-'}")),
                          DataCell(Text("${data['who'] ?? '-'}")),
                          DataCell(Text("${data['weight'] ?? '-'}")),
                          DataCell(Text("${data['dosage'] ?? '-'}")),
                        ],
                        onSelectChanged: (_) {
                          _showEditDialog(
                            context,
                            doc.id,
                            data,
                            locations,
                            whoList,
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, String docId,
      Map<String, dynamic> data, List<String> locations, List<String> whoList) {
    final uniqueLocations = locations.toSet().toList();
    final uniqueWhoList = whoList.toSet().toList();
    final weightController =
        TextEditingController(text: data['weight']?.toString() ?? '');
    final dosageController =
        TextEditingController(text: data['dosage']?.toString() ?? '');
    String location = uniqueLocations.contains(data['location'])
        ? data['location']
        : (uniqueLocations.isNotEmpty ? uniqueLocations.first : "");
    String whoInjected = uniqueWhoList.contains(data['who'])
        ? data['who']
        : (uniqueWhoList.isNotEmpty ? uniqueWhoList.first : "");
    DateTime selectedTime = (data['time'] as Timestamp).toDate();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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

              setState(() {
                selectedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
              });
            }

            return AlertDialog(
              title: const Text("Redaguoti įrašą"),
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
                      items: uniqueLocations
                          .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => location = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: whoInjected,
                      decoration: const InputDecoration(labelText: "Kas suleido"),
                      items: uniqueWhoList
                          .map((who) => DropdownMenuItem(value: who, child: Text(who)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => whoInjected = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    // Delete button: bottom left, icon only, red background
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
                        shape: MaterialStateProperty.all<OutlinedBorder>(
                          CircleBorder(),
                        ),
                      ),
                      tooltip: "Ištrinti",
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Ištrinti įrašą?"),
                            content: const Text("Ar tikrai norite ištrinti šį įrašą?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Atšaukti"),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Ištrinti", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await FirebaseFirestore.instance
                              .collection('injections')
                              .doc(docId)
                              .delete();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Įrašas ištrintas")),
                          );
                        }
                      },
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Atšaukti"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final weight = double.tryParse(weightController.text);
                        final dosage = double.tryParse(dosageController.text);

                        if (weight != null && dosage != null && location.isNotEmpty) {
                          await FirebaseFirestore.instance
                              .collection('injections')
                              .doc(docId)
                              .update({
                            'time': selectedTime,
                            'weight': weight,
                            'dosage': dosage,
                            'location': location,
                            'who': whoInjected,
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Įrašas atnaujintas")),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Užpildykite visus laukus")),
                          );
                        }
                      },
                      child: const Text("Išsaugoti"),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Helper for CSV conversion
class ListToCsvConverter {
  const ListToCsvConverter();

  String convert(List<List<String>> rows) {
    return rows.map((row) => row.map(_escapeCsv).join(',')).join('\n');
  }

  String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
