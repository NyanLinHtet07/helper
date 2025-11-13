import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import './../services/contact_database.dart';

class ContactNewScreen extends StatefulWidget {
  const ContactNewScreen({super.key});

  @override
  ContactNewScreenState createState() => ContactNewScreenState();
}

class ContactNewScreenState extends State<ContactNewScreen> {
  List<Contact> contacts = [];
  List<Contact> selectedContacts = [];
  List<Map<String, dynamic>> savedContacts = [];
  int _currentIndex = 0;

  String query = "";
  bool _isLoadingContacts = false;
  bool _permissionDenied = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadSavedContacts();
  }

  /// Load device contacts
  Future<void> _loadContacts() async {
    setState(() {
      _isLoadingContacts = true;
      _permissionDenied = false;
    });
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      final fetchedContacts = await FastContacts.getAllContacts();
      setState(() {
        contacts = fetchedContacts;
        _isLoadingContacts = false;
      });
    } else {
      setState(() {
        _permissionDenied = true;
        _isLoadingContacts = false;
      });
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

  Future<void> _deleteContacts(int id) async {
    await DBHelper.deleteContact(id);
    await _loadSavedContacts();
  }

  /// Toggle contact selection
  void _toggleSelection(Contact contact) {
    setState(() {
      if (selectedContacts.contains(contact)) {
        selectedContacts.remove(contact);
      } else if (selectedContacts.length < 10) {
        selectedContacts.add(contact);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can select up to 10 contacts')),
        );
      }
    });
  }

  /// Debounced search handler
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        query = value;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Build contact list
  Widget _buildContactList() {
    if (_isLoadingContacts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_permissionDenied) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Contacts permission is required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please grant access to view and select contacts.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _loadContacts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: openAppSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final filterdContacts = contacts
        .where((c) => c.displayName.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (filterdContacts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.search_off, size: 56),
            SizedBox(height: 12),
            Text('No contacts match your search'),
          ],
        ),
      );
    }

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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search contacts",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        if (selectedContacts.isNotEmpty)
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final c = selectedContacts[index];
                final initials = c.displayName.isNotEmpty
                    ? c.displayName
                          .trim()
                          .split(' ')
                          .map((e) => e.isNotEmpty ? e[0] : '')
                          .take(2)
                          .join()
                          .toUpperCase()
                    : '?';
                return InputChip(
                  avatar: CircleAvatar(child: Text(initials)),
                  label: Text(c.displayName, overflow: TextOverflow.ellipsis),
                  onDeleted: () => _toggleSelection(c),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: selectedContacts.length,
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadContacts,
            child: ListView(
              children: grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ...entry.value.map((c) {
                      final selected = selectedContacts.contains(c);
                      final display = c.displayName;
                      final phone = c.phones.isNotEmpty
                          ? c.phones.first.number
                          : '';
                      final initials = display.isNotEmpty
                          ? display
                                .trim()
                                .split(' ')
                                .map((e) => e.isNotEmpty ? e[0] : '')
                                .take(2)
                                .join()
                                .toUpperCase()
                          : '?';
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(child: Text(initials)),
                          title: Text(
                            display,
                            style: TextStyle(fontSize: 16.0),
                          ),
                          subtitle: Text(
                            phone,
                            style: TextStyle(fontSize: 14.0),
                          ),
                          trailing: Checkbox(
                            value: selected,
                            onChanged: (_) => _toggleSelection(c),
                          ),
                          onTap: () => _toggleSelection(c),
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// Build saved contacts list
  Widget _buildSavedContacts() {
    if (savedContacts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.inbox_outlined, size: 56),
            SizedBox(height: 12),
            Text("No saved contacts"),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: savedContacts.length,
      itemBuilder: (context, index) {
        final c = savedContacts[index];
        final display = (c['name'] ?? '') as String;
        final phone = (c['phone'] ?? '') as String;
        final id = c['id'] as int;

        final initials = display.isNotEmpty
            ? display
                  .trim()
                  .split(' ')
                  .map((e) => e.isNotEmpty ? e[0] : '')
                  .take(2)
                  .join()
                  .toUpperCase()
            : '?';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(child: Text(initials)),
            title: Text(display, style: TextStyle(fontSize: 14.0)),
            subtitle: Text(phone, style: TextStyle(fontSize: 12.0)),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                await _deleteContacts(id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact Deleted')),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [_buildContactList(), _buildSavedContacts()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: _currentIndex == 0
            ? [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _isLoadingContacts ? null : _loadContacts,
                  icon: const Icon(Icons.refresh),
                ),
              ]
            : null,
      ),
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
                FloatingActionButton.extended(
                  heroTag: 'save',
                  onPressed: selectedContacts.isEmpty ? null : _saveContacts,
                  icon: const Icon(Icons.save),
                  label: Text(
                    selectedContacts.isEmpty
                        ? 'Save contacts'
                        : 'Save (${selectedContacts.length}/10)',
                  ),
                ),
                SizedBox(height: 16.0),
              ],
            )
          : null,
    );
  }
}
