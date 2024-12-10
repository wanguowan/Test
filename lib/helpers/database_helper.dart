import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/todo.dart';

class DatabaseHelper {
  static const _databaseName = "todo_database.db";
  static const _databaseVersion = 1;
  static const table = 'todos';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        isCompleted INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertTodo(Todo todo) async {
    Database db = await database;
    return await db.insert(
      table,
      {
        'id': todo.id,
        'title': todo.title,
        'isCompleted': todo.isCompleted ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Todo>> getTodos() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(table);
    return List.generate(maps.length, (i) {
      return Todo(
        id: maps[i]['id'],
        title: maps[i]['title'],
        isCompleted: maps[i]['isCompleted'] == 1,
      );
    });
  }

  Future<int> updateTodo(Todo todo) async {
    Database db = await database;
    return await db.update(
      table,
      {
        'title': todo.title,
        'isCompleted': todo.isCompleted ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  Future<int> deleteTodo(String id) async {
    Database db = await database;
    return await db.delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
} 