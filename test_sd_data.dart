// ignore_for_file: avoid_print
import 'dart:async';
import 'package:obsession_tracker/core/services/nps_api_service.dart';

/// Quick test to see what South Dakota data is available right now
Future<void> main() async {
  print('🗺️ Testing South Dakota mapping data availability...\n');
  
  final npsService = NpsApiService();
  
  try {
    // Test NPS API for South Dakota
    print('📍 Fetching NPS data for South Dakota...');
    final sdParks = await npsService.getSouthDakotaParks();
    
    if (sdParks.isNotEmpty) {
      print('✅ Found ${sdParks.length} National Parks in South Dakota:');
      for (final park in sdParks) {
        print('  🏞️ ${park.ownerName}');
        print('     Type: ${park.designation}');
        print('     Location: ${park.centroid.latitude}, ${park.centroid.longitude}');
        print('     Access: ${park.accessType}');
        print('');
      }
    } else {
      print('❌ No NPS data found for South Dakota');
    }
    
  } catch (e) {
    print('❌ Error fetching NPS data: $e');
  }
  
  print("📱 What you'll see in your Flutter app when selecting SD:");
  print('✅ National Parks: ${await testNPSData() ? "Available" : "Not available"}');
  print('❌ Land Ownership Boundaries: Not available (needs PAD-US geodatabase)');
  print('❌ Legal Descriptions: Not available (needs BLM PLSS integration)');
  print('');
  print('🚀 To get full mapping data:');
  print('1. Manual download PAD-US from: https://www.sciencebase.gov/catalog/item/6759abcfd34edfeb8710a004');
  print('2. Start spatial database: docker-compose -f docker-compose.mapping-data.yml up -d postgres-spatial');
  print('3. Process geodatabase data');
  print('4. Start mapping API services');
}

Future<bool> testNPSData() async {
  try {
    final npsService = NpsApiService();
    // Create test cache if it doesn't exist
    await npsService.createSouthDakotaTestCache();
    final parks = await npsService.getParksForState('SD');
    return parks.isNotEmpty;
  } catch (e) {
    return false;
  }
}