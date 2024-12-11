class Todo {
  String id;
  String title;
  bool isCompleted;
  int orderIndex;
  bool isTimerRunning;
  int? remainingSeconds;

  Todo({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.orderIndex,
    this.isTimerRunning = false,
    this.remainingSeconds,
  });
} 