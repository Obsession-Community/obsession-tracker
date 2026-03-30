import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/quadrangle_manifest.dart';
import 'package:obsession_tracker/core/services/quadrangle_download_service.dart';

/// Page for browsing and downloading historical map quadrangles for a specific state.
///
/// Shows available eras (Survey Era, Early Topos, etc.) with their quadrangles.
/// Allows selective download/deletion of individual quadrangles.
class HistoricalMapLayersPage extends ConsumerStatefulWidget {
  const HistoricalMapLayersPage({
    super.key,
    required this.stateCode,
    required this.stateName,
  });

  final String stateCode;
  final String stateName;

  @override
  ConsumerState<HistoricalMapLayersPage> createState() =>
      _HistoricalMapLayersPageState();
}

class _HistoricalMapLayersPageState
    extends ConsumerState<HistoricalMapLayersPage> {
  final QuadrangleDownloadService _downloadService =
      QuadrangleDownloadService.instance;

  bool _isLoading = true;
  StateQuadrangleManifest? _manifest;
  QuadrangleDownloadSummary? _summary;
  String? _errorMessage;

  // Download state
  String? _downloadingQuadId;
  double _downloadProgress = 0.0;

  // Selection state for batch download
  final Set<String> _selectedQuads = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _downloadService.initialize();

      final (manifest, summary) = await (
        _downloadService.getQuadrangleManifest(widget.stateCode),
        _downloadService.getDownloadSummary(widget.stateCode),
      ).wait;

      _manifest = manifest;
      _summary = summary;

      if (_manifest == null && _summary?.totalAvailableQuads == 0) {
        _errorMessage = 'No historical map quadrangles available for ${widget.stateName}';
      }
    } catch (e) {
      _errorMessage = 'Error loading data: $e';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool _isQuadDownloaded(String eraId, String quadId) {
    return _downloadService.isQuadrangleDownloaded(
      widget.stateCode,
      eraId,
      quadId,
    );
  }

  Future<void> _downloadQuad(HistoricalEra era, QuadrangleManifest quad) async {
    setState(() {
      _downloadingQuadId = quad.id;
      _downloadProgress = 0.0;
    });

    final result = await _downloadService.downloadQuadrangle(
      stateCode: widget.stateCode,
      eraId: era.id,
      quad: quad,
      onProgress: (received, total) {
        if (mounted && total > 0) {
          setState(() => _downloadProgress = received / total);
        }
      },
    );

    if (!mounted) return;

    setState(() => _downloadingQuadId = null);

    switch (result) {
      case QuadrangleDownloadSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${quad.name}'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData(); // Refresh to show updated status
      case QuadrangleDownloadError(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $message'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _deleteQuad(String eraId, QuadrangleManifest quad) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quadrangle'),
        content: Text(
          'Delete ${quad.name} (${quad.formattedSize})?\n\n'
          'You can re-download it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _downloadService.deleteQuadrangle(
        widget.stateCode,
        eraId,
        quad.id,
      );
      await _loadData();
    }
  }

  void _toggleSelection(String eraId, String quadId) {
    final key = '${eraId}_$quadId';
    setState(() {
      if (_selectedQuads.contains(key)) {
        _selectedQuads.remove(key);
      } else {
        _selectedQuads.add(key);
      }
    });
  }

  Future<void> _downloadSelected() async {
    if (_selectedQuads.isEmpty || _manifest == null) return;

    final quadsToDownload = <(HistoricalEra, QuadrangleManifest)>[];

    for (final era in _manifest!.eras) {
      for (final quad in era.quadrangles) {
        final key = '${era.id}_${quad.id}';
        if (_selectedQuads.contains(key) && !_isQuadDownloaded(era.id, quad.id)) {
          quadsToDownload.add((era, quad));
        }
      }
    }

    if (quadsToDownload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected quadrangles are already downloaded')),
      );
      return;
    }

    setState(() => _isSelectionMode = false);
    _selectedQuads.clear();

    for (final (era, quad) in quadsToDownload) {
      if (!mounted) break;
      await _downloadQuad(era, quad);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Historical Maps - ${widget.stateName}'),
        actions: [
          if (_manifest != null && _manifest!.eras.isNotEmpty)
            IconButton(
              icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
              onPressed: () {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  if (!_isSelectionMode) _selectedQuads.clear();
                });
              },
              tooltip: _isSelectionMode ? 'Cancel Selection' : 'Select Multiple',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(theme),
      bottomNavigationBar: _isSelectionMode && _selectedQuads.isNotEmpty
          ? _buildSelectionBar(theme)
          : null,
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(theme),
          const SizedBox(height: 16),
          if (_manifest != null)
            ...(_manifest!.eras.map((era) => _buildEraSection(theme, era)).toList()),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    if (_summary == null) return const SizedBox.shrink();

    final downloaded = _summary!.downloadedQuads;
    final total = _summary!.totalAvailableQuads;
    final downloadedSize = _summary!.downloadedSize;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text(
                  'Download Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: total > 0 ? downloaded / total : 0,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(Colors.purple[400]),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$downloaded of $total quadrangles',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  _formatSize(downloadedSize),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEraSection(ThemeData theme, HistoricalEra era) {
    final downloadedForEra = _downloadService
        .getDownloadedQuadranglesForEra(widget.stateCode, era.id);
    final downloadedCount = downloadedForEra.length;
    final totalCount = era.quadrangleCount;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.map, color: Colors.purple[700]),
        ),
        title: Text(
          era.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              era.yearRange,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.purple[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: totalCount > 0 ? downloadedCount / totalCount : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(Colors.purple[400]),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$downloadedCount/$totalCount',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              era.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          const Divider(),
          ...era.quadrangles.map((quad) => _buildQuadTile(theme, era, quad)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildQuadTile(
    ThemeData theme,
    HistoricalEra era,
    QuadrangleManifest quad,
  ) {
    final isDownloaded = _isQuadDownloaded(era.id, quad.id);
    final isDownloading = _downloadingQuadId == quad.id;
    final selectionKey = '${era.id}_${quad.id}';
    final isSelected = _selectedQuads.contains(selectionKey);

    return ListTile(
      leading: _isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: isDownloaded
                  ? null
                  : (_) => _toggleSelection(era.id, quad.id),
              activeColor: Colors.purple,
            )
          : Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDownloaded
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isDownloaded ? Icons.check_circle : Icons.map_outlined,
                color: isDownloaded ? Colors.green : Colors.grey,
                size: 20,
              ),
            ),
      title: Text(
        quad.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isDownloaded ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Row(
        children: [
          Text(
            quad.yearDisplay,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.purple[600],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            quad.formattedSize,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      trailing: isDownloading
          ? SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: _downloadProgress,
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Colors.purple[400]),
              ),
            )
          : isDownloaded
              ? IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  onPressed: () => _deleteQuad(era.id, quad),
                  tooltip: 'Delete',
                )
              : IconButton(
                  icon: const Icon(Icons.download),
                  color: Colors.purple,
                  onPressed: () => _downloadQuad(era, quad),
                  tooltip: 'Download',
                ),
      onTap: _isSelectionMode && !isDownloaded
          ? () => _toggleSelection(era.id, quad.id)
          : null,
    );
  }

  Widget _buildSelectionBar(ThemeData theme) {
    final notDownloadedCount = _selectedQuads.where((key) {
      final parts = key.split('_');
      if (parts.length != 2) return false;
      return !_isQuadDownloaded(parts[0], parts[1]);
    }).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              '${_selectedQuads.length} selected',
              style: theme.textTheme.bodyMedium,
            ),
            if (notDownloadedCount < _selectedQuads.length)
              Text(
                ' ($notDownloadedCount to download)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: notDownloadedCount > 0 ? _downloadSelected : null,
              icon: const Icon(Icons.download),
              label: const Text('Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
