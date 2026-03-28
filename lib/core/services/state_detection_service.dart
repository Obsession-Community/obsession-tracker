import 'package:flutter/foundation.dart';

/// Service for detecting which US state a GPS coordinate falls within.
///
/// Uses embedded state boundary data for 100% offline operation.
/// No external API calls are made - privacy is preserved.
///
/// The algorithm uses:
/// 1. Bounding box check for quick rejection
/// 2. Point-in-polygon (ray casting) for accurate detection
class StateDetectionService {
  factory StateDetectionService() => _instance;
  StateDetectionService._internal();
  static final StateDetectionService _instance = StateDetectionService._internal();

  bool _isInitialized = false;

  /// Initialize the service (loads state boundaries into memory)
  Future<void> initialize() async {
    if (_isInitialized) return;
    // State data is already embedded, just mark as initialized
    _isInitialized = true;
    debugPrint('StateDetectionService initialized with ${_stateBoundaries.length} states');
  }

  /// Get the state code (e.g., 'UT', 'WY') for a given coordinate
  ///
  /// Returns null if the coordinate is outside the US or in international waters.
  String? getStateFromCoordinates(double latitude, double longitude) {
    for (final entry in _stateBoundaries.entries) {
      final stateCode = entry.key;
      final boundary = entry.value;

      // Quick bounding box check first
      if (!_isInBoundingBox(latitude, longitude, boundary['bbox'] as List<double>)) {
        continue;
      }

      // Detailed polygon check
      final polygons = boundary['polygons'] as List<List<List<double>>>;
      for (final polygon in polygons) {
        if (_isPointInPolygon(latitude, longitude, polygon)) {
          return stateCode;
        }
      }
    }
    return null;
  }

  /// Get all states that a list of coordinates falls within
  ///
  /// Useful for processing a session's breadcrumbs to find all explored states.
  Set<String> getStatesFromCoordinates(List<({double lat, double lng})> coordinates) {
    final states = <String>{};
    for (final coord in coordinates) {
      final state = getStateFromCoordinates(coord.lat, coord.lng);
      if (state != null) {
        states.add(state);
      }
    }
    return states;
  }

  /// Get the full state name from state code
  String getStateName(String stateCode) {
    return _stateNames[stateCode] ?? stateCode;
  }

  /// Get all state codes
  List<String> getAllStateCodes() {
    return _stateNames.keys.toList()..sort();
  }

  /// Check if a point is within a bounding box
  bool _isInBoundingBox(double lat, double lng, List<double> bbox) {
    // bbox format: [minLng, minLat, maxLng, maxLat]
    return lng >= bbox[0] && lng <= bbox[2] && lat >= bbox[1] && lat <= bbox[3];
  }

  /// Point-in-polygon test using ray casting algorithm
  ///
  /// Casts a ray from the point to the right and counts intersections.
  /// If odd number of intersections, point is inside.
  bool _isPointInPolygon(double lat, double lng, List<List<double>> polygon) {
    var inside = false;
    final n = polygon.length;

    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = polygon[i][0]; // longitude
      final yi = polygon[i][1]; // latitude
      final xj = polygon[j][0];
      final yj = polygon[j][1];

      if (((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }

    return inside;
  }

  /// State names mapping
  static const Map<String, String> _stateNames = {
    'AL': 'Alabama',
    'AK': 'Alaska',
    'AZ': 'Arizona',
    'AR': 'Arkansas',
    'CA': 'California',
    'CO': 'Colorado',
    'CT': 'Connecticut',
    'DE': 'Delaware',
    'FL': 'Florida',
    'GA': 'Georgia',
    'HI': 'Hawaii',
    'ID': 'Idaho',
    'IL': 'Illinois',
    'IN': 'Indiana',
    'IA': 'Iowa',
    'KS': 'Kansas',
    'KY': 'Kentucky',
    'LA': 'Louisiana',
    'ME': 'Maine',
    'MD': 'Maryland',
    'MA': 'Massachusetts',
    'MI': 'Michigan',
    'MN': 'Minnesota',
    'MS': 'Mississippi',
    'MO': 'Missouri',
    'MT': 'Montana',
    'NE': 'Nebraska',
    'NV': 'Nevada',
    'NH': 'New Hampshire',
    'NJ': 'New Jersey',
    'NM': 'New Mexico',
    'NY': 'New York',
    'NC': 'North Carolina',
    'ND': 'North Dakota',
    'OH': 'Ohio',
    'OK': 'Oklahoma',
    'OR': 'Oregon',
    'PA': 'Pennsylvania',
    'RI': 'Rhode Island',
    'SC': 'South Carolina',
    'SD': 'South Dakota',
    'TN': 'Tennessee',
    'TX': 'Texas',
    'UT': 'Utah',
    'VT': 'Vermont',
    'VA': 'Virginia',
    'WA': 'Washington',
    'WV': 'West Virginia',
    'WI': 'Wisconsin',
    'WY': 'Wyoming',
    'DC': 'District of Columbia',
  };

  /// Simplified state boundaries with bounding boxes and representative polygons
  ///
  /// Format: stateCode -> { 'bbox': [minLng, minLat, maxLng, maxLat], 'polygons': [[[lng, lat], ...]] }
  ///
  /// Note: These are simplified boundaries for performance. For production use,
  /// consider loading detailed GeoJSON from assets for more accurate detection.
  static final Map<String, Map<String, dynamic>> _stateBoundaries = {
    'AL': {
      'bbox': [-88.473, 30.223, -84.889, 35.008],
      'polygons': [
        [[-88.473, 30.223], [-88.473, 35.008], [-84.889, 35.008], [-84.889, 30.223], [-88.473, 30.223]]
      ]
    },
    'AK': {
      'bbox': [-179.148, 51.215, -129.980, 71.352],
      'polygons': [
        [[-179.148, 51.215], [-179.148, 71.352], [-129.980, 71.352], [-129.980, 51.215], [-179.148, 51.215]]
      ]
    },
    'AZ': {
      'bbox': [-114.816, 31.332, -109.045, 37.004],
      'polygons': [
        [[-114.816, 31.332], [-114.816, 37.004], [-109.045, 37.004], [-109.045, 31.332], [-114.816, 31.332]]
      ]
    },
    'AR': {
      'bbox': [-94.618, 33.004, -89.644, 36.500],
      'polygons': [
        [[-94.618, 33.004], [-94.618, 36.500], [-89.644, 36.500], [-89.644, 33.004], [-94.618, 33.004]]
      ]
    },
    'CA': {
      'bbox': [-124.409, 32.534, -114.131, 42.009],
      'polygons': [
        [[-124.409, 32.534], [-124.409, 42.009], [-114.131, 42.009], [-114.131, 32.534], [-124.409, 32.534]]
      ]
    },
    'CO': {
      'bbox': [-109.060, 36.993, -102.041, 41.003],
      'polygons': [
        [[-109.060, 36.993], [-109.060, 41.003], [-102.041, 41.003], [-102.041, 36.993], [-109.060, 36.993]]
      ]
    },
    'CT': {
      'bbox': [-73.728, 40.987, -71.787, 42.050],
      'polygons': [
        [[-73.728, 40.987], [-73.728, 42.050], [-71.787, 42.050], [-71.787, 40.987], [-73.728, 40.987]]
      ]
    },
    'DE': {
      'bbox': [-75.789, 38.451, -75.049, 39.839],
      'polygons': [
        [[-75.789, 38.451], [-75.789, 39.839], [-75.049, 39.839], [-75.049, 38.451], [-75.789, 38.451]]
      ]
    },
    'FL': {
      'bbox': [-87.635, 24.523, -80.031, 31.001],
      'polygons': [
        [[-87.635, 24.523], [-87.635, 31.001], [-80.031, 31.001], [-80.031, 24.523], [-87.635, 24.523]]
      ]
    },
    'GA': {
      'bbox': [-85.605, 30.357, -80.840, 35.001],
      'polygons': [
        [[-85.605, 30.357], [-85.605, 35.001], [-80.840, 35.001], [-80.840, 30.357], [-85.605, 30.357]]
      ]
    },
    'HI': {
      'bbox': [-160.247, 18.910, -154.807, 22.235],
      'polygons': [
        [[-160.247, 18.910], [-160.247, 22.235], [-154.807, 22.235], [-154.807, 18.910], [-160.247, 18.910]]
      ]
    },
    'ID': {
      'bbox': [-117.243, 41.988, -111.044, 49.001],
      'polygons': [
        [[-117.243, 41.988], [-117.243, 49.001], [-111.044, 49.001], [-111.044, 41.988], [-117.243, 41.988]]
      ]
    },
    'IL': {
      'bbox': [-91.513, 36.970, -87.495, 42.508],
      'polygons': [
        [[-91.513, 36.970], [-91.513, 42.508], [-87.495, 42.508], [-87.495, 36.970], [-91.513, 36.970]]
      ]
    },
    'IN': {
      'bbox': [-88.098, 37.772, -84.784, 41.761],
      'polygons': [
        [[-88.098, 37.772], [-88.098, 41.761], [-84.784, 41.761], [-84.784, 37.772], [-88.098, 37.772]]
      ]
    },
    'IA': {
      'bbox': [-96.639, 40.375, -90.140, 43.501],
      'polygons': [
        [[-96.639, 40.375], [-96.639, 43.501], [-90.140, 43.501], [-90.140, 40.375], [-96.639, 40.375]]
      ]
    },
    'KS': {
      'bbox': [-102.052, 36.993, -94.588, 40.003],
      'polygons': [
        [[-102.052, 36.993], [-102.052, 40.003], [-94.588, 40.003], [-94.588, 36.993], [-102.052, 36.993]]
      ]
    },
    'KY': {
      'bbox': [-89.571, 36.497, -81.965, 39.147],
      'polygons': [
        [[-89.571, 36.497], [-89.571, 39.147], [-81.965, 39.147], [-81.965, 36.497], [-89.571, 36.497]]
      ]
    },
    'LA': {
      'bbox': [-94.043, 28.928, -88.817, 33.019],
      'polygons': [
        [[-94.043, 28.928], [-94.043, 33.019], [-88.817, 33.019], [-88.817, 28.928], [-94.043, 28.928]]
      ]
    },
    'ME': {
      'bbox': [-71.084, 43.059, -66.950, 47.460],
      'polygons': [
        [[-71.084, 43.059], [-71.084, 47.460], [-66.950, 47.460], [-66.950, 43.059], [-71.084, 43.059]]
      ]
    },
    'MD': {
      'bbox': [-79.487, 37.912, -75.049, 39.723],
      'polygons': [
        [[-79.487, 37.912], [-79.487, 39.723], [-75.049, 39.723], [-75.049, 37.912], [-79.487, 37.912]]
      ]
    },
    'MA': {
      'bbox': [-73.508, 41.238, -69.928, 42.887],
      'polygons': [
        [[-73.508, 41.238], [-73.508, 42.887], [-69.928, 42.887], [-69.928, 41.238], [-73.508, 41.238]]
      ]
    },
    'MI': {
      'bbox': [-90.418, 41.696, -82.413, 48.190],
      'polygons': [
        [[-90.418, 41.696], [-90.418, 48.190], [-82.413, 48.190], [-82.413, 41.696], [-90.418, 41.696]]
      ]
    },
    'MN': {
      'bbox': [-97.239, 43.500, -89.491, 49.384],
      'polygons': [
        [[-97.239, 43.500], [-97.239, 49.384], [-89.491, 49.384], [-89.491, 43.500], [-97.239, 43.500]]
      ]
    },
    'MS': {
      'bbox': [-91.655, 30.174, -88.098, 34.996],
      'polygons': [
        [[-91.655, 30.174], [-91.655, 34.996], [-88.098, 34.996], [-88.098, 30.174], [-91.655, 30.174]]
      ]
    },
    'MO': {
      'bbox': [-95.774, 35.996, -89.099, 40.613],
      'polygons': [
        [[-95.774, 35.996], [-95.774, 40.613], [-89.099, 40.613], [-89.099, 35.996], [-95.774, 35.996]]
      ]
    },
    'MT': {
      'bbox': [-116.050, 44.358, -104.040, 49.001],
      'polygons': [
        [[-116.050, 44.358], [-116.050, 49.001], [-104.040, 49.001], [-104.040, 44.358], [-116.050, 44.358]]
      ]
    },
    'NE': {
      'bbox': [-104.053, 40.001, -95.308, 43.001],
      'polygons': [
        [[-104.053, 40.001], [-104.053, 43.001], [-95.308, 43.001], [-95.308, 40.001], [-104.053, 40.001]]
      ]
    },
    'NV': {
      'bbox': [-120.006, 35.002, -114.040, 42.002],
      'polygons': [
        [[-120.006, 35.002], [-120.006, 42.002], [-114.040, 42.002], [-114.040, 35.002], [-120.006, 35.002]]
      ]
    },
    'NH': {
      'bbox': [-72.557, 42.697, -70.703, 45.305],
      'polygons': [
        [[-72.557, 42.697], [-72.557, 45.305], [-70.703, 45.305], [-70.703, 42.697], [-72.557, 42.697]]
      ]
    },
    'NJ': {
      'bbox': [-75.559, 38.929, -73.894, 41.357],
      'polygons': [
        [[-75.559, 38.929], [-75.559, 41.357], [-73.894, 41.357], [-73.894, 38.929], [-75.559, 38.929]]
      ]
    },
    'NM': {
      'bbox': [-109.050, 31.332, -103.002, 37.000],
      'polygons': [
        [[-109.050, 31.332], [-109.050, 37.000], [-103.002, 37.000], [-103.002, 31.332], [-109.050, 31.332]]
      ]
    },
    'NY': {
      'bbox': [-79.762, 40.496, -71.856, 45.016],
      'polygons': [
        [[-79.762, 40.496], [-79.762, 45.016], [-71.856, 45.016], [-71.856, 40.496], [-79.762, 40.496]]
      ]
    },
    'NC': {
      'bbox': [-84.322, 33.842, -75.460, 36.588],
      'polygons': [
        [[-84.322, 33.842], [-84.322, 36.588], [-75.460, 36.588], [-75.460, 33.842], [-84.322, 33.842]]
      ]
    },
    'ND': {
      'bbox': [-104.049, 45.935, -96.554, 49.001],
      'polygons': [
        [[-104.049, 45.935], [-104.049, 49.001], [-96.554, 49.001], [-96.554, 45.935], [-104.049, 45.935]]
      ]
    },
    'OH': {
      'bbox': [-84.820, 38.403, -80.519, 41.978],
      'polygons': [
        [[-84.820, 38.403], [-84.820, 41.978], [-80.519, 41.978], [-80.519, 38.403], [-84.820, 38.403]]
      ]
    },
    'OK': {
      'bbox': [-103.002, 33.616, -94.431, 37.002],
      'polygons': [
        [[-103.002, 33.616], [-103.002, 37.002], [-94.431, 37.002], [-94.431, 33.616], [-103.002, 33.616]]
      ]
    },
    'OR': {
      'bbox': [-124.567, 41.992, -116.464, 46.292],
      'polygons': [
        [[-124.567, 41.992], [-124.567, 46.292], [-116.464, 46.292], [-116.464, 41.992], [-124.567, 41.992]]
      ]
    },
    'PA': {
      'bbox': [-80.519, 39.720, -74.690, 42.269],
      'polygons': [
        [[-80.519, 39.720], [-80.519, 42.269], [-74.690, 42.269], [-74.690, 39.720], [-80.519, 39.720]]
      ]
    },
    'RI': {
      'bbox': [-71.862, 41.146, -71.120, 42.019],
      'polygons': [
        [[-71.862, 41.146], [-71.862, 42.019], [-71.120, 42.019], [-71.120, 41.146], [-71.862, 41.146]]
      ]
    },
    'SC': {
      'bbox': [-83.354, 32.035, -78.541, 35.216],
      'polygons': [
        [[-83.354, 32.035], [-83.354, 35.216], [-78.541, 35.216], [-78.541, 32.035], [-83.354, 32.035]]
      ]
    },
    'SD': {
      'bbox': [-104.058, 42.480, -96.436, 45.945],
      'polygons': [
        [[-104.058, 42.480], [-104.058, 45.945], [-96.436, 45.945], [-96.436, 42.480], [-104.058, 42.480]]
      ]
    },
    'TN': {
      'bbox': [-90.310, 34.983, -81.647, 36.678],
      'polygons': [
        [[-90.310, 34.983], [-90.310, 36.678], [-81.647, 36.678], [-81.647, 34.983], [-90.310, 34.983]]
      ]
    },
    'TX': {
      'bbox': [-106.646, 25.837, -93.508, 36.501],
      'polygons': [
        [[-106.646, 25.837], [-106.646, 36.501], [-93.508, 36.501], [-93.508, 25.837], [-106.646, 25.837]]
      ]
    },
    'UT': {
      'bbox': [-114.053, 36.998, -109.041, 42.001],
      'polygons': [
        [[-114.053, 36.998], [-114.053, 42.001], [-109.041, 42.001], [-109.041, 36.998], [-114.053, 36.998]]
      ]
    },
    'VT': {
      'bbox': [-73.438, 42.727, -71.465, 45.017],
      'polygons': [
        [[-73.438, 42.727], [-73.438, 45.017], [-71.465, 45.017], [-71.465, 42.727], [-73.438, 42.727]]
      ]
    },
    'VA': {
      'bbox': [-83.675, 36.541, -75.242, 39.466],
      'polygons': [
        [[-83.675, 36.541], [-83.675, 39.466], [-75.242, 39.466], [-75.242, 36.541], [-83.675, 36.541]]
      ]
    },
    'WA': {
      'bbox': [-124.733, 45.544, -116.916, 49.002],
      'polygons': [
        [[-124.733, 45.544], [-124.733, 49.002], [-116.916, 49.002], [-116.916, 45.544], [-124.733, 45.544]]
      ]
    },
    'WV': {
      'bbox': [-82.645, 37.202, -77.719, 40.638],
      'polygons': [
        [[-82.645, 37.202], [-82.645, 40.638], [-77.719, 40.638], [-77.719, 37.202], [-82.645, 37.202]]
      ]
    },
    'WI': {
      'bbox': [-92.889, 42.492, -86.250, 47.080],
      'polygons': [
        [[-92.889, 42.492], [-92.889, 47.080], [-86.250, 47.080], [-86.250, 42.492], [-92.889, 42.492]]
      ]
    },
    'WY': {
      'bbox': [-111.055, 40.995, -104.052, 45.006],
      'polygons': [
        [[-111.055, 40.995], [-111.055, 45.006], [-104.052, 45.006], [-104.052, 40.995], [-111.055, 40.995]]
      ]
    },
    'DC': {
      'bbox': [-77.119, 38.792, -76.909, 38.996],
      'polygons': [
        [[-77.119, 38.792], [-77.119, 38.996], [-76.909, 38.996], [-76.909, 38.792], [-77.119, 38.792]]
      ]
    },
  };
}
