import 'package:flutter/material.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony_sms/telephony_sms.dart';
import './../services/contact_database.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  _ContactScreenState createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  List<Contact> contacts = [];
  List<Contact> selectedContacts = [];
  List<Map<String, dynamic>> savedContacts = [];
  final _telephonySMS = TelephonySMS();
  int _currentIndex = 0;

  String query = "";

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadSavedContacts();
  }

  /// Load device contacts
  Future<void> _loadContacts() async {
    if (await Permission.contacts.request().isGranted) {
      final fetchedContacts = await FastContacts.getAllContacts();
      setState(() {
        contacts = fetchedContacts;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact permission denied')),
      );
    }
  }

  /// Save selected contacts into SQLite
  Future<void> _saveContacts() async {
    await DBHelper.deleteAll(); // clear old selections
    for (var contact in selectedContacts) {
      for (var phone in contact.phones) {
        await DBHelper.insertContact(contact.displayName, phone.number);
      }
    }
    await _loadSavedContacts();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Contacts saved to SQLite')));
  }

  /// Load saved contacts from SQLite
  Future<void> _loadSavedContacts() async {
    final data = await DBHelper.getContacts();
    setState(() {
      savedContacts = data;
    });
  }

  /// Toggle contact selection
  void _toggleSelection(Contact contact) {
    setState(() {
      if (selectedContacts.contains(contact)) {
        selectedContacts.remove(contact);
      } else if (selectedContacts.length < 10) {
        selectedContacts.add(contact);
      }
    });
  }

  /// Build contact list
  Widget _buildContactList() {
    if (contacts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filterdContacts = contacts
        .where((c) => c.displayName.toLowerCase().contains(query.toLowerCase()))
        .toList();

    filterdContacts.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );

    final Map<String, List<Contact>> grouped = {};
    for (var c in filterdContacts) {
      final firstLetter = c.displayName.isNotEmpty
          ? c.displayName[0].toUpperCase()
          : "#";

      grouped.putIfAbsent(firstLetter, () => []).add(c);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: "Search ...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                query = value;
              });
            },
          ),
        ),
        Expanded(
          child: ListView(
            children: grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.grey[100],
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  ...entry.value.map((c) {
                    final selected = selectedContacts.contains(c);
                    return ListTile(
                      title: Text(c.displayName),
                      subtitle: Text(
                        c.phones.isNotEmpty ? c.phones.first.number : '',
                      ),
                      trailing: Checkbox(
                        value: selected,
                        onChanged: (_) => _toggleSelection(c),
                      ),
                      onTap: () => _toggleSelection(c),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Build saved contacts list
  Widget _buildSavedContacts() {
    if (savedContacts.isEmpty) {
      return const Center(child: Text("No saved contacts"));
    }
    return ListView.builder(
      itemCount: savedContacts.length,
      itemBuilder: (context, index) {
        final c = savedContacts[index];
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(c['name']),
          subtitle: Text(c['phone']),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [_buildContactList(), _buildSavedContacts()];

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.contacts), label: "All"),
          BottomNavigationBarItem(icon: Icon(Icons.save), label: "Saved"),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      floatingActionButton: _currentIndex == 0
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'save',
                  onPressed: _saveContacts,
                  child: const Icon(Icons.save),
                ),
                const SizedBox(height: 20.0),
                ElevatedButton(
                  onPressed: () async {
                    await _telephonySMS.requestPermission();
                  },
                  child: const Text('Check Permission'),
                ),
                const SizedBox(height: 20.0),
              ],
            )
          : null,
    );
  }
}
