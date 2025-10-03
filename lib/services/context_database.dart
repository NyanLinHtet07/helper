import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ContextDBHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  static Future<Database> initDb() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "context.db");

    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(''' 
          CREATE TABLE contexts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            value TEXT
          )
        ''');

        // Insert Default Data
        await db.insert("contexts", {
          "value": "SOS! I need help. My location:",
        });
      },
    );
  }

  static Future<int> insertContext(String key, String value) async {
    final dbClient = await db;
    return await dbClient.insert("contexts", {"value": value});
  }

  static Future<String> getContexts() async {
    final dbClient = await db;
    final result = await dbClient.query("contexts", limit: 1);
    if (result.isNotEmpty) {
      return result.first["value"] as String;
    }
    return "SOS! I need help. My location:";
  }

  static Future<int> updateMessage(String newMessage) async {
    final dbClient = await db;
    return await dbClient.update(
      "contexts",
      {"value": newMessage},
      where: "id = ?",
      whereArgs: [1],
    );
  }

  static Future<int> deleteAll() async {
    final dbClient = await db;
    return await dbClient.delete("contexts");
  }
}
