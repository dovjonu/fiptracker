import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  List<String> locations = [];
  List<String> whoList = [];
  bool _loading = true;
  String? _error;

  final _newLocationController = TextEditingController();
  final _newWhoController = TextEditingController();

  Future<void> _fetchSettings() async {
    setState(() { _loading = true; });
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('lPzjtYWL3JQrjNrWZjb2').get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          locations = List<String>.from(data['locations'] ?? []);
          whoList = List<String>.from(data['who'] ?? []);
        });
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    }
    setState(() { _loading = false; });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    // Optionally, navigate to login screen if you re-enable login
  }

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nustatymai")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                    ],
                    const Text("Vietos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ...locations.map((loc) => Row(
                          children: [
                            Expanded(child: Text(loc)),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () async {
                                setState(() { locations.remove(loc); });
                                await FirebaseFirestore.instance.collection('settings').doc('lPzjtYWL3JQrjNrWZjb2').update({'locations': locations});
                              },
                            ),
                          ],
                        )),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newLocationController,
                            decoration: const InputDecoration(hintText: "Pridėti naują vietą"),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            final newLoc = _newLocationController.text.trim();
                            if (newLoc.isNotEmpty && !locations.contains(newLoc)) {
                              setState(() { locations.add(newLoc); });
                              await FirebaseFirestore.instance.collection('settings').doc('lPzjtYWL3JQrjNrWZjb2').update({'locations': locations});
                              _newLocationController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text("Kas suleido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ...whoList.map((who) => Row(
                          children: [
                            Expanded(child: Text(who)),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () async {
                                setState(() { whoList.remove(who); });
                                await FirebaseFirestore.instance.collection('settings').doc('lPzjtYWL3JQrjNrWZjb2').update({'who': whoList});
                              },
                            ),
                          ],
                        )),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newWhoController,
                            decoration: const InputDecoration(hintText: "Pridėti naują asmenį"),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            final newWho = _newWhoController.text.trim();
                            if (newWho.isNotEmpty && !whoList.contains(newWho)) {
                              setState(() { whoList.add(newWho); });
                              await FirebaseFirestore.instance.collection('settings').doc('lPzjtYWL3JQrjNrWZjb2').update({'who': whoList});
                              _newWhoController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _logout,
                      child: const Text("Atsijungti"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
