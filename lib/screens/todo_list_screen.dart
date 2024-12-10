import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../helpers/database_helper.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final List<Todo> _todos = [];
  final _textController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadTodos();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('待办事项'),
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
            child: ListView.builder(
              itemCount: _todos.length,
              itemBuilder: (context, index) {
                final todo = _todos[index];
                return ListTile(
                  leading: Checkbox(
                    value: todo.isCompleted,
                    onChanged: (_) => _toggleTodo(todo.id),
                  ),
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      decoration: todo.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
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
    _textController.dispose();
    super.dispose();
  }
} 