import 'package:flutter/material.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:telephony_sms/telephony_sms.dart';
import 'dart:io';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  _ContactScreen createState() => _ContactScreen();
}

class _ContactScreen extends State<ContactScreen> {
  List<Contact> contacts = [];
  List<Contact> selectedContacts = [];
  final _telephonySMS = TelephonySMS();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    if (await Permission.contacts.request().isGranted) {
      final fetchedContacts = await FastContacts.getAllContacts();
      setState(() {
        contacts = fetchedContacts;
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Contact permission denied')));
    }
  }

  void _toggleSelection(Contact contact) {
    setState(() {
      if (selectedContacts.contains(contact)) {
        selectedContacts.remove(contact);
      } else if (selectedContacts.length < 10) {
        selectedContacts.add(contact);
      }
    });
  }

  Future<void> _saveContacts() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/selected_contacts.txt');
    final name = selectedContacts.map((c) => c.displayName).join('\n');
    await file.writeAsString(name);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Contacts saved')));
  }

  Future<void> _sendSMS() async {
    final numbers = selectedContacts
        .expand((c) => c.phones.map((p) => p.number))
        .join(',');
    final smsUri = Uri.parse('sms:$numbers');
    if (!await launchUrl(smsUri)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open SMS app')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: contacts.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final c = contacts[index];
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
              },
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'save',
            child: Icon(Icons.save),
            onPressed: _saveContacts,
          ),

          SizedBox(height: 20.0),
          FloatingActionButton(
            heroTag: 'sms',
            child: Icon(Icons.sms),
            onPressed: _sendSMS,
          ),
          SizedBox(height: 20.0),
          ElevatedButton(
            onPressed: () async {
              await _telephonySMS.requestPermission();
            },
            child: const Text('Check Permission'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _telephonySMS.sendSMS(
                phone: "+959250015864",
                message: "Hello Loream",
              );
            },
            child: const Text('Send SMS'),
          ),
        ],
      ),
    );
  }
}
