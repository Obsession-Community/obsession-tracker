import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/features/sessions/presentation/pages/session_list_page.dart';
import 'package:obsession_tracker/features/tracking/presentation/pages/tracking_page.dart';
import 'package:obsession_tracker/features/waypoints/presentation/pages/adaptive_photo_gallery_page.dart';

/// The main home page of Obsession Tracker.
///
/// This page serves as the central hub for all GPS tracking activities,
/// providing quick access to navigation, waypoint management, and settings.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar:
            AppBar(title: const Text('Obsession Tracker'), centerTitle: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.explore, size: 80, color: Color(0xFF2E7D32)),
              const SizedBox(height: 24),
              const Text(
                'Welcome to Obsession Tracker',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Your compass when nothing adds up. '
                  'Start exploring with privacy-first GPS tracking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const SessionListPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text('View Saved Adventures'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const AdaptivePhotoGalleryPage(
                        sessionId:
                            'default-session', // TODO(dev): Use actual session
                        sessionName: 'Photo Gallery',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.photo_library),
                label: const Text('Photo Gallery'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ready to explore!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const TrackingPage(),
              ),
            );
          },
          tooltip: 'Start Tracking',
          child: const Icon(Icons.my_location),
        ),
      );
}
