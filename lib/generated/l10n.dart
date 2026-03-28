// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name =
        (locale.countryCode?.isEmpty ?? false)
            ? locale.languageCode
            : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Obsession Tracker`
  String get appTitle {
    return Intl.message(
      'Obsession Tracker',
      name: 'appTitle',
      desc: 'The title of the application',
      args: [],
    );
  }

  /// `Your compass when nothing adds up. A privacy-first GPS tracking app for treasure hunters, explorers, and adventurers.`
  String get appDescription {
    return Intl.message(
      'Your compass when nothing adds up. A privacy-first GPS tracking app for treasure hunters, explorers, and adventurers.',
      name: 'appDescription',
      desc: 'The description of the application',
      args: [],
    );
  }

  /// `Home`
  String get home {
    return Intl.message(
      'Home',
      name: 'home',
      desc: 'Home navigation label',
      args: [],
    );
  }

  /// `Map`
  String get map {
    return Intl.message(
      'Map',
      name: 'map',
      desc: 'Map navigation label',
      args: [],
    );
  }

  /// `Tracking`
  String get tracking {
    return Intl.message(
      'Tracking',
      name: 'tracking',
      desc: 'Tracking navigation label',
      args: [],
    );
  }

  /// `Waypoints`
  String get waypoints {
    return Intl.message(
      'Waypoints',
      name: 'waypoints',
      desc: 'Waypoints navigation label',
      args: [],
    );
  }

  /// `Settings`
  String get settings {
    return Intl.message(
      'Settings',
      name: 'settings',
      desc: 'Settings navigation label',
      args: [],
    );
  }

  /// `Accessibility`
  String get accessibility {
    return Intl.message(
      'Accessibility',
      name: 'accessibility',
      desc: 'Accessibility settings section',
      args: [],
    );
  }

  /// `Language`
  String get language {
    return Intl.message(
      'Language',
      name: 'language',
      desc: 'Language settings section',
      args: [],
    );
  }

  /// `Theme`
  String get theme {
    return Intl.message(
      'Theme',
      name: 'theme',
      desc: 'Theme settings section',
      args: [],
    );
  }

  /// `High Contrast`
  String get highContrast {
    return Intl.message(
      'High Contrast',
      name: 'highContrast',
      desc: 'High contrast theme option',
      args: [],
    );
  }

  /// `Large Text`
  String get largeText {
    return Intl.message(
      'Large Text',
      name: 'largeText',
      desc: 'Large text accessibility option',
      args: [],
    );
  }

  /// `Voice Control`
  String get voiceControl {
    return Intl.message(
      'Voice Control',
      name: 'voiceControl',
      desc: 'Voice control accessibility option',
      args: [],
    );
  }

  /// `Audio Feedback`
  String get audioFeedback {
    return Intl.message(
      'Audio Feedback',
      name: 'audioFeedback',
      desc: 'Audio feedback accessibility option',
      args: [],
    );
  }

  /// `Screen Reader Support`
  String get screenReader {
    return Intl.message(
      'Screen Reader Support',
      name: 'screenReader',
      desc: 'Screen reader support option',
      args: [],
    );
  }

  /// `Start Tracking`
  String get startTracking {
    return Intl.message(
      'Start Tracking',
      name: 'startTracking',
      desc: 'Button to start GPS tracking',
      args: [],
    );
  }

  /// `Stop Tracking`
  String get stopTracking {
    return Intl.message(
      'Stop Tracking',
      name: 'stopTracking',
      desc: 'Button to stop GPS tracking',
      args: [],
    );
  }

  /// `Add Waypoint`
  String get addWaypoint {
    return Intl.message(
      'Add Waypoint',
      name: 'addWaypoint',
      desc: 'Button to add a new waypoint',
      args: [],
    );
  }

  /// `Current Location`
  String get currentLocation {
    return Intl.message(
      'Current Location',
      name: 'currentLocation',
      desc: 'Label for current GPS location',
      args: [],
    );
  }

  /// `Latitude`
  String get latitude {
    return Intl.message(
      'Latitude',
      name: 'latitude',
      desc: 'GPS latitude coordinate label',
      args: [],
    );
  }

  /// `Longitude`
  String get longitude {
    return Intl.message(
      'Longitude',
      name: 'longitude',
      desc: 'GPS longitude coordinate label',
      args: [],
    );
  }

  /// `Altitude`
  String get altitude {
    return Intl.message(
      'Altitude',
      name: 'altitude',
      desc: 'GPS altitude measurement label',
      args: [],
    );
  }

  /// `Accuracy`
  String get accuracy {
    return Intl.message(
      'Accuracy',
      name: 'accuracy',
      desc: 'GPS accuracy measurement label',
      args: [],
    );
  }

  /// `Speed`
  String get speed {
    return Intl.message(
      'Speed',
      name: 'speed',
      desc: 'GPS speed measurement label',
      args: [],
    );
  }

  /// `Heading`
  String get heading {
    return Intl.message(
      'Heading',
      name: 'heading',
      desc: 'Compass heading measurement label',
      args: [],
    );
  }

  /// `Distance`
  String get distance {
    return Intl.message(
      'Distance',
      name: 'distance',
      desc: 'Distance measurement label',
      args: [],
    );
  }

  /// `Duration`
  String get duration {
    return Intl.message(
      'Duration',
      name: 'duration',
      desc: 'Time duration label',
      args: [],
    );
  }

  /// `Location permission is required to use this app`
  String get locationPermissionRequired {
    return Intl.message(
      'Location permission is required to use this app',
      name: 'locationPermissionRequired',
      desc: 'Message when location permission is needed',
      args: [],
    );
  }

  /// `Microphone permission is required for voice control`
  String get microphonePermissionRequired {
    return Intl.message(
      'Microphone permission is required for voice control',
      name: 'microphonePermissionRequired',
      desc: 'Message when microphone permission is needed for voice features',
      args: [],
    );
  }

  /// `Grant Permission`
  String get grantPermission {
    return Intl.message(
      'Grant Permission',
      name: 'grantPermission',
      desc: 'Button to grant app permissions',
      args: [],
    );
  }

  /// `Voice Commands Help`
  String get voiceCommandsHelp {
    return Intl.message(
      'Voice Commands Help',
      name: 'voiceCommandsHelp',
      desc: 'Title for voice commands help section',
      args: [],
    );
  }

  /// `Say 'Start tracking' to begin GPS tracking`
  String get sayStartTracking {
    return Intl.message(
      'Say \'Start tracking\' to begin GPS tracking',
      name: 'sayStartTracking',
      desc: 'Voice command instruction for starting tracking',
      args: [],
    );
  }

  /// `Say 'Stop tracking' to end GPS tracking`
  String get sayStopTracking {
    return Intl.message(
      'Say \'Stop tracking\' to end GPS tracking',
      name: 'sayStopTracking',
      desc: 'Voice command instruction for stopping tracking',
      args: [],
    );
  }

  /// `Say 'Add waypoint' to mark current location`
  String get sayAddWaypoint {
    return Intl.message(
      'Say \'Add waypoint\' to mark current location',
      name: 'sayAddWaypoint',
      desc: 'Voice command instruction for adding waypoint',
      args: [],
    );
  }

  /// `Say 'Show map' to view the map`
  String get sayShowMap {
    return Intl.message(
      'Say \'Show map\' to view the map',
      name: 'sayShowMap',
      desc: 'Voice command instruction for showing map',
      args: [],
    );
  }

  /// `Voice command recognized: {command}`
  String voiceCommandRecognized(String command) {
    return Intl.message(
      'Voice command recognized: $command',
      name: 'voiceCommandRecognized',
      desc: 'Confirmation message when voice command is recognized',
      args: [command],
    );
  }

  /// `GPS tracking started`
  String get trackingStarted {
    return Intl.message(
      'GPS tracking started',
      name: 'trackingStarted',
      desc: 'Announcement when tracking begins',
      args: [],
    );
  }

  /// `GPS tracking stopped`
  String get trackingStopped {
    return Intl.message(
      'GPS tracking stopped',
      name: 'trackingStopped',
      desc: 'Announcement when tracking ends',
      args: [],
    );
  }

  /// `Waypoint added at current location`
  String get waypointAdded {
    return Intl.message(
      'Waypoint added at current location',
      name: 'waypointAdded',
      desc: 'Announcement when waypoint is created',
      args: [],
    );
  }

  /// `Location updated: {latitude}, {longitude}`
  String locationUpdated(String latitude, String longitude) {
    return Intl.message(
      'Location updated: $latitude, $longitude',
      name: 'locationUpdated',
      desc: 'Announcement when GPS location changes',
      args: [latitude, longitude],
    );
  }

  /// `Compass heading: {degrees} degrees {direction}`
  String compassHeading(String degrees, String direction) {
    return Intl.message(
      'Compass heading: $degrees degrees $direction',
      name: 'compassHeading',
      desc: 'Compass heading announcement',
      args: [degrees, direction],
    );
  }

  /// `North`
  String get north {
    return Intl.message(
      'North',
      name: 'north',
      desc: 'Cardinal direction North',
      args: [],
    );
  }

  /// `South`
  String get south {
    return Intl.message(
      'South',
      name: 'south',
      desc: 'Cardinal direction South',
      args: [],
    );
  }

  /// `East`
  String get east {
    return Intl.message(
      'East',
      name: 'east',
      desc: 'Cardinal direction East',
      args: [],
    );
  }

  /// `West`
  String get west {
    return Intl.message(
      'West',
      name: 'west',
      desc: 'Cardinal direction West',
      args: [],
    );
  }

  /// `Northeast`
  String get northeast {
    return Intl.message(
      'Northeast',
      name: 'northeast',
      desc: 'Cardinal direction Northeast',
      args: [],
    );
  }

  /// `Northwest`
  String get northwest {
    return Intl.message(
      'Northwest',
      name: 'northwest',
      desc: 'Cardinal direction Northwest',
      args: [],
    );
  }

  /// `Southeast`
  String get southeast {
    return Intl.message(
      'Southeast',
      name: 'southeast',
      desc: 'Cardinal direction Southeast',
      args: [],
    );
  }

  /// `Southwest`
  String get southwest {
    return Intl.message(
      'Southwest',
      name: 'southwest',
      desc: 'Cardinal direction Southwest',
      args: [],
    );
  }

  /// `meters`
  String get meters {
    return Intl.message(
      'meters',
      name: 'meters',
      desc: 'Unit of measurement: meters',
      args: [],
    );
  }

  /// `kilometers`
  String get kilometers {
    return Intl.message(
      'kilometers',
      name: 'kilometers',
      desc: 'Unit of measurement: kilometers',
      args: [],
    );
  }

  /// `feet`
  String get feet {
    return Intl.message(
      'feet',
      name: 'feet',
      desc: 'Unit of measurement: feet',
      args: [],
    );
  }

  /// `miles`
  String get miles {
    return Intl.message(
      'miles',
      name: 'miles',
      desc: 'Unit of measurement: miles',
      args: [],
    );
  }

  /// `meters per second`
  String get metersPerSecond {
    return Intl.message(
      'meters per second',
      name: 'metersPerSecond',
      desc: 'Unit of measurement: meters per second',
      args: [],
    );
  }

  /// `kilometers per hour`
  String get kilometersPerHour {
    return Intl.message(
      'kilometers per hour',
      name: 'kilometersPerHour',
      desc: 'Unit of measurement: kilometers per hour',
      args: [],
    );
  }

  /// `miles per hour`
  String get milesPerHour {
    return Intl.message(
      'miles per hour',
      name: 'milesPerHour',
      desc: 'Unit of measurement: miles per hour',
      args: [],
    );
  }

  /// `Measurement Units`
  String get measurementUnits {
    return Intl.message(
      'Measurement Units',
      name: 'measurementUnits',
      desc: 'Settings section for measurement units',
      args: [],
    );
  }

  /// `Metric`
  String get metric {
    return Intl.message(
      'Metric',
      name: 'metric',
      desc: 'Metric measurement system',
      args: [],
    );
  }

  /// `Imperial`
  String get imperial {
    return Intl.message(
      'Imperial',
      name: 'imperial',
      desc: 'Imperial measurement system',
      args: [],
    );
  }

  /// `Date Format`
  String get dateFormat {
    return Intl.message(
      'Date Format',
      name: 'dateFormat',
      desc: 'Settings for date format',
      args: [],
    );
  }

  /// `Time Format`
  String get timeFormat {
    return Intl.message(
      'Time Format',
      name: 'timeFormat',
      desc: 'Settings for time format',
      args: [],
    );
  }

  /// `12 Hour`
  String get twelveHour {
    return Intl.message(
      '12 Hour',
      name: 'twelveHour',
      desc: '12-hour time format',
      args: [],
    );
  }

  /// `24 Hour`
  String get twentyFourHour {
    return Intl.message(
      '24 Hour',
      name: 'twentyFourHour',
      desc: '24-hour time format',
      args: [],
    );
  }

  /// `Regional Settings`
  String get regionalSettings {
    return Intl.message(
      'Regional Settings',
      name: 'regionalSettings',
      desc: 'Settings section for regional preferences',
      args: [],
    );
  }

  /// `Currency`
  String get currency {
    return Intl.message(
      'Currency',
      name: 'currency',
      desc: 'Currency settings',
      args: [],
    );
  }

  /// `Number Format`
  String get numberFormat {
    return Intl.message(
      'Number Format',
      name: 'numberFormat',
      desc: 'Number formatting settings',
      args: [],
    );
  }

  /// `Text Direction`
  String get textDirection {
    return Intl.message(
      'Text Direction',
      name: 'textDirection',
      desc: 'Text direction settings for RTL languages',
      args: [],
    );
  }

  /// `Left to Right`
  String get leftToRight {
    return Intl.message(
      'Left to Right',
      name: 'leftToRight',
      desc: 'Left-to-right text direction',
      args: [],
    );
  }

  /// `Right to Left`
  String get rightToLeft {
    return Intl.message(
      'Right to Left',
      name: 'rightToLeft',
      desc: 'Right-to-left text direction',
      args: [],
    );
  }

  /// `Font Scale`
  String get fontScale {
    return Intl.message(
      'Font Scale',
      name: 'fontScale',
      desc: 'Font scaling accessibility option',
      args: [],
    );
  }

  /// `Small`
  String get small {
    return Intl.message(
      'Small',
      name: 'small',
      desc: 'Small size option',
      args: [],
    );
  }

  /// `Normal`
  String get normal {
    return Intl.message(
      'Normal',
      name: 'normal',
      desc: 'Normal size option',
      args: [],
    );
  }

  /// `Large`
  String get large {
    return Intl.message(
      'Large',
      name: 'large',
      desc: 'Large size option',
      args: [],
    );
  }

  /// `Extra Large`
  String get extraLarge {
    return Intl.message(
      'Extra Large',
      name: 'extraLarge',
      desc: 'Extra large size option',
      args: [],
    );
  }

  /// `Color Filters`
  String get colorFilters {
    return Intl.message(
      'Color Filters',
      name: 'colorFilters',
      desc: 'Color filter accessibility options',
      args: [],
    );
  }

  /// `None`
  String get none {
    return Intl.message(
      'None',
      name: 'none',
      desc: 'No filter option',
      args: [],
    );
  }

  /// `Protanopia`
  String get protanopia {
    return Intl.message(
      'Protanopia',
      name: 'protanopia',
      desc: 'Color blindness filter for protanopia',
      args: [],
    );
  }

  /// `Deuteranopia`
  String get deuteranopia {
    return Intl.message(
      'Deuteranopia',
      name: 'deuteranopia',
      desc: 'Color blindness filter for deuteranopia',
      args: [],
    );
  }

  /// `Tritanopia`
  String get tritanopia {
    return Intl.message(
      'Tritanopia',
      name: 'tritanopia',
      desc: 'Color blindness filter for tritanopia',
      args: [],
    );
  }

  /// `Monochrome`
  String get monochrome {
    return Intl.message(
      'Monochrome',
      name: 'monochrome',
      desc: 'Monochrome color filter',
      args: [],
    );
  }

  /// `Focus Indicator`
  String get focusIndicator {
    return Intl.message(
      'Focus Indicator',
      name: 'focusIndicator',
      desc: 'Focus indicator accessibility option',
      args: [],
    );
  }

  /// `Enhanced Focus`
  String get enhancedFocus {
    return Intl.message(
      'Enhanced Focus',
      name: 'enhancedFocus',
      desc: 'Enhanced focus indicator option',
      args: [],
    );
  }

  /// `Keyboard Navigation`
  String get keyboardNavigation {
    return Intl.message(
      'Keyboard Navigation',
      name: 'keyboardNavigation',
      desc: 'Keyboard navigation accessibility option',
      args: [],
    );
  }

  /// `Enabled`
  String get enabled {
    return Intl.message(
      'Enabled',
      name: 'enabled',
      desc: 'Enabled state',
      args: [],
    );
  }

  /// `Disabled`
  String get disabled {
    return Intl.message(
      'Disabled',
      name: 'disabled',
      desc: 'Disabled state',
      args: [],
    );
  }

  /// `Tap to activate`
  String get tapToActivate {
    return Intl.message(
      'Tap to activate',
      name: 'tapToActivate',
      desc: 'Accessibility hint for tappable elements',
      args: [],
    );
  }

  /// `Double tap to activate`
  String get doubleTabToActivate {
    return Intl.message(
      'Double tap to activate',
      name: 'doubleTabToActivate',
      desc: 'Accessibility hint for double-tap activation',
      args: [],
    );
  }

  /// `Swipe to navigate`
  String get swipeToNavigate {
    return Intl.message(
      'Swipe to navigate',
      name: 'swipeToNavigate',
      desc: 'Accessibility hint for swipe navigation',
      args: [],
    );
  }

  /// `Loading`
  String get loading {
    return Intl.message(
      'Loading',
      name: 'loading',
      desc: 'Loading state announcement',
      args: [],
    );
  }

  /// `Error`
  String get error {
    return Intl.message(
      'Error',
      name: 'error',
      desc: 'Error state announcement',
      args: [],
    );
  }

  /// `Success`
  String get success {
    return Intl.message(
      'Success',
      name: 'success',
      desc: 'Success state announcement',
      args: [],
    );
  }

  /// `Warning`
  String get warning {
    return Intl.message(
      'Warning',
      name: 'warning',
      desc: 'Warning state announcement',
      args: [],
    );
  }

  /// `Information`
  String get information {
    return Intl.message(
      'Information',
      name: 'information',
      desc: 'Information state announcement',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'ar'),
      Locale.fromSubtags(languageCode: 'es'),
      Locale.fromSubtags(languageCode: 'fr'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
