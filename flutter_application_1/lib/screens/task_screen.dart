import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../widgets/task_card.dart';
import '../widgets/loading_widget.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final ApiService _apiService = ApiService();
  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _error;
  
  // Filter states
  String _filterStatus = 'all'; // all, pending, completed, overdue
  String _sortBy = 'due_date'; // due_date, priority, created_at

  int _getPriorityValue(String priority) {
    switch (priority) {
      case 'high':
        return 1;
      case 'medium':
        return 2;
      case 'low':
        return 3;
      default:
        return 2;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // TODO: Implement getTasks method in ApiService
      // For now, we'll simulate with empty list
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _tasks = []; // TODO: Replace with actual API call
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    try {
      // TODO: Implement task completion toggle
      setState(() {
        task.isCompleted = !task.isCompleted;
        if (task.isCompleted) {
          task.completedAt = DateTime.now();
        } else {
          task.completedAt = null;
        }
      });
      
      _showSuccessSnackBar(
        task.isCompleted ? 'Task completed!' : 'Task marked as pending'
      );
    } catch (e) {
      _showErrorSnackBar('Error updating task: $e');
    }
  }

  Future<void> _syncToCalendar(Task task) async {
    try {
      // TODO: Implement calendar sync
      _showSuccessSnackBar('Task synced to calendar');
    } catch (e) {
      _showErrorSnackBar('Error syncing to calendar: $e');
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // TODO: Implement task deletion
        setState(() {
          _tasks.remove(task);
        });
        _showSuccessSnackBar('Task deleted');
      } catch (e) {
        _showErrorSnackBar('Error deleting task: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  List<Task> _getFilteredTasks() {
    List<Task> filtered = List.from(_tasks);

    // Apply status filter
    switch (_filterStatus) {
      case 'pending':
        filtered = filtered.where((task) => !task.isCompleted).toList();
        break;
      case 'completed':
        filtered = filtered.where((task) => task.isCompleted).toList();
        break;
      case 'overdue':
        final now = DateTime.now();
        filtered = filtered.where((task) => 
          !task.isCompleted && 
          task.dueDate != null && 
          task.dueDate!.isBefore(now)
        ).toList();
        break;
    }

    // Apply sorting
    switch (_sortBy) {
      case 'due_date':
        filtered.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      case 'priority':
        filtered.sort((a, b) => b.priority.compareTo(a.priority));
        break;
      case 'created_at':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _getFilteredTasks();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _loadTasks,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'due_date',
                child: Text('Sort by Due Date'),
              ),
              const PopupMenuItem(
                value: 'priority',
                child: Text('Sort by Priority'),
              ),
              const PopupMenuItem(
                value: 'created_at',
                child: Text('Sort by Created Date'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter tabs
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterTab('all', 'All', _tasks.length),
                      _buildFilterTab('pending', 'Pending', 
                        _tasks.where((t) => !t.isCompleted).length),
                      _buildFilterTab('completed', 'Completed', 
                        _tasks.where((t) => t.isCompleted).length),
                      _buildFilterTab('overdue', 'Overdue', 
                        _tasks.where((t) => 
                          !t.isCompleted && 
                          t.dueDate != null && 
                          t.dueDate!.isBefore(DateTime.now())
                        ).length),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Task count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${filteredTasks.length} tasks',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (_filterStatus != 'all')
                  Text(
                    'Filtered from ${_tasks.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          
          // Tasks list
          Expanded(
            child: _buildTaskList(filteredTasks),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  Widget _buildFilterTab(String status, String label, int count) {
    final isSelected = _filterStatus == status;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _filterStatus = status;
          });
        },
        selectedColor: _getStatusColor(status),
      ),
    );
  }

  Color? _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange[100];
      case 'completed':
        return Colors.green[100];
      case 'overdue':
        return Colors.red[100];
      default:
        return Colors.blue[100];
    }
  }

  Widget _buildTaskList(List<Task> tasks) {
    if (_isLoading) {
      return const Center(
        child: LoadingWidget(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading tasks',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _filterStatus == 'all' ? Icons.task_alt : Icons.filter_list,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _filterStatus == 'all' ? 'No tasks yet' : 'No tasks match your filter',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _filterStatus == 'all' 
                  ? 'Extract tasks from your data sources or add them manually'
                  : 'Try changing your filter or add new tasks',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddTaskDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TaskCard(
              task: task,
              onTap: () => _toggleTaskCompletion(task),
              onSyncToCalendar: () => _syncToCalendar(task),
              onDelete: () => _deleteTask(task),
            ),
          );
        },
      ),
    );
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? selectedDueDate;
    String selectedPriority = 'medium';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Task Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedDueDate == null
                            ? 'No due date'
                            : 'Due: ${selectedDueDate!.day}/${selectedDueDate!.month}/${selectedDueDate!.year}',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setDialogState(() {
                            selectedDueDate = date;
                          });
                        }
                      },
                      child: const Text('Set Due Date'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedPriority = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  final newTask = Task(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text,
                    verb: 'do',
                    text: descriptionController.text,
                    priority: _getPriorityValue(selectedPriority),
                    dueDate: selectedDueDate,
                    isCompleted: false,
                    createdAt: DateTime.now(),
                    source: 'manual',
                    sourceId: DateTime.now().millisecondsSinceEpoch.toString(),
                  );
                  
                  setState(() {
                    _tasks.add(newTask);
                  });
                  
                  Navigator.of(context).pop();
                  _showSuccessSnackBar('Task added successfully');
                }
              },
              child: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }
}
