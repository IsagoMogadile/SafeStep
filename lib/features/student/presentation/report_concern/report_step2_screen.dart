import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../../core/storage/storage_uploader.dart';
import '../../../../core/supabase/supabase_service.dart';
import 'report_success_screen.dart';

class ReportStep2Screen extends StatefulWidget {
  const ReportStep2Screen({
    super.key,
    required this.category,
    required this.locationText,
    required this.lat,
    required this.lng,
    required this.description,
    required this.anonymous,
    required this.followUpRequested,
    this.photo,
  });

  final String category;
  final String locationText;
  final double? lat;
  final double? lng;
  final String description;
  final bool anonymous;
  final bool followUpRequested;
  final File? photo;

  @override
  State<ReportStep2Screen> createState() => _ReportStep2ScreenState();
}

class _ReportStep2ScreenState extends State<ReportStep2Screen> {
  final _uploader = StorageUploader();
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final userId = SupabaseService.client.auth.currentUser!.id;

      String? photoUrl;
      if (widget.photo != null) {
        photoUrl = await _uploader.uploadImage(
          bucket: 'incident-photos',
          userId: userId,
          file: widget.photo!,
          filename: 'report_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      await SupabaseService.client.from('incident_reports').insert({
        'student_id': userId,
        'is_anonymous': widget.anonymous,
        'category': widget.category,
        'location_text': widget.locationText,
        'lat': widget.lat,
        'lng': widget.lng,
        'description': widget.description,
        'photo_url': photoUrl,
        'follow_up_requested': widget.followUpRequested,
        'status': 'new',
      });
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ReportSuccessScreen()),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Could not submit. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a Concern')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Review and send',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (widget.photo != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    widget.photo!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              if (widget.photo != null) const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ReviewRow(label: 'Category', value: widget.category),
                      _ReviewRow(label: 'Location', value: widget.locationText),
                      _ReviewRow(
                        label: 'Anonymous',
                        value: widget.anonymous ? 'Yes' : 'No',
                      ),
                      _ReviewRow(
                        label: 'Follow-up',
                        value: widget.followUpRequested ? 'Requested' : 'Not requested',
                      ),
                      _ReviewRow(
                        label: 'Description',
                        value: widget.description,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your report can help improve campus safety. Thank you for '
                'speaking up.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Share This Concern'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
