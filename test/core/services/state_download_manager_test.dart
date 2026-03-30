import 'package:flutter_test/flutter_test.dart';
import 'package:obsession_tracker/core/services/state_download_manager.dart';

void main() {
  group('StateDownloadProgress', () {
    test('calculates progress as 0 when pending', () {
      final progress = StateDownloadProgress(
        stateCode: 'SD',
        stateName: 'South Dakota',
      );

      expect(progress.progress, 0.0);
    });

    test('calculates progress as 1.0 when completed', () {
      final progress = StateDownloadProgress(
        stateCode: 'SD',
        stateName: 'South Dakota',
        status: StateDownloadStatus.completed,
        bytesDownloaded: 50,
        totalBytes: 100,
      );

      // Should be 1.0 regardless of bytes
      expect(progress.progress, 1.0);
    });

    test('calculates progress from bytes when downloading', () {
      final progress = StateDownloadProgress(
        stateCode: 'SD',
        stateName: 'South Dakota',
        status: StateDownloadStatus.downloading,
        bytesDownloaded: 50,
        totalBytes: 100,
      );

      expect(progress.progress, 0.5);
    });

    test('returns 0 progress when totalBytes is 0 during download', () {
      final progress = StateDownloadProgress(
        stateCode: 'SD',
        stateName: 'South Dakota',
        status: StateDownloadStatus.downloading,
      );

      expect(progress.progress, 0.0);
    });

    test('copyWith preserves unchanged values', () {
      final original = StateDownloadProgress(
        stateCode: 'SD',
        stateName: 'South Dakota',
        status: StateDownloadStatus.downloading,
        message: 'Downloading...',
        recordCount: 100,
        trailCount: 50,
        bytesDownloaded: 1000,
        totalBytes: 2000,
      );

      final updated = original.copyWith(status: StateDownloadStatus.completed);

      expect(updated.stateCode, 'SD');
      expect(updated.stateName, 'South Dakota');
      expect(updated.status, StateDownloadStatus.completed);
      expect(updated.message, 'Downloading...');
      expect(updated.recordCount, 100);
      expect(updated.trailCount, 50);
      expect(updated.bytesDownloaded, 1000);
      expect(updated.totalBytes, 2000);
    });

    test('copyWith updates specified values', () {
      final original = StateDownloadProgress(
        stateCode: 'SD',
        stateName: 'South Dakota',
      );

      final updated = original.copyWith(
        status: StateDownloadStatus.completed,
        message: 'Done!',
        recordCount: 500,
      );

      expect(updated.status, StateDownloadStatus.completed);
      expect(updated.message, 'Done!');
      expect(updated.recordCount, 500);
    });
  });

  group('DownloadManagerState', () {
    test('calculates overall progress as 0 when no downloads', () {
      const state = DownloadManagerState();

      expect(state.overallProgress, 0.0);
    });

    test('calculates overall progress from completed count', () {
      const state = DownloadManagerState(
        completedCount: 3,
        totalCount: 6,
      );

      expect(state.overallProgress, 0.5);
    });

    test('calculates overall progress as 1.0 when all complete', () {
      const state = DownloadManagerState(
        completedCount: 5,
        totalCount: 5,
      );

      expect(state.overallProgress, 1.0);
    });

    test('copyWith preserves unchanged values', () {
      final downloads = {
        'SD': StateDownloadProgress(stateCode: 'SD', stateName: 'South Dakota'),
      };
      final original = DownloadManagerState(
        isDownloading: true,
        downloads: downloads,
        completedCount: 1,
        totalCount: 3,
      );

      final updated = original.copyWith(completedCount: 2);

      expect(updated.isDownloading, true);
      expect(updated.isCancelling, false);
      expect(updated.downloads, downloads);
      expect(updated.completedCount, 2);
      expect(updated.totalCount, 3);
    });

    test('default state has expected values', () {
      const state = DownloadManagerState();

      expect(state.isDownloading, false);
      expect(state.isCancelling, false);
      expect(state.downloads, isEmpty);
      expect(state.completedCount, 0);
      expect(state.totalCount, 0);
    });
  });

  group('StateDownloadStatus', () {
    test('has all expected values', () {
      expect(StateDownloadStatus.values, containsAll([
        StateDownloadStatus.pending,
        StateDownloadStatus.downloading,
        StateDownloadStatus.completed,
        StateDownloadStatus.failed,
        StateDownloadStatus.cancelled,
      ]));
    });
  });
}
