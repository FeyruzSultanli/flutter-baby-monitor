import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../core/alert_history_service.dart';
import '../l10n/app_localizations.dart';

class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  final AlertHistoryService _service = AlertHistoryService();
  List<AlertModel> _alerts = [];
  bool _isLoading = true;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final alerts = await _service.getAlerts();
    if (mounted) {
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 0, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 23, minute: 59),
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _getGroupLabel(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) {
      return l10n.today;
    } else if (checkDate == yesterday) {
      return l10n.yesterday;
    } else {
      return _formatDate(date);
    }
  }

  Map<String, List<AlertModel>> _groupAlerts(AppLocalizations l10n) {
    final Map<String, List<AlertModel>> groups = {};
    for (var alert in _alerts) {
      // Date Filter
      if (_selectedDate != null) {
        final alertDate = DateTime(alert.timestamp.year, alert.timestamp.month, alert.timestamp.day);
        final filterDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
        if (alertDate != filterDate) continue;
      }

      // Time Filter
      final alertMinutes = alert.timestamp.hour * 60 + alert.timestamp.minute;
      if (_startTime != null) {
        final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
        if (alertMinutes < startMinutes) continue;
      }
      if (_endTime != null) {
        final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
        if (alertMinutes > endMinutes) continue;
      }

      final label = _getGroupLabel(alert.timestamp, l10n);
      if (!groups.containsKey(label)) {
        groups[label] = [];
      }
      groups[label]!.add(alert);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groupedAlerts = _groupAlerts(l10n);
    final sortedKeys = groupedAlerts.keys.toList(); 

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.alertHistory),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.clearHistory),
                  content: Text(l10n.clearHistoryConfirmation),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _service.clearHistory();
                _loadAlerts();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedDate == null 
                              ? l10n.dateAll 
                              : '${l10n.date}: ${_formatDate(_selectedDate!)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      TextButton(
                        onPressed: _pickDate,
                        child: Text(_selectedDate == null ? l10n.pick : l10n.change),
                      ),
                      if (_selectedDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => setState(() => _selectedDate = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (_startTime == null && _endTime == null)
                              ? l10n.timeRangeAll
                              : '${_startTime?.format(context) ?? l10n.startTime} - ${_endTime?.format(context) ?? l10n.endTime}',
                           style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      TextButton(
                        onPressed: _pickStartTime,
                        child: Text(l10n.start),
                      ),
                      TextButton(
                        onPressed: _pickEndTime,
                        child: Text(l10n.end),
                      ),
                      if (_startTime != null || _endTime != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => setState(() {
                            _startTime = null;
                            _endTime = null;
                          }),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _alerts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(l10n.noAlertsYet, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: sortedKeys.length,
                        itemBuilder: (context, index) {
                          final key = sortedKeys[index];
                          final groupItems = groupedAlerts[key]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                                child: Text(
                                  key,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                              ...groupItems.map((alert) => Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    child: ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: Colors.redAccent,
                                        child: Icon(Icons.warning_amber_rounded, color: Colors.white),
                                      ),
                                      title: Text(alert.message),
                                      subtitle: Text(
                                        alert.decibel != null 
                                          ? '${l10n.noiseLevel}: ${alert.decibel!.toStringAsFixed(1)} dB' 
                                          : l10n.motionOrSoundDetected,
                                      ),
                                      trailing: Text(
                                        _formatTime(alert.timestamp),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  )),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
