import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/services/debug_land_data_service.dart';
import 'package:obsession_tracker/core/services/land_ownership_service.dart';
import 'package:obsession_tracker/core/services/nps_api_service.dart';
import 'package:obsession_tracker/core/services/pad_us_data_service.dart';
import 'package:obsession_tracker/core/services/pad_us_diagnostic_service.dart';
import 'package:obsession_tracker/core/services/test_land_data_service.dart';

/// Widget for managing land ownership data settings
class LandDataSettingsWidget extends ConsumerStatefulWidget {
  const LandDataSettingsWidget({super.key});

  @override
  ConsumerState<LandDataSettingsWidget> createState() =>
      _LandDataSettingsWidgetState();
}

class _LandDataSettingsWidgetState
    extends ConsumerState<LandDataSettingsWidget> {
  bool _isGeneratingData = false;
  bool _isDownloadingPadUs = false;
  bool _isRunningDiagnostic = false;
  bool _isRunningDebugAnalysis = false;
  bool _isTestingNpsApi = false;
  int? _recordCount;

  @override
  void initState() {
    super.initState();
    _loadRecordCount();
  }

  Future<void> _loadRecordCount() async {
    try {
      final service = LandOwnershipService.instance;
      await service.initialize();
      final count = await service.getLandOwnershipCount();
      if (mounted) {
        setState(() {
          _recordCount = count;
        });
      }
    } catch (e) {
      debugPrint('Error loading record count: $e');
    }
  }

  Future<void> _runPadUsDiagnostic() async {
    if (_isRunningDiagnostic) return;

    setState(() {
      _isRunningDiagnostic = true;
    });

    try {
      final diagnosticService = PadUsDiagnosticService();
      final results = await diagnosticService.diagnosticDownloadAndAnalyze();

      if (mounted) {
        if (results['success'] == true) {
          final totalFeatures = results['totalFeatures'];
          final foundLandmarks = results['foundLandmarkNames'] as List;
          final parsedCount = results['parsedCount'];

          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('PAD-US Diagnostic Results'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Downloaded: $totalFeatures features'),
                      Text('Parsed: $parsedCount landmarks'),
                      const SizedBox(height: 16),
                      const Text('Expected South Dakota Landmarks:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...foundLandmarks.map((landmark) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                      '${landmark['expected']}: ${landmark['actual']}'),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 16),
                      const Text(
                          'Check console/debug output for detailed analysis.'),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Diagnostic failed: ${results['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        await _loadRecordCount();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Diagnostic error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunningDiagnostic = false;
        });
      }
    }
  }

  Future<void> _downloadPadUsData() async {
    if (_isDownloadingPadUs) return;

    setState(() {
      _isDownloadingPadUs = true;
    });

    try {
      final padUsService = PadUsDataService();
      await padUsService.downloadBlackHillsData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PAD-US data downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadRecordCount();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading PAD-US data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingPadUs = false;
        });
      }
    }
  }

  Future<void> _generateTestData() async {
    if (_isGeneratingData) return;

    setState(() {
      _isGeneratingData = true;
    });

    try {
      final testService = TestLandDataService();
      await testService.generateBlackHillsTestData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test land data generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadRecordCount();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating test data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingData = false;
        });
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Land Data'),
        content: const Text(
            'Are you sure you want to delete all land ownership data? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = LandOwnershipService.instance;
        await service.clearAllLandOwnership();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All land data cleared'),
              backgroundColor: Colors.orange,
            ),
          );
          await _loadRecordCount();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDataStats() async {
    try {
      final service = LandOwnershipService.instance;
      final countByType = await service.getLandOwnershipCountByType();

      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Land Data Statistics'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Records: $_recordCount'),
                const SizedBox(height: 16),
                const Text('By Land Type:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...countByType.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(entry.key.displayName)),
                          Text('${entry.value}'),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading statistics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testNpsApi() async {
    if (_isTestingNpsApi) return;

    setState(() {
      _isTestingNpsApi = true;
    });

    try {
      final npsService = NpsApiService();
      final parks = await npsService.getSouthDakotaParks();

      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('NPS API Test Results'),
            content: SizedBox(
              width: 400,
              height: 300,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Successfully retrieved ${parks.length} South Dakota parks from NPS API',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('Parks found:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...parks.map((park) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.park,
                                  color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(park.ownerName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    if (park.designation != null)
                                      Text('${park.designation}',
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 16),
                    const Text('✅ Expected landmarks:'),
                    Text(
                        'Wind Cave: ${parks.any((p) => p.ownerName.contains('Wind Cave')) ? 'Found ✅' : 'Missing ❌'}'),
                    Text(
                        'Badlands: ${parks.any((p) => p.ownerName.contains('Badlands')) ? 'Found ✅' : 'Missing ❌'}'),
                    Text(
                        'Jewel Cave: ${parks.any((p) => p.ownerName.contains('Jewel Cave')) ? 'Found ✅' : 'Missing ❌'}'),
                    Text(
                        'Mount Rushmore: ${parks.any((p) => p.ownerName.contains('Mount Rushmore')) ? 'Found ✅' : 'Missing ❌'}'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('NPS API test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingNpsApi = false;
        });
      }
    }
  }

  Future<void> _runDebugAnalysis() async {
    if (_isRunningDebugAnalysis) return;

    setState(() {
      _isRunningDebugAnalysis = true;
    });

    try {
      final debugService = DebugLandDataService();
      await debugService.printDetailedAnalysis();
      final analysis = await debugService.analyzeLandOwnershipData();

      if (mounted) {
        final landmarkAnalysis =
            analysis['landmarkAnalysis'] as Map<String, dynamic>;
        final coordinateAnalysis =
            analysis['coordinateAnalysis'] as Map<String, dynamic>;
        final sourceAnalysis =
            analysis['sourceAnalysis'] as Map<String, dynamic>;

        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Debug Analysis Results'),
            content: SizedBox(
              width: 500,
              height: 400,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Records: ${analysis['totalCount']}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'Records in SD Bounds: ${analysis['recordsInSDBounds']}'),
                    const SizedBox(height: 16),
                    const Text('🏞️ Landmark Analysis:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'Expected Landmarks Found: ${landmarkAnalysis['expectedLandmarksFound']}/${landmarkAnalysis['totalExpected']}'),
                    const SizedBox(height: 8),
                    if (landmarkAnalysis['foundLandmarks'] != null)
                      ...(landmarkAnalysis['foundLandmarks']
                              as Map<String, dynamic>)
                          .entries
                          .map((e) =>
                              Text('✅ ${e.key}: ${(e.value as List).first}')),
                    const SizedBox(height: 16),
                    const Text('🗺️ Coordinate Analysis:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'Valid SD Coordinates: ${coordinateAnalysis['validSDCoordinates']}'),
                    Text(
                        'Invalid Coordinates: ${coordinateAnalysis['invalidCoordinates']}'),
                    Text('Accuracy: ${coordinateAnalysis['percentageValid']}%'),
                    const SizedBox(height: 16),
                    const Text('📡 Data Source Analysis:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Primary Source: ${sourceAnalysis['primarySource']}'),
                    const SizedBox(height: 16),
                    const Text('📋 Key Findings:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    if ((landmarkAnalysis['expectedLandmarksFound'] as int) ==
                        0)
                      const Text('❌ No expected SD landmarks found in data',
                          style: TextStyle(color: Colors.red)),
                    if ((coordinateAnalysis['percentageValid'] as int) < 50)
                      const Text('❌ Most coordinates are outside South Dakota',
                          style: TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    const Text(
                        '📖 Check debug console for detailed breakdown.'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug analysis error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunningDebugAnalysis = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terrain, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Land Ownership Data',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_recordCount ?? 0) > 0
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_recordCount ?? 0) > 0
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    (_recordCount ?? 0) > 0
                        ? Icons.check_circle
                        : Icons.warning_amber,
                    color:
                        (_recordCount ?? 0) > 0 ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _recordCount == null
                          ? 'Loading...'
                          : _recordCount! > 0
                              ? 'Land data available (${_recordCount!} records)'
                              : 'No land ownership data available',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Actions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: (_isDownloadingPadUs || _isGeneratingData)
                      ? null
                      : _downloadPadUsData,
                  icon: _isDownloadingPadUs
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isDownloadingPadUs
                      ? 'Downloading...'
                      : 'Download PAD-US Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: (_isDownloadingPadUs || _isGeneratingData)
                      ? null
                      : _generateTestData,
                  icon: _isGeneratingData
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_location),
                  label: Text(_isGeneratingData
                      ? 'Generating...'
                      : 'Generate Test Data'),
                ),
                ElevatedButton.icon(
                  onPressed: (_isDownloadingPadUs ||
                          _isGeneratingData ||
                          _isRunningDebugAnalysis ||
                          _isTestingNpsApi)
                      ? null
                      : _testNpsApi,
                  icon: _isTestingNpsApi
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.park),
                  label: Text(_isTestingNpsApi ? 'Testing...' : 'Test NPS API'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: (_isDownloadingPadUs ||
                          _isGeneratingData ||
                          _isRunningDebugAnalysis ||
                          _isTestingNpsApi)
                      ? null
                      : _runDebugAnalysis,
                  icon: _isRunningDebugAnalysis
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.analytics),
                  label: Text(_isRunningDebugAnalysis
                      ? 'Analyzing...'
                      : 'Analyze 77 Records'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: (_isDownloadingPadUs ||
                          _isGeneratingData ||
                          _isRunningDiagnostic ||
                          _isRunningDebugAnalysis)
                      ? null
                      : _runPadUsDiagnostic,
                  icon: _isRunningDiagnostic
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bug_report),
                  label: Text(_isRunningDiagnostic
                      ? 'Diagnosing...'
                      : 'Diagnose PAD-US Data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                  ),
                ),
                if ((_recordCount ?? 0) > 0) ...[
                  OutlinedButton.icon(
                    onPressed: _showDataStats,
                    icon: const Icon(Icons.analytics),
                    label: const Text('View Stats'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _clearAllData,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Help text
            Text(
              'PAD-US data downloads real protected areas from the USGS database for the Black Hills region. '
              'Test data provides sample land ownership information for development and testing.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
