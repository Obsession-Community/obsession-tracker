import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/mapbox_config.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/providers/hunt_provider.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/features/hunts/presentation/pages/document_viewer_page.dart';
import 'package:obsession_tracker/features/hunts/presentation/widgets/add_link_dialog.dart';
import 'package:obsession_tracker/features/hunts/presentation/widgets/add_note_dialog.dart';
import 'package:obsession_tracker/features/hunts/presentation/widgets/location_map_picker.dart';
import 'package:obsession_tracker/features/hunts/presentation/widgets/locations_map_view.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/mapbox_map_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Detailed view of a treasure hunt with document management.
///
/// Displays all documents, notes, links, locations, and linked sessions
/// for a specific treasure hunt.
class HuntDetailPage extends ConsumerStatefulWidget {
  const HuntDetailPage({
    super.key,
    required this.huntId,
  });

  final String huntId;

  @override
  ConsumerState<HuntDetailPage> createState() => _HuntDetailPageState();
}

class _HuntDetailPageState extends ConsumerState<HuntDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showLocationsMapView = false; // Toggle between list and map view
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentTabIndex = _tabController.index;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  // Disable scrolling when map view is active to allow map gestures
  bool get _isMapViewActive => _currentTabIndex == 1 && _showLocationsMapView;

  @override
  Widget build(BuildContext context) {
    final hunt = ref.watch(huntByIdProvider(widget.huntId));
    final documentsAsync = ref.watch(huntDocumentProvider(widget.huntId));
    final locationsAsync = ref.watch(huntLocationProvider(widget.huntId));

    if (hunt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hunt Not Found')),
        body: const Center(child: Text('This hunt could not be found.')),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        // Key forces rebuild when map view state changes (physics don't update in place)
        key: ValueKey('nested_scroll_map_$_isMapViewActive'),
        // Disable scrolling when map view is active to allow map gestures
        physics: _isMapViewActive
            ? const NeverScrollableScrollPhysics()
            : null,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(hunt),
        ],
        body: Column(
          children: [
            // Tab bar
            ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.gold,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.gold,
                tabs: const [
                  Tab(icon: Icon(Icons.folder), text: 'Documents'),
                  Tab(icon: Icon(Icons.place), text: 'Locations'),
                  Tab(icon: Icon(Icons.info_outline), text: 'Info'),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                key: ValueKey('tab_bar_view_map_$_isMapViewActive'),
                controller: _tabController,
                // Disable tab swiping when map view is active to allow map panning
                physics: _isMapViewActive
                    ? const NeverScrollableScrollPhysics()
                    : null,
                children: [
                  _buildDocumentsTab(documentsAsync),
                  _buildLocationsTab(locationsAsync),
                  _buildInfoTab(hunt),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildSliverAppBar(TreasureHunt hunt) {
    Widget? background;

    if (hunt.coverImagePath != null) {
      final file = File(hunt.coverImagePath!);
      if (file.existsSync()) {
        background = Image.file(
          file,
          fit: BoxFit.cover,
        );
      }
    }

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          hunt.name,
          style: const TextStyle(
            shadows: [
              Shadow(color: Colors.black54, blurRadius: 4),
            ],
          ),
        ),
        background: background ??
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.gold.withValues(alpha: 0.3),
                    Colors.black87,
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.search,
                  size: 80,
                  color: AppTheme.gold.withValues(alpha: 0.3),
                ),
              ),
            ),
      ),
      actions: [
        // Status badge
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Color(hunt.status.color).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hunt.status.icon,
                style: TextStyle(
                  color: Color(hunt.status.color),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                hunt.status.displayName,
                style: TextStyle(
                  color: Color(hunt.status.color),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsTab(AsyncValue<List<HuntDocument>> documentsAsync) {
    return documentsAsync.when(
      data: (documents) {
        if (documents.isEmpty) {
          return _buildEmptyDocuments();
        }

        // Group by type
        final images = documents.where((d) => d.type == HuntDocumentType.image).toList();
        final pdfs = documents.where((d) => d.type == HuntDocumentType.pdf).toList();
        final docs = documents.where((d) => d.type == HuntDocumentType.document).toList();
        final notes = documents.where((d) => d.type == HuntDocumentType.note).toList();
        final links = documents.where((d) => d.type == HuntDocumentType.link).toList();

        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (images.isNotEmpty) ...[
              _buildDocumentSectionHeader('Images', HuntDocumentType.image, images.length),
              _buildImageGrid(images),
            ],
            if (pdfs.isNotEmpty) ...[
              _buildDocumentSectionHeader('PDFs', HuntDocumentType.pdf, pdfs.length),
              ...pdfs.map(_buildPdfTile),
            ],
            if (docs.isNotEmpty) ...[
              _buildDocumentSectionHeader('Documents', HuntDocumentType.document, docs.length),
              ...docs.map(_buildGenericDocumentTile),
            ],
            if (notes.isNotEmpty) ...[
              _buildDocumentSectionHeader('Notes', HuntDocumentType.note, notes.length),
              ...notes.map(_buildNoteTile),
            ],
            if (links.isNotEmpty) ...[
              _buildDocumentSectionHeader('Links', HuntDocumentType.link, links.length),
              ...links.map(_buildLinkTile),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildEmptyDocuments() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: AppTheme.gold.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Documents Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add images, PDFs, notes, and links\nto organize your research',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSectionHeader(String title, HuntDocumentType type, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(type.icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(List<HuntDocument> images) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final doc = images[index];
          return _buildImageThumbnail(doc);
        },
      ),
    );
  }

  Widget _buildImageThumbnail(HuntDocument doc) {
    Widget image = Container(
      color: Colors.grey[300],
      child: const Icon(Icons.image, color: Colors.grey),
    );

    // Debug logging to diagnose photo display issues
    debugPrint('🖼️ HuntDocument "${doc.name}":');
    debugPrint('   thumbnailPath: ${doc.thumbnailPath}');
    debugPrint('   filePath: ${doc.filePath}');

    if (doc.thumbnailPath != null) {
      final file = File(doc.thumbnailPath!);
      final exists = file.existsSync();
      debugPrint('   thumbnail exists: $exists');
      if (exists) {
        image = Image.file(file, fit: BoxFit.cover);
      }
    } else if (doc.filePath != null) {
      final file = File(doc.filePath!);
      final exists = file.existsSync();
      debugPrint('   file exists: $exists');
      if (exists) {
        image = Image.file(file, fit: BoxFit.cover);
      }
    }

    return GestureDetector(
      onTap: () => _viewImage(doc),
      onLongPress: () => _showDocumentOptions(doc),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: image,
      ),
    );
  }

  Widget _buildPdfTile(HuntDocument doc) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.picture_as_pdf, color: Colors.red),
      ),
      title: Text(doc.name),
      subtitle: Text(
        DateFormat.yMMMd().format(doc.createdAt),
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openPdf(doc),
      onLongPress: () => _showDocumentOptions(doc),
    );
  }

  Widget _buildGenericDocumentTile(HuntDocument doc) {
    // Get file extension for icon selection
    final extension = doc.filePath != null
        ? doc.filePath!.split('.').last.toLowerCase()
        : '';

    IconData iconData;
    Color iconColor;

    // Choose icon based on file extension
    switch (extension) {
      case 'doc':
      case 'docx':
        iconData = Icons.description;
        iconColor = Colors.blue;
        break;
      case 'xls':
      case 'xlsx':
      case 'csv':
      case 'tsv':
      case 'numbers':
        iconData = Icons.table_chart;
        iconColor = Colors.green;
        break;
      case 'ppt':
      case 'pptx':
      case 'key':
        iconData = Icons.slideshow;
        iconColor = Colors.orange;
        break;
      case 'txt':
      case 'rtf':
      case 'md':
      case 'markdown':
        iconData = Icons.article;
        iconColor = Colors.grey;
        break;
      case 'gpx':
      case 'kml':
      case 'kmz':
        iconData = Icons.map;
        iconColor = Colors.purple;
        break;
      case 'json':
      case 'xml':
      case 'html':
      case 'htm':
        iconData = Icons.code;
        iconColor = Colors.teal;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.teal;
    }

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(iconData, color: iconColor),
      ),
      title: Text(doc.name),
      subtitle: Text(
        '${extension.toUpperCase()} • ${DateFormat.yMMMd().format(doc.createdAt)}',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openDocument(doc),
      onLongPress: () => _showDocumentOptions(doc),
    );
  }

  Widget _buildNoteTile(HuntDocument doc) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.note, color: AppTheme.gold),
        ),
        title: Text(doc.name),
        subtitle: Text(
          doc.content?.substring(0, doc.content!.length.clamp(0, 100)) ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _viewNote(doc),
        onLongPress: () => _showDocumentOptions(doc),
      ),
    );
  }

  Widget _buildLinkTile(HuntDocument doc) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.link, color: Colors.blue),
      ),
      title: Text(doc.name),
      subtitle: Text(
        doc.url ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => _openLink(doc),
      onLongPress: () => _showDocumentOptions(doc),
    );
  }

  Widget _buildLocationsTab(AsyncValue<List<HuntLocation>> locationsAsync) {
    return locationsAsync.when(
      data: (locations) {
        if (locations.isEmpty) {
          return _buildEmptyLocations();
        }

        return Column(
          children: [
            // View toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.list, size: 18),
                          label: Text('List'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.map, size: 18),
                          label: Text('Map'),
                        ),
                      ],
                      selected: {_showLocationsMapView},
                      onSelectionChanged: (values) {
                        setState(() {
                          _showLocationsMapView = values.first;
                        });
                      },
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _showLocationsMapView
                  ? LocationsMapView(
                      locations: locations,
                      onLocationTap: _showLocationDetails,
                    )
                  : _buildLocationsListView(locations),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildLocationsListView(List<HuntLocation> locations) {
    // Group by status
    final potential = locations.where((l) => l.status == HuntLocationStatus.potential).toList();
    final searched = locations.where((l) => l.status == HuntLocationStatus.searched).toList();
    final eliminated = locations.where((l) => l.status == HuntLocationStatus.eliminated).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        if (potential.isNotEmpty) ...[
          _buildLocationSectionHeader('Potential Spots', Icons.place, AppTheme.gold, potential.length),
          ...potential.map(_buildLocationTile),
        ],
        if (searched.isNotEmpty) ...[
          _buildLocationSectionHeader('Searched', Icons.check_circle, Colors.green, searched.length),
          ...searched.map(_buildLocationTile),
        ],
        if (eliminated.isNotEmpty) ...[
          _buildLocationSectionHeader('Eliminated', Icons.cancel, Colors.grey, eliminated.length),
          ...eliminated.map(_buildLocationTile),
        ],
      ],
    );
  }

  void _showLocationDetails(HuntLocation location) {
    showModalBottomSheet<String>(
      context: context,
      builder: (context) => _LocationDetailsSheet(
        location: location,
        onAction: (action) {
          Navigator.pop(context);
          _handleLocationAction(action, location);
        },
      ),
    );
  }

  Widget _buildEmptyLocations() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.place_outlined,
              size: 64,
              color: AppTheme.gold.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Locations Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mark potential solve spots and\ntrack your search progress',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addLocation,
              icon: const Icon(Icons.add_location),
              label: const Text('Add Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSectionHeader(String title, IconData icon, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile(HuntLocation location) {
    Color statusColor;
    IconData statusIcon;

    switch (location.status) {
      case HuntLocationStatus.searched:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      case HuntLocationStatus.eliminated:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
      case HuntLocationStatus.potential:
        statusColor = AppTheme.gold;
        statusIcon = Icons.place;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(location.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (location.notes != null && location.notes!.isNotEmpty)
              Text(
                location.notes!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleLocationAction(value, location),
          itemBuilder: (context) => [
            if (location.status != HuntLocationStatus.searched)
              const PopupMenuItem(
                value: 'searched',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('Mark Searched'),
                  ],
                ),
              ),
            if (location.status != HuntLocationStatus.eliminated)
              const PopupMenuItem(
                value: 'eliminated',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Text('Mark Eliminated'),
                  ],
                ),
              ),
            if (location.status != HuntLocationStatus.potential)
              const PopupMenuItem(
                value: 'potential',
                child: Row(
                  children: [
                    Icon(Icons.place, color: AppTheme.gold, size: 20),
                    SizedBox(width: 8),
                    Text('Mark Potential'),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'view_on_map',
              child: Row(
                children: [
                  Icon(Icons.map, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text('View on Map'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab(TreasureHunt hunt) {
    final summary = ref.watch(huntSummaryProvider(hunt.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hunt info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hunt.author != null) ...[
                  Text(
                    'Author',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    hunt.author!,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                ],
                if (hunt.description != null) ...[
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    hunt.description!,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Created',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  DateFormat.yMMMMd().format(hunt.createdAt),
                  style: const TextStyle(fontSize: 14),
                ),
                if (hunt.completedAt != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    DateFormat.yMMMMd().format(hunt.completedAt!),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Summary stats
        summary.when(
          data: (s) => s != null ? _buildSummaryCard(s) : const SizedBox.shrink(),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        // Tags
        if (hunt.tags.isNotEmpty) ...[
          Text(
            'Tags',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hunt.tags.map((tag) {
              return Chip(
                label: Text(tag),
                backgroundColor: AppTheme.gold.withValues(alpha: 0.15),
                labelStyle: const TextStyle(color: AppTheme.gold),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryCard(HuntSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hunt Statistics',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Documents', '${summary.documentCount}'),
                _buildStatColumn('Notes', '${summary.noteCount}'),
                _buildStatColumn('Links', '${summary.linkCount}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Locations', '${summary.locationCount}'),
                _buildStatColumn('Sessions', '${summary.sessionCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.gold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _showAddOptions,
      backgroundColor: AppTheme.gold,
      foregroundColor: Colors.black,
      child: const Icon(Icons.add),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.green),
              title: const Text('Add Image'),
              onTap: () {
                Navigator.pop(context);
                _addImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Add PDF'),
              onTap: () {
                Navigator.pop(context);
                _addPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.teal),
              title: const Text('Add Document'),
              subtitle: const Text('txt, doc, csv, and more'),
              onTap: () {
                Navigator.pop(context);
                _addDocument();
              },
            ),
            ListTile(
              leading: const Icon(Icons.note, color: AppTheme.gold),
              title: const Text('Add Note'),
              onTap: () {
                Navigator.pop(context);
                _addNote();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.blue),
              title: const Text('Add Link'),
              onTap: () {
                Navigator.pop(context);
                _addLink();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_location, color: Colors.purple),
              title: const Text('Add Location'),
              subtitle: const Text('Mark a potential solve spot'),
              onTap: () {
                Navigator.pop(context);
                _addLocation();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      final name = await _promptForName('Image Name',
        defaultValue: result.files.single.name.split('.').first);
      if (name != null && name.isNotEmpty) {
        await ref.read(huntDocumentNotifierProvider.notifier).addImage(
              huntId: widget.huntId,
              name: name,
              imageFile: File(result.files.single.path!),
            );
        // Invalidate the document provider to refresh the list
        ref.invalidate(huntDocumentProvider(widget.huntId));
      }
    }
  }

  Future<void> _addPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final name = await _promptForName('PDF Name',
        defaultValue: result.files.single.name.replaceAll('.pdf', ''));
      if (name != null && name.isNotEmpty) {
        await ref.read(huntDocumentNotifierProvider.notifier).addPdf(
              huntId: widget.huntId,
              name: name,
              pdfFile: File(result.files.single.path!),
            );
        // Invalidate the document provider to refresh the list
        ref.invalidate(huntDocumentProvider(widget.huntId));
      }
    }
  }

  Future<void> _addDocument() async {
    // Allow a wide range of document types
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        // Text files
        'txt', 'rtf', 'md', 'markdown',
        // Microsoft Office
        'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
        // Spreadsheets
        'csv', 'tsv',
        // Other common formats
        'odt', 'ods', 'odp', // OpenDocument
        'pages', 'numbers', 'key', // Apple iWork
        'json', 'xml', 'html', 'htm',
        'gpx', 'kml', 'kmz', // Geo files
      ],
    );

    if (result != null && result.files.single.path != null) {
      final fileName = result.files.single.name;
      // Remove extension for default name
      final extension = fileName.contains('.')
          ? '.${fileName.split('.').last}'
          : '';
      final defaultName = fileName.replaceAll(extension, '');

      final name = await _promptForName('Document Name',
        defaultValue: defaultName);
      if (name != null && name.isNotEmpty) {
        await ref.read(huntDocumentNotifierProvider.notifier).addDocument(
              huntId: widget.huntId,
              name: name,
              documentFile: File(result.files.single.path!),
            );
        // Invalidate providers to refresh lists and summary
        ref.invalidate(huntDocumentProvider(widget.huntId));
        ref.invalidate(huntSummaryProvider(widget.huntId));
      }
    }
  }

  Future<void> _addNote() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const AddNoteDialog(),
    );

    if (result != null) {
      await ref.read(huntDocumentNotifierProvider.notifier).addNote(
            huntId: widget.huntId,
            name: result['name']!,
            content: result['content']!,
          );
      // Invalidate providers to refresh lists and summary
      ref.invalidate(huntDocumentProvider(widget.huntId));
      ref.invalidate(huntSummaryProvider(widget.huntId));
    }
  }

  Future<void> _addLink() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const AddLinkDialog(),
    );

    if (result != null) {
      await ref.read(huntDocumentNotifierProvider.notifier).addLink(
            huntId: widget.huntId,
            name: result['name']!,
            url: result['url']!,
          );
      // Invalidate providers to refresh lists and summary
      ref.invalidate(huntDocumentProvider(widget.huntId));
      ref.invalidate(huntSummaryProvider(widget.huntId));
    }
  }

  Future<String?> _promptForName(String label, {String? defaultValue}) async {
    final controller = TextEditingController(text: defaultValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter a name...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _viewImage(HuntDocument doc) {
    if (doc.filePath == null) return;

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(doc.name)),
          body: InteractiveViewer(
            child: Center(
              child: Image.file(File(doc.filePath!)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPdf(HuntDocument doc) async {
    if (doc.filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found')),
      );
      return;
    }

    final file = File(doc.filePath!);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File no longer exists')),
        );
      }
      return;
    }

    // Open PDF in in-app viewer
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => DocumentViewerPage(
          title: doc.name,
          filePath: doc.filePath!,
        ),
      ),
    );
  }

  Future<void> _openDocument(HuntDocument doc) async {
    if (doc.filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found')),
      );
      return;
    }

    final file = File(doc.filePath!);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File no longer exists')),
        );
      }
      return;
    }

    // Get file extension to determine how to open
    final extension = doc.filePath!.split('.').last.toLowerCase();

    // List of file types supported by in-app viewer
    const supportedTextExtensions = [
      'txt', 'rtf', 'md', 'markdown',
      'json', 'xml', 'html', 'htm',
      'csv', 'tsv',
      'gpx', 'kml',
      'log', 'ini', 'cfg', 'conf',
      'yaml', 'yml',
    ];

    if (supportedTextExtensions.contains(extension)) {
      // Open in in-app viewer for supported text files
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => DocumentViewerPage(
            title: doc.name,
            filePath: doc.filePath!,
          ),
        ),
      );
    } else {
      // For unsupported formats (docx, xlsx, pptx, etc.), use share sheet
      // since they require specialized apps to render properly
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(doc.filePath!)],
          subject: doc.name,
        ),
      );
    }
  }

  void _viewNote(HuntDocument doc) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doc.name),
        content: SingleChildScrollView(
          child: Text(doc.content ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(HuntDocument doc) async {
    if (doc.url == null) return;

    final uri = Uri.tryParse(doc.url!);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showDocumentOptions(HuntDocument doc) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteDocument(doc);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDocument(HuntDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to delete "${doc.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(huntDocumentNotifierProvider.notifier)
          .deleteDocument(doc.id, widget.huntId);
      ref.invalidate(huntDocumentProvider(widget.huntId));
      ref.invalidate(huntSummaryProvider(widget.huntId));
    }
  }

  // ==================== Location Methods ====================

  Future<void> _addLocation() async {
    // Show dialog to get location details
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddLocationDialog(),
    );

    if (result != null) {
      await ref.read(huntLocationNotifierProvider.notifier).addLocation(
            huntId: widget.huntId,
            name: result['name'] as String,
            latitude: result['latitude'] as double,
            longitude: result['longitude'] as double,
            notes: result['notes'] as String?,
          );
      ref.invalidate(huntLocationProvider(widget.huntId));
      ref.invalidate(huntSummaryProvider(widget.huntId));
    }
  }

  Future<void> _handleLocationAction(String action, HuntLocation location) async {
    switch (action) {
      case 'searched':
        await ref.read(huntLocationNotifierProvider.notifier)
            .markSearched(location.id, widget.huntId);
        ref.invalidate(huntLocationProvider(widget.huntId));
        ref.invalidate(huntSummaryProvider(widget.huntId));
      case 'eliminated':
        final updated = location.copyWith(status: HuntLocationStatus.eliminated);
        await ref.read(huntLocationNotifierProvider.notifier)
            .updateLocation(updated, widget.huntId);
        ref.invalidate(huntLocationProvider(widget.huntId));
        ref.invalidate(huntSummaryProvider(widget.huntId));
      case 'potential':
        final updated = location.copyWith(status: HuntLocationStatus.potential);
        await ref.read(huntLocationNotifierProvider.notifier)
            .updateLocation(updated, widget.huntId);
        ref.invalidate(huntLocationProvider(widget.huntId));
        ref.invalidate(huntSummaryProvider(widget.huntId));
      case 'view_on_map':
        _viewLocationOnMap(location);
      case 'delete':
        _confirmDeleteLocation(location);
    }
  }

  void _viewLocationOnMap(HuntLocation location) {
    // Navigate to map page with location coordinates
    // Pop back to home and switch to Map tab, passing location to center on
    Navigator.of(context).popUntil((route) => route.isFirst);

    // Use a post-frame callback to switch to map tab after navigation completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Find the AdaptiveHomePage and tell it to show the map at this location
      // For now, we'll use a simple approach - navigate to a dedicated location view
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => _SingleLocationMapPage(location: location),
        ),
      );
    });
  }

  Future<void> _confirmDeleteLocation(HuntLocation location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location?'),
        content: Text('Are you sure you want to delete "${location.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(huntLocationNotifierProvider.notifier)
          .deleteLocation(location.id, widget.huntId);
      ref.invalidate(huntLocationProvider(widget.huntId));
      ref.invalidate(huntSummaryProvider(widget.huntId));
    }
  }
}

/// Dialog for adding a new location with GPS or manual entry
class _AddLocationDialog extends StatefulWidget {
  @override
  State<_AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<_AddLocationDialog> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  bool _isLoadingGps = false;
  bool _hasGpsLocation = false;
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    // Add listeners to rebuild UI when text changes (for _canSave validation)
    _nameController.addListener(_onFieldChanged);
    _latController.addListener(_onFieldChanged);
    _lonController.addListener(_onFieldChanged);
    // Auto-fetch GPS on open
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _latController.removeListener(_onFieldChanged);
    _lonController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _notesController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    // Trigger rebuild to update Save button enabled state
    setState(() {});
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingGps = true;
      _gpsError = null;
    });

    try {
      // Check if location services are enabled
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _gpsError = 'Location services are disabled';
          _isLoadingGps = false;
        });
        return;
      }

      // Check permission
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          setState(() {
            _gpsError = 'Location permission denied';
            _isLoadingGps = false;
          });
          return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        setState(() {
          _gpsError = 'Location permission permanently denied';
          _isLoadingGps = false;
        });
        return;
      }

      // Get current position
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lonController.text = position.longitude.toStringAsFixed(6);
        _hasGpsLocation = true;
        _isLoadingGps = false;
      });
    } catch (e) {
      setState(() {
        _gpsError = 'Could not get location: $e';
        _isLoadingGps = false;
      });
    }
  }

  Future<void> _pickFromMap() async {
    // Parse current coordinates to pass as initial location
    final currentLat = double.tryParse(_latController.text);
    final currentLon = double.tryParse(_lonController.text);

    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (context) => LocationMapPicker(
          initialLatitude: currentLat,
          initialLongitude: currentLon,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latController.text = result.latitude.toStringAsFixed(6);
        _lonController.text = result.longitude.toStringAsFixed(6);
        _hasGpsLocation = true;
        // If a place name was returned and name field is empty, suggest it
        if (result.placeName != null && _nameController.text.isEmpty) {
          _nameController.text = result.placeName!;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Location'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'e.g., Old Oak Tree, Creek Crossing',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // GPS Status and Pick from Map
            Row(
              children: [
                // GPS button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingGps ? null : _getCurrentLocation,
                    icon: _isLoadingGps
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _hasGpsLocation ? Icons.gps_fixed : Icons.gps_not_fixed,
                            size: 18,
                            color: _hasGpsLocation ? Colors.green : null,
                          ),
                    label: Text(
                      _isLoadingGps
                          ? 'Getting...'
                          : _hasGpsLocation
                              ? 'GPS ✓'
                              : 'Use GPS',
                      style: TextStyle(
                        color: _hasGpsLocation ? Colors.green : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Pick from Map button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromMap,
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('Pick from Map'),
                  ),
                ),
              ],
            ),
            if (_gpsError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _gpsError!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red[400],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Coordinate fields
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: '44.123456',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lonController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: '-103.123456',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Why is this location interesting?',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canSave() ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: Colors.black,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  bool _canSave() {
    if (_nameController.text.trim().isEmpty) return false;
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    if (lat == null || lon == null) return false;
    if (lat < -90 || lat > 90) return false;
    if (lon < -180 || lon > 180) return false;
    return true;
  }

  void _save() {
    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'latitude': double.parse(_latController.text),
      'longitude': double.parse(_lonController.text),
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    });
  }
}

/// Simple map page showing a single hunt location
class _SingleLocationMapPage extends ConsumerStatefulWidget {
  const _SingleLocationMapPage({required this.location});

  final HuntLocation location;

  @override
  ConsumerState<_SingleLocationMapPage> createState() => _SingleLocationMapPageState();
}

class _SingleLocationMapPageState extends ConsumerState<_SingleLocationMapPage> {
  PointAnnotationManager? _annotationManager;

  Future<void> _onMapCreated(MapboxMap map) async {
    _annotationManager = await map.annotations.createPointAnnotationManager();

    // Add marker for the location
    Color markerColor;
    switch (widget.location.status) {
      case HuntLocationStatus.potential:
        markerColor = AppTheme.gold;
      case HuntLocationStatus.searched:
        markerColor = Colors.green;
      case HuntLocationStatus.eliminated:
        markerColor = Colors.grey;
    }

    await _annotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(widget.location.longitude, widget.location.latitude),
        ),
        iconSize: 1.5,
        iconColor: markerColor.toARGB32(),
        iconImage: 'marker-15',
        textField: widget.location.name,
        textSize: 14.0,
        textColor: Colors.white.toARGB32(),
        textHaloColor: Colors.black.toARGB32(),
        textHaloWidth: 1.5,
        textOffset: [0.0, 1.8],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location.name),
      ),
      body: Stack(
        children: [
          MapboxMapWidget(
            config: MapboxMapConfig(
              initialCenter: Point(
                coordinates: Position(
                  widget.location.longitude,
                  widget.location.latitude,
                ),
              ),
              initialZoom: 15.0,
              followUserLocation: false,
              showMapControls: false,
            ),
            onMapCreated: _onMapCreated,
          ),
          // Info panel at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.location.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.location.latitude.toStringAsFixed(6)}, ${widget.location.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      if (widget.location.notes != null &&
                          widget.location.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.location.notes!,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet showing location details with action buttons
class _LocationDetailsSheet extends StatelessWidget {
  const _LocationDetailsSheet({
    required this.location,
    required this.onAction,
  });

  final HuntLocation location;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (location.status) {
      case HuntLocationStatus.searched:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusLabel = 'Searched';
      case HuntLocationStatus.eliminated:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        statusLabel = 'Eliminated';
      case HuntLocationStatus.potential:
        statusColor = AppTheme.gold;
        statusIcon = Icons.place;
        statusLabel = 'Potential';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(statusIcon, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Coordinates
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: AppTheme.gold),
                const SizedBox(width: 8),
                Text(
                  '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),

          // Notes
          if (location.notes != null && location.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              location.notes!,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ],

          // Searched timestamp
          if (location.searchedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Searched: ${DateFormat.yMMMd().add_jm().format(location.searchedAt!)}',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 12,
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),

          // Actions
          Text(
            'Actions',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (location.status != HuntLocationStatus.searched)
                ActionChip(
                  avatar: const Icon(Icons.check, size: 18),
                  label: const Text('Mark Searched'),
                  onPressed: () => onAction('searched'),
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                ),
              if (location.status != HuntLocationStatus.eliminated)
                ActionChip(
                  avatar: const Icon(Icons.cancel, size: 18),
                  label: const Text('Eliminate'),
                  onPressed: () => onAction('eliminated'),
                  backgroundColor: Colors.grey.withValues(alpha: 0.1),
                ),
              if (location.status != HuntLocationStatus.potential)
                ActionChip(
                  avatar: const Icon(Icons.replay, size: 18),
                  label: const Text('Mark Potential'),
                  onPressed: () => onAction('potential'),
                  backgroundColor: AppTheme.gold.withValues(alpha: 0.1),
                ),
              ActionChip(
                avatar: const Icon(Icons.map, size: 18),
                label: const Text('View on Map'),
                onPressed: () => onAction('view_on_map'),
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
              ),
              ActionChip(
                avatar: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                onPressed: () => onAction('delete'),
                backgroundColor: Colors.red.withValues(alpha: 0.1),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
