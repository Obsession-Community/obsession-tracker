import 'package:flutter/material.dart';

import 'package:obsession_tracker/core/models/imported_route.dart';
import 'package:obsession_tracker/core/services/route_import_service.dart';

/// Dialog for importing GPX/KML route files
class RouteImportDialog extends StatefulWidget {
  const RouteImportDialog({super.key});

  @override
  State<RouteImportDialog> createState() => _RouteImportDialogState();
}

class _RouteImportDialogState extends State<RouteImportDialog> {
  final RouteImportService _routeImportService = RouteImportService();
  bool _isImporting = false;
  ImportedRoute? _previewRoute;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Route'),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return _buildError();
    }

    if (_previewRoute != null) {
      return _buildPreview();
    }

    if (_isImporting) {
      return _buildImporting();
    }

    return _buildInitial();
  }

  Widget _buildInitial() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.file_download,
          size: 64,
          color: Colors.blue,
        ),
        const SizedBox(height: 16),
        const Text(
          'Select a GPX or KML file to import',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Supported formats: GPX, KML\nMax file size: 10MB',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose File'),
          ),
        ),
      ],
    );
  }

  Widget _buildImporting() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Importing route...'),
      ],
    );
  }

  Widget _buildPreview() {
    final route = _previewRoute!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Route Preview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Name', route.name),
        if (route.description != null)
          _buildInfoRow('Description', route.description!),
        _buildInfoRow('Format', route.sourceFormat.toUpperCase()),
        _buildInfoRow('Distance',
            '${(route.totalDistance / 1000).toStringAsFixed(2)} km'),
        _buildInfoRow('Points', '${route.points.length}'),
        _buildInfoRow('Waypoints', '${route.waypoints.length}'),
        if (route.estimatedDuration != null)
          _buildInfoRow('Est. Time', _formatDuration(route.estimatedDuration!)),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline,
          size: 64,
          color: Colors.red,
        ),
        const SizedBox(height: 16),
        Text(
          'Import Failed',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red[700],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    if (_error != null) {
      return [
        TextButton(
          onPressed: _reset,
          child: const Text('Try Again'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ];
    }

    if (_previewRoute != null) {
      return [
        TextButton(
          onPressed: _reset,
          child: const Text('Change File'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_previewRoute),
          child: const Text('Import'),
        ),
      ];
    }

    if (_isImporting) {
      return [
        const TextButton(
          onPressed: null,
          child: Text('Cancel'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ];
  }

  Future<void> _pickFile() async {
    setState(() {
      _isImporting = true;
      _error = null;
    });

    try {
      final route = await _routeImportService.pickAndImportFile();
      if (route != null) {
        setState(() {
          _previewRoute = route;
          _isImporting = false;
        });
      } else {
        // User cancelled
        setState(() {
          _isImporting = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isImporting = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _previewRoute = null;
      _error = null;
      _isImporting = false;
    });
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  /// Static method to show the dialog
  // Public API for showing dialog - may be used by external callers
  // ignore: unused_element
  static Future<ImportedRoute?> show(BuildContext context) {
    return showDialog<ImportedRoute>(
      context: context,
      builder: (context) => const RouteImportDialog(),
    );
  }
}
