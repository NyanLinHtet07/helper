import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DBHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  static Future<Database> initDb() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "contacts.db");

    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE selected_contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            phone TEXT
          )
        ''');
      },
    );
  }

  static Future<int> insertContact(String name, String phone) async {
    final dbClient = await db;
    return await dbClient.insert("selected_contacts", {
      "name": name,
      "phone": phone,
    });
  }

  static Future<List<Map<String, dynamic>>> getContacts() async {
    final dbClient = await db;
    return await dbClient.query("selected_contacts");
  }

  static Future<int> deleteAll() async {
    final dbClient = await db;
    return await dbClient.delete("selected_contacts");
  }
}
