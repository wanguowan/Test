import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../helpers/database_helper.dart';
import 'dart:async';
import '../helpers/settings_helper.dart';
import '../screens/settings_screen.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final List<Todo> _todos = [];
  final _textController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;
  final _settingsHelper = SettingsHelper.instance;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadTodos();
    _startTimerCheck();
  }

  void _startTimerCheck() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      bool needsUpdate = false;
      final defaultTime = await _settingsHelper.getPomodoroTime();
      for (var todo in _todos) {
        if (todo.isTimerRunning && (todo.remainingSeconds ?? 0) > 0) {
          todo.remainingSeconds = (todo.remainingSeconds ?? (defaultTime * 60)) - 1;
          if ((todo.remainingSeconds ?? 0) <= 0) {
            todo.isTimerRunning = false;
            todo.remainingSeconds = 0;
          }
          needsUpdate = true;
          _dbHelper.updateTimer(todo.id, todo.isTimerRunning, todo.remainingSeconds ?? 0);
        }
      }
      if (needsUpdate) {
        setState(() {});
      }
    });
  }

  Future<void> _loadTodos() async {
    final todos = await _dbHelper.getTodos();
    setState(() {
      _todos.clear();
      _todos.addAll(todos);
    });
  }

  Future<void> _addTodo(String title) async {
    if (title.isEmpty) return;

    final todo = Todo(
      id: DateTime.now().toString(),
      title: title,
      orderIndex: _todos.length,
    );

    await _dbHelper.insertTodo(todo);
    await _loadTodos();
    _textController.clear();
  }

  Future<void> _toggleTodo(String id) async {
    final todo = _todos.firstWhere((todo) => todo.id == id);
    todo.isCompleted = !todo.isCompleted;
    await _dbHelper.updateTodo(todo);
    await _loadTodos();
  }

  Future<void> _deleteTodo(String id) async {
    await _dbHelper.deleteTodo(id);
    await _loadTodos();
  }

  Future<void> _toggleTimer(String id) async {
    final todo = _todos.firstWhere((todo) => todo.id == id);
    final pomodoroTime = await _settingsHelper.getPomodoroTime();
    setState(() {
      todo.isTimerRunning = !todo.isTimerRunning;
      if (!todo.isTimerRunning && (todo.remainingSeconds == null || todo.remainingSeconds == 0)) {
        todo.remainingSeconds = pomodoroTime * 60;
      }
    });
    await _dbHelper.updateTimer(
      todo.id, 
      todo.isTimerRunning, 
      todo.remainingSeconds ?? (pomodoroTime * 60)
    );
  }

  String _formatTime(int? seconds) {
    if (seconds == null) {
      final defaultMinutes = SettingsHelper.defaultPomodoroMinutes;
      return '$defaultMinutes:00';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('待办事项'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
              await _loadTodos();
              for (var todo in _todos) {
                if (!todo.isCompleted && !todo.isTimerRunning) {
                  final pomodoroTime = await _settingsHelper.getPomodoroTime();
                  todo.remainingSeconds = pomodoroTime * 60;
                  await _dbHelper.updateTimer(
                    todo.id, 
                    todo.isTimerRunning, 
                    todo.remainingSeconds ?? (pomodoroTime * 60)
                  );
                }
              }
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '添加新的待办事项',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _addTodo(_textController.text),
                  child: const Text('添加'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _todos.length,
              onReorder: (oldIndex, newIndex) async {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final Todo item = _todos.removeAt(oldIndex);
                  _todos.insert(newIndex, item);
                });
                await _dbHelper.reorderTodos(_todos);
              },
              itemBuilder: (context, index) {
                final todo = _todos[index];
                return ListTile(
                  key: Key(todo.id),
                  leading: Checkbox(
                    value: todo.isCompleted,
                    onChanged: (_) => _toggleTodo(todo.id),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          todo.title,
                          style: TextStyle(
                            decoration: todo.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (!todo.isCompleted) ...[
                        Text(_formatTime(todo.remainingSeconds)),
                        IconButton(
                          icon: Icon(
                            todo.isTimerRunning ? Icons.pause : Icons.play_arrow,
                          ),
                          onPressed: () => _toggleTimer(todo.id),
                        ),
                      ],
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteTodo(todo.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textController.dispose();
    super.dispose();
  }
} 