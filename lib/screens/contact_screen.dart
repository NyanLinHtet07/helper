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

  /// Send SMS in background
  Future<void> _autoSMS() async {
    final numbers = selectedContacts
        .expand((c) => c.phones.map((p) => p.number))
        .join(', ');

    const message = "I will be there";

    try {
      final numberList = numbers
          .split(',')
          .map((n) => n.trim())
          .where((n) => n.isNotEmpty);
      for (var number in numberList) {
        await _telephonySMS.sendSMS(phone: number, message: message);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messages sent successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send SMS: $e')));
    }
  }

  /// Build contact list
  Widget _buildContactList() {
    if (contacts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final c = contacts[index];
        final selected = selectedContacts.contains(c);
        return ListTile(
          title: Text(c.displayName),
          subtitle: Text(c.phones.isNotEmpty ? c.phones.first.number : ''),
          trailing: Checkbox(
            value: selected,
            onChanged: (_) => _toggleSelection(c),
          ),
          onTap: () => _toggleSelection(c),
        );
      },
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
                  child: const Icon(Icons.save),
                  onPressed: _saveContacts,
                ),
                const SizedBox(height: 20.0),
                ElevatedButton(
                  onPressed: () async {
                    await _telephonySMS.requestPermission();
                  },
                  child: const Text('Check Permission'),
                ),
                const SizedBox(height: 20.0),
                // ElevatedButton(
                //   onPressed: _autoSMS,
                //   child: const Text('Send Auto SMS'),
                // ),
              ],
            )
          : null,
    );
  }
}
