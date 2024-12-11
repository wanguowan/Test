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
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
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
      final totalSeconds = defaultTime * 60;

      for (var todo in _todos) {
        if (todo.isTimerRunning && (todo.remainingSeconds ?? 0) > 0) {
          todo.remainingSeconds = (todo.remainingSeconds ?? totalSeconds) - 1;
          
          // 计算进度
          todo.currentProgress = 1.0 - (todo.remainingSeconds ?? 0) / totalSeconds;
          
          if ((todo.remainingSeconds ?? 0) <= 0) {
            todo.isTimerRunning = false;
            todo.remainingSeconds = 0;
            todo.completedPomodoros++;  // 增加完成的番茄钟数量
            todo.currentProgress = 0.0;  // 重置进度
            
            // 更新数据库中的番茄钟计数
            await _dbHelper.updatePomodoroProgress(
              todo.id,
              todo.completedPomodoros,
              todo.currentProgress
            );
          }
          
          needsUpdate = true;
          await _dbHelper.updateTimer(todo.id, todo.isTimerRunning, todo.remainingSeconds ?? 0);
        }
      }
      if (needsUpdate) {
        setState(() {});
      }
    });
  }

  Future<void> _loadTodos() async {
    final todos = await _dbHelper.getTodos();
    
    // 如果列表已经有项目，先全部移除
    if (_todos.isNotEmpty) {
      final length = _todos.length;
      _todos.clear();
      for (int i = length - 1; i >= 0; i--) {
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => const SizedBox.shrink(),
          duration: const Duration(milliseconds: 0),
        );
      }
    }

    // 添加新的项目
    setState(() {
      _todos.addAll(todos);
    });

    // 逐个插入新项目
    for (int i = 0; i < todos.length; i++) {
      _listKey.currentState?.insertItem(
        i,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  Future<void> _addTodo(String title) async {
    if (title.isEmpty) return;

    final todo = Todo(
      id: DateTime.now().toString(),
      title: title,
      orderIndex: _todos.length,
    );

    await _dbHelper.insertTodo(todo);
    
    // 直接添加到列表并显示动画
    setState(() {
      _todos.add(todo);
      _listKey.currentState?.insertItem(
        _todos.length - 1,
        duration: const Duration(milliseconds: 300),
      );
    });
    
    _textController.clear();
  }

  Future<void> _toggleTodo(String id) async {
    final todo = _todos.firstWhere((todo) => todo.id == id);
    final oldIndex = _todos.indexOf(todo);
    todo.isCompleted = !todo.isCompleted;

    // 创建新的排序列表
    final newTodos = List<Todo>.from(_todos);
    newTodos.sort((a, b) {
      if (a.isCompleted == b.isCompleted) {
        return a.orderIndex.compareTo(b.orderIndex);
      }
      return a.isCompleted ? 1 : -1;
    });

    // 计算项目的新位置
    final newIndex = newTodos.indexWhere((t) => t.id == todo.id);

    // 使用动画移动项目
    setState(() {
      // 从旧位置移除
      _todos.removeAt(oldIndex);
      _listKey.currentState?.removeItem(
        oldIndex,
        (context, animation) => _buildItem(_todos[oldIndex], animation),
        duration: const Duration(milliseconds: 300),
      );

      // 插入到新位置
      _todos.insert(newIndex, todo);
      _listKey.currentState?.insertItem(
        newIndex,
        duration: const Duration(milliseconds: 300),
      );

      // 更新所有项目的 orderIndex
      for (int i = 0; i < _todos.length; i++) {
        _todos[i].orderIndex = i;
      }
    });

    await _dbHelper.updateTodo(todo);
    await _dbHelper.reorderTodos(_todos);
  }

  Widget _buildItem(Todo item, Animation<double> animation) {
    return SlideTransition(
      position: animation.drive(
        Tween(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
      ),
      child: FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          child: ListTile(
            key: Key(item.id),
            leading: Checkbox(
              value: item.isCompleted,
              onChanged: (_) => _toggleTodo(item.id),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      decoration: item.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                _buildPomodoroIndicator(item),
                if (!item.isCompleted) ...[
                  Text(_formatTime(item.remainingSeconds)),
                  IconButton(
                    icon: Icon(
                      item.isTimerRunning ? Icons.pause : Icons.play_arrow,
                    ),
                    onPressed: () => _toggleTimer(item.id),
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteTodo(item.id),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTodo(String id) async {
    await _dbHelper.deleteTodo(id);
    await _loadTodos();
  }

  Future<void> _toggleTimer(String id) async {
    final todo = _todos.firstWhere((todo) => todo.id == id);
    final pomodoroTime = await _settingsHelper.getPomodoroTime();
    
    setState(() {
      if (!todo.isTimerRunning) {
        for (var otherTodo in _todos) {
          if (otherTodo.id != id && otherTodo.isTimerRunning) {
            otherTodo.isTimerRunning = false;
            _dbHelper.updateTimer(
              otherTodo.id,
              false,
              otherTodo.remainingSeconds ?? (pomodoroTime * 60)
            );
          }
        }
      }
      
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

  Widget _buildPomodoroIndicator(Todo todo) {
    if (todo.completedPomodoros == 0 && todo.currentProgress == 0.0) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        // 显示完整番茄钟
        if (todo.completedPomodoros > 0)
          Row(
            children: [
              Text('🍅' * todo.completedPomodoros),  // 使用重复的表情符号
              const SizedBox(width: 4),
            ],
          ),
        // 显示进行中的番茄钟进度
        if (todo.currentProgress > 0.0)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: todo.currentProgress,
              strokeWidth: 2,
            ),
          ),
      ],
    );
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
            child: AnimatedList(
              key: _listKey,
              initialItemCount: _todos.length,
              itemBuilder: (context, index, animation) {
                return _buildItem(_todos[index], animation);
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