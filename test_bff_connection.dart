// ignore_for_file: avoid_print
// Simple test script to verify BFF connection configuration
// Run with: dart run test_bff_connection.dart

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

void main() async {
  print('🧪 Testing BFF Connection Configuration\n');

  // Configuration
  const String localIP = '192.168.10.229';
  const String port = '4000';
  const String healthEndpoint = 'http://$localIP:$port/health';
  const String graphqlEndpoint = 'http://$localIP:$port/graphql';

  print('📍 Local IP: $localIP');
  print('🔗 Health Endpoint: $healthEndpoint');
  print('🔗 GraphQL Endpoint: $graphqlEndpoint');
  print('');

  // Test 1: Health Check
  print('🏥 Testing Health Check...');
  try {
    final healthResponse = await http.get(
      Uri.parse(healthEndpoint),
      headers: {'Accept': 'text/plain'},
    ).timeout(const Duration(seconds: 5));

    if (healthResponse.statusCode == 200) {
      print('✅ Health Check: ${healthResponse.body.trim()}');
    } else {
      print('❌ Health Check Failed: ${healthResponse.statusCode}');
      print('   Response: ${healthResponse.body}');
    }
  } catch (e) {
    print('❌ Health Check Error: $e');
    return;
  }

  print('');

  // Test 2: Basic GraphQL Query
  print('🔍 Testing GraphQL Query...');
  try {
    final graphqlQuery = {
      'query': '{ hello status }'
    };

    final graphqlResponse = await http.post(
      Uri.parse(graphqlEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(graphqlQuery),
    ).timeout(const Duration(seconds: 10));

    if (graphqlResponse.statusCode == 200) {
      final responseData = json.decode(graphqlResponse.body);
      if (responseData['data'] != null) {
        print('✅ GraphQL Query Success:');
        print('   Hello: ${responseData['data']['hello']}');
        print('   Status: ${responseData['data']['status']}');
      } else if (responseData['errors'] != null) {
        print('❌ GraphQL Errors:');
        for (final error in responseData['errors'] as List) {
          print('   - ${error['message']}');
        }
      }
    } else {
      print('❌ GraphQL Query Failed: ${graphqlResponse.statusCode}');
      print('   Response: ${graphqlResponse.body}');
    }
  } catch (e) {
    print('❌ GraphQL Query Error: $e');
  }

  print('');

  // Test 3: Network Connectivity Test
  print('🌐 Testing Network Connectivity...');
  try {
    final result = await Process.run('ping', ['-c', '1', localIP]);
    if (result.exitCode == 0) {
      print('✅ Network: Can reach $localIP');
    } else {
      print('❌ Network: Cannot reach $localIP');
      print('   Make sure your device is on the same network');
    }
  } catch (e) {
    print('⚠️  Network test unavailable: $e');
  }

  print('');
  print('🎯 Configuration Summary:');
  print('   - Update your Flutter app to use: $graphqlEndpoint');
  print('   - Make sure Docker services are running');
  print('   - Test from your mobile device or emulator');
  print('');
  print('📱 Flutter Usage:');
  print('   BFFConfig.graphqlEndpoint will return: $graphqlEndpoint (in debug mode)');
}