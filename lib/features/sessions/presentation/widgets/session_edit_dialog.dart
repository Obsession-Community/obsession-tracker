import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/providers/hunt_provider.dart';
import 'package:obsession_tracker/core/providers/session_provider.dart';
import 'package:obsession_tracker/features/tracking/presentation/widgets/hunt_selection_modal.dart';

/// Dialog for editing session details
class SessionEditDialog extends ConsumerStatefulWidget {
  const SessionEditDialog({
    required this.session,
    super.key,
  });

  final TrackingSession session;

  @override
  ConsumerState<SessionEditDialog> createState() => _SessionEditDialogState();
}

class _SessionEditDialogState extends ConsumerState<SessionEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _selectedHuntId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.session.name);
    _descriptionController =
        TextEditingController(text: widget.session.description ?? '');
    _selectedHuntId = widget.session.huntId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final huntsAsync = ref.watch(huntProvider);
    final hasHunts = huntsAsync.maybeWhen(
      data: (hunts) => hunts.isNotEmpty,
      orElse: () => false,
    );

    // Get the selected hunt object for display
    final selectedHunt = _selectedHuntId != null
        ? ref.watch(huntByIdProvider(_selectedHuntId!))
        : null;

    return AlertDialog(
      title: const Text('Edit Session'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Session Name',
                  hintText: 'Enter session name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Session name is required';
                  }
                  if (value.trim().length < 2) {
                    return 'Session name must be at least 2 characters';
                  }
                  if (value.trim().length > 50) {
                    return 'Session name must be less than 50 characters';
                  }
                  return null;
                },
                enabled: !_isLoading,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Enter session description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value != null && value.trim().length > 200) {
                    return 'Description must be less than 200 characters';
                  }
                  return null;
                },
                enabled: !_isLoading,
                textCapitalization: TextCapitalization.sentences,
              ),
              // Hunt selection (only if hunts exist)
              if (hasHunts) ...[
                const SizedBox(height: 16),
                const Text(
                  'Associated Hunt',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _isLoading ? null : _selectHunt,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedHunt != null ? Icons.search : Icons.add,
                          color: selectedHunt != null
                              ? Theme.of(context).colorScheme.secondary
                              : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedHunt?.name ?? 'No hunt selected',
                                style: TextStyle(
                                  fontWeight: selectedHunt != null
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                  color: selectedHunt != null
                                      ? null
                                      : Colors.grey,
                                ),
                              ),
                              if (selectedHunt != null) ...[
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getHuntStatusColor(selectedHunt.status)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    selectedHunt.status.displayName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: _getHuntStatusColor(selectedHunt.status),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (selectedHunt != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _selectedHuntId = null;
                                    });
                                  },
                            tooltip: 'Remove hunt',
                          )
                        else
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _selectHunt() async {
    final selectedHunt = await showModalBottomSheet<TreasureHunt>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HuntSelectionModal(
        currentHuntId: _selectedHuntId,
      ),
    );

    if (mounted) {
      setState(() {
        _selectedHuntId = selectedHunt?.id;
      });
    }
  }

  Color _getHuntStatusColor(HuntStatus status) {
    switch (status) {
      case HuntStatus.active:
        return Colors.green;
      case HuntStatus.paused:
        return Colors.orange;
      case HuntStatus.solved:
        return Colors.amber;
      case HuntStatus.abandoned:
        return Colors.grey;
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create updated session with hunt assignment
      // Use clearHuntId when removing hunt, huntId when setting one
      final descriptionText = _descriptionController.text.trim();
      final updatedSession = widget.session.copyWith(
        name: _nameController.text.trim(),
        description: descriptionText.isEmpty ? null : descriptionText,
        clearDescription: descriptionText.isEmpty,
        huntId: _selectedHuntId,
        clearHuntId: _selectedHuntId == null,
      );

      // Save changes
      final success = await ref
          .read(sessionProvider.notifier)
          .updateSession(updatedSession);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update session. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
