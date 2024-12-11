import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/todo.dart';
import '../helpers/settings_helper.dart';

class DatabaseHelper {
  static const _databaseName = "todo_database.db";
  static const _databaseVersion = 4;
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
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        isCompleted INTEGER NOT NULL,
        orderIndex INTEGER NOT NULL,
        isTimerRunning INTEGER NOT NULL DEFAULT 0,
        remainingSeconds INTEGER NOT NULL DEFAULT ${SettingsHelper.defaultPomodoroMinutes * 60},
        completedPomodoros INTEGER NOT NULL DEFAULT 0,
        currentProgress REAL NOT NULL DEFAULT 0.0
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $table ADD COLUMN orderIndex INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE $table ADD COLUMN isTimerRunning INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE $table ADD COLUMN remainingSeconds INTEGER NOT NULL DEFAULT ${SettingsHelper.defaultPomodoroMinutes * 60}');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE $table ADD COLUMN completedPomodoros INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE $table ADD COLUMN currentProgress REAL NOT NULL DEFAULT 0.0');
    }
  }

  Future<int> insertTodo(Todo todo) async {
    Database db = await database;
    return await db.insert(
      table,
      {
        'id': todo.id,
        'title': todo.title,
        'isCompleted': todo.isCompleted ? 1 : 0,
        'orderIndex': todo.orderIndex,
        'isTimerRunning': todo.isTimerRunning ? 1 : 0,
        'remainingSeconds': todo.remainingSeconds,
        'completedPomodoros': todo.completedPomodoros,
        'currentProgress': todo.currentProgress,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Todo>> getTodos() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      orderBy: 'orderIndex ASC',
    );
    return List.generate(maps.length, (i) {
      return Todo(
        id: maps[i]['id'],
        title: maps[i]['title'],
        isCompleted: maps[i]['isCompleted'] == 1,
        orderIndex: maps[i]['orderIndex'],
        isTimerRunning: maps[i]['isTimerRunning'] == 1,
        remainingSeconds: maps[i]['remainingSeconds'] ?? (SettingsHelper.defaultPomodoroMinutes * 60),
        completedPomodoros: maps[i]['completedPomodoros'] ?? 0,
        currentProgress: maps[i]['currentProgress'] ?? 0.0,
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
        'completedPomodoros': todo.completedPomodoros,
        'currentProgress': todo.currentProgress,
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

  Future<void> updateTodoOrder(String id, int newOrder) async {
    Database db = await database;
    await db.update(
      table,
      {'orderIndex': newOrder},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> reorderTodos(List<Todo> todos) async {
    Database db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < todos.length; i++) {
        await txn.update(
          table,
          {'orderIndex': i},
          where: 'id = ?',
          whereArgs: [todos[i].id],
        );
      }
    });
  }

  Future<void> updateTimer(String id, bool isRunning, int remainingSeconds) async {
    Database db = await database;
    await db.update(
      table,
      {
        'isTimerRunning': isRunning ? 1 : 0,
        'remainingSeconds': remainingSeconds,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updatePomodoroProgress(String id, int completedPomodoros, double currentProgress) async {
    Database db = await database;
    await db.update(
      table,
      {
        'completedPomodoros': completedPomodoros,
        'currentProgress': currentProgress,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
} 