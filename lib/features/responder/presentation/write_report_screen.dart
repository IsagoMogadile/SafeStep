import 'package:flutter/material.dart';

import '../data/responder_repository.dart';

/// scope.md §6 "Write report": short notes field, saved when resolving.
class WriteReportScreen extends StatefulWidget {
  const WriteReportScreen({super.key, required this.alertId});

  final String alertId;

  @override
  State<WriteReportScreen> createState() => _WriteReportScreenState();
}

class _WriteReportScreenState extends State<WriteReportScreen> {
  final _repository = ResponderRepository();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await _repository.resolveWithReport(
        widget.alertId,
        _notesController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = 'Could not submit. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write Report')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Log a short note before closing this alert.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'What happened / outcome',
                  hintText: 'e.g. Responded on scene, student confirmed safe…',
                  alignLabelWithHint: true,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _resolve,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Resolve & Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
