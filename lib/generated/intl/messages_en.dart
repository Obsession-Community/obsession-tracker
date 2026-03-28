// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(degrees, direction) =>
      "Compass heading: ${degrees} degrees ${direction}";

  static String m1(latitude, longitude) =>
      "Location updated: ${latitude}, ${longitude}";

  static String m2(command) => "Voice command recognized: ${command}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "accessibility": MessageLookupByLibrary.simpleMessage("Accessibility"),
    "accuracy": MessageLookupByLibrary.simpleMessage("Accuracy"),
    "addWaypoint": MessageLookupByLibrary.simpleMessage("Add Waypoint"),
    "altitude": MessageLookupByLibrary.simpleMessage("Altitude"),
    "appDescription": MessageLookupByLibrary.simpleMessage(
      "Your compass when nothing adds up. A privacy-first GPS tracking app for treasure hunters, explorers, and adventurers.",
    ),
    "appTitle": MessageLookupByLibrary.simpleMessage("Obsession Tracker"),
    "audioFeedback": MessageLookupByLibrary.simpleMessage("Audio Feedback"),
    "colorFilters": MessageLookupByLibrary.simpleMessage("Color Filters"),
    "compassHeading": m0,
    "currency": MessageLookupByLibrary.simpleMessage("Currency"),
    "currentLocation": MessageLookupByLibrary.simpleMessage("Current Location"),
    "dateFormat": MessageLookupByLibrary.simpleMessage("Date Format"),
    "deuteranopia": MessageLookupByLibrary.simpleMessage("Deuteranopia"),
    "disabled": MessageLookupByLibrary.simpleMessage("Disabled"),
    "distance": MessageLookupByLibrary.simpleMessage("Distance"),
    "doubleTabToActivate": MessageLookupByLibrary.simpleMessage(
      "Double tap to activate",
    ),
    "duration": MessageLookupByLibrary.simpleMessage("Duration"),
    "east": MessageLookupByLibrary.simpleMessage("East"),
    "enabled": MessageLookupByLibrary.simpleMessage("Enabled"),
    "enhancedFocus": MessageLookupByLibrary.simpleMessage("Enhanced Focus"),
    "error": MessageLookupByLibrary.simpleMessage("Error"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("Extra Large"),
    "feet": MessageLookupByLibrary.simpleMessage("feet"),
    "focusIndicator": MessageLookupByLibrary.simpleMessage("Focus Indicator"),
    "fontScale": MessageLookupByLibrary.simpleMessage("Font Scale"),
    "grantPermission": MessageLookupByLibrary.simpleMessage("Grant Permission"),
    "heading": MessageLookupByLibrary.simpleMessage("Heading"),
    "highContrast": MessageLookupByLibrary.simpleMessage("High Contrast"),
    "home": MessageLookupByLibrary.simpleMessage("Home"),
    "imperial": MessageLookupByLibrary.simpleMessage("Imperial"),
    "information": MessageLookupByLibrary.simpleMessage("Information"),
    "keyboardNavigation": MessageLookupByLibrary.simpleMessage(
      "Keyboard Navigation",
    ),
    "kilometers": MessageLookupByLibrary.simpleMessage("kilometers"),
    "kilometersPerHour": MessageLookupByLibrary.simpleMessage(
      "kilometers per hour",
    ),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "large": MessageLookupByLibrary.simpleMessage("Large"),
    "largeText": MessageLookupByLibrary.simpleMessage("Large Text"),
    "latitude": MessageLookupByLibrary.simpleMessage("Latitude"),
    "leftToRight": MessageLookupByLibrary.simpleMessage("Left to Right"),
    "loading": MessageLookupByLibrary.simpleMessage("Loading"),
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Location permission is required to use this app",
    ),
    "locationUpdated": m1,
    "longitude": MessageLookupByLibrary.simpleMessage("Longitude"),
    "map": MessageLookupByLibrary.simpleMessage("Map"),
    "measurementUnits": MessageLookupByLibrary.simpleMessage(
      "Measurement Units",
    ),
    "meters": MessageLookupByLibrary.simpleMessage("meters"),
    "metersPerSecond": MessageLookupByLibrary.simpleMessage(
      "meters per second",
    ),
    "metric": MessageLookupByLibrary.simpleMessage("Metric"),
    "microphonePermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Microphone permission is required for voice control",
    ),
    "miles": MessageLookupByLibrary.simpleMessage("miles"),
    "milesPerHour": MessageLookupByLibrary.simpleMessage("miles per hour"),
    "monochrome": MessageLookupByLibrary.simpleMessage("Monochrome"),
    "none": MessageLookupByLibrary.simpleMessage("None"),
    "normal": MessageLookupByLibrary.simpleMessage("Normal"),
    "north": MessageLookupByLibrary.simpleMessage("North"),
    "northeast": MessageLookupByLibrary.simpleMessage("Northeast"),
    "northwest": MessageLookupByLibrary.simpleMessage("Northwest"),
    "numberFormat": MessageLookupByLibrary.simpleMessage("Number Format"),
    "protanopia": MessageLookupByLibrary.simpleMessage("Protanopia"),
    "regionalSettings": MessageLookupByLibrary.simpleMessage(
      "Regional Settings",
    ),
    "rightToLeft": MessageLookupByLibrary.simpleMessage("Right to Left"),
    "sayAddWaypoint": MessageLookupByLibrary.simpleMessage(
      "Say \'Add waypoint\' to mark current location",
    ),
    "sayShowMap": MessageLookupByLibrary.simpleMessage(
      "Say \'Show map\' to view the map",
    ),
    "sayStartTracking": MessageLookupByLibrary.simpleMessage(
      "Say \'Start tracking\' to begin GPS tracking",
    ),
    "sayStopTracking": MessageLookupByLibrary.simpleMessage(
      "Say \'Stop tracking\' to end GPS tracking",
    ),
    "screenReader": MessageLookupByLibrary.simpleMessage(
      "Screen Reader Support",
    ),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "small": MessageLookupByLibrary.simpleMessage("Small"),
    "south": MessageLookupByLibrary.simpleMessage("South"),
    "southeast": MessageLookupByLibrary.simpleMessage("Southeast"),
    "southwest": MessageLookupByLibrary.simpleMessage("Southwest"),
    "speed": MessageLookupByLibrary.simpleMessage("Speed"),
    "startTracking": MessageLookupByLibrary.simpleMessage("Start Tracking"),
    "stopTracking": MessageLookupByLibrary.simpleMessage("Stop Tracking"),
    "success": MessageLookupByLibrary.simpleMessage("Success"),
    "swipeToNavigate": MessageLookupByLibrary.simpleMessage(
      "Swipe to navigate",
    ),
    "tapToActivate": MessageLookupByLibrary.simpleMessage("Tap to activate"),
    "textDirection": MessageLookupByLibrary.simpleMessage("Text Direction"),
    "theme": MessageLookupByLibrary.simpleMessage("Theme"),
    "timeFormat": MessageLookupByLibrary.simpleMessage("Time Format"),
    "tracking": MessageLookupByLibrary.simpleMessage("Tracking"),
    "trackingStarted": MessageLookupByLibrary.simpleMessage(
      "GPS tracking started",
    ),
    "trackingStopped": MessageLookupByLibrary.simpleMessage(
      "GPS tracking stopped",
    ),
    "tritanopia": MessageLookupByLibrary.simpleMessage("Tritanopia"),
    "twelveHour": MessageLookupByLibrary.simpleMessage("12 Hour"),
    "twentyFourHour": MessageLookupByLibrary.simpleMessage("24 Hour"),
    "voiceCommandRecognized": m2,
    "voiceCommandsHelp": MessageLookupByLibrary.simpleMessage(
      "Voice Commands Help",
    ),
    "voiceControl": MessageLookupByLibrary.simpleMessage("Voice Control"),
    "warning": MessageLookupByLibrary.simpleMessage("Warning"),
    "waypointAdded": MessageLookupByLibrary.simpleMessage(
      "Waypoint added at current location",
    ),
    "waypoints": MessageLookupByLibrary.simpleMessage("Waypoints"),
    "west": MessageLookupByLibrary.simpleMessage("West"),
  };
}
