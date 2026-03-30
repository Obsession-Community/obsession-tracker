import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive internationalization service providing language support,
/// cultural adaptations, and regional preferences management.
class InternationalizationService extends ChangeNotifier {
  factory InternationalizationService() => _instance;
  InternationalizationService._internal();
  static final InternationalizationService _instance =
      InternationalizationService._internal();

  // Current locale and supported locales
  Locale _currentLocale = const Locale('en', 'US');
  final List<Locale> _supportedLocales = const [
    Locale('en', 'US'), // English (US)
    Locale('es', 'ES'), // Spanish (Spain)
    Locale('fr', 'FR'), // French (France)
    Locale('ar', 'SA'), // Arabic (Saudi Arabia)
    Locale('de', 'DE'), // German (Germany)
    Locale('ja', 'JP'), // Japanese (Japan)
    Locale('zh', 'CN'), // Chinese (China)
    Locale('pt', 'BR'), // Portuguese (Brazil)
    Locale('ru', 'RU'), // Russian (Russia)
    Locale('hi', 'IN'), // Hindi (India)
  ];

  // Regional and cultural preferences
  String _measurementSystem = 'imperial'; // metric, imperial
  String _dateFormat = 'default'; // default, us, european, iso
  String _timeFormat = '24h'; // 12h, 24h
  String _numberFormat = 'default'; // default, european, indian
  String _currency = 'USD';
  ui.TextDirection _textDirection = ui.TextDirection.ltr;

  // Cultural adaptations
  bool _useLocalizedUnits = true;
  bool _useLocalizedDateFormats = true;
  bool _useLocalizedNumberFormats = true;
  bool _respectRtlLanguages = true;

  // Getters
  Locale get currentLocale => _currentLocale;
  List<Locale> get supportedLocales => _supportedLocales;
  String get measurementSystem => _measurementSystem;
  String get dateFormat => _dateFormat;
  String get timeFormat => _timeFormat;
  String get numberFormat => _numberFormat;
  String get currency => _currency;
  ui.TextDirection get textDirection => _textDirection;
  bool get useLocalizedUnits => _useLocalizedUnits;
  bool get useLocalizedDateFormats => _useLocalizedDateFormats;
  bool get useLocalizedNumberFormats => _useLocalizedNumberFormats;
  bool get respectRtlLanguages => _respectRtlLanguages;

  /// Update text direction based on current locale
  void _updateTextDirection() {
    if (_respectRtlLanguages) {
      final rtlLanguages = ['ar', 'he', 'fa', 'ur'];
      _textDirection = rtlLanguages.contains(_currentLocale.languageCode)
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr;
    } else {
      _textDirection = ui.TextDirection.ltr;
    }
  }

  /// Initialize the internationalization service
  Future<void> initialize() async {
    await _loadPreferences();
    await _configureLocale();
  }

  /// Load internationalization preferences from storage
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load locale
      final languageCode = prefs.getString('i18n_language') ?? 'en';
      final countryCode = prefs.getString('i18n_country') ?? 'US';
      _currentLocale = Locale(languageCode, countryCode);

      // Load regional preferences
      _measurementSystem =
          prefs.getString('i18n_measurement_system') ?? 'imperial';
      _dateFormat = prefs.getString('i18n_date_format') ?? 'default';
      _timeFormat = prefs.getString('i18n_time_format') ?? '24h';
      _numberFormat = prefs.getString('i18n_number_format') ?? 'default';
      _currency = prefs.getString('i18n_currency') ?? 'USD';

      // Load cultural adaptations
      _useLocalizedUnits = prefs.getBool('i18n_localized_units') ?? true;
      _useLocalizedDateFormats = prefs.getBool('i18n_localized_dates') ?? true;
      _useLocalizedNumberFormats =
          prefs.getBool('i18n_localized_numbers') ?? true;
      _respectRtlLanguages = prefs.getBool('i18n_respect_rtl') ?? true;

      // Set text direction based on locale
      _updateTextDirection();

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load internationalization preferences: $e');
    }
  }

  /// Save internationalization preferences to storage
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save locale
      await prefs.setString('i18n_language', _currentLocale.languageCode);
      await prefs.setString('i18n_country', _currentLocale.countryCode ?? '');

      // Save regional preferences
      await prefs.setString('i18n_measurement_system', _measurementSystem);
      await prefs.setString('i18n_date_format', _dateFormat);
      await prefs.setString('i18n_time_format', _timeFormat);
      await prefs.setString('i18n_number_format', _numberFormat);
      await prefs.setString('i18n_currency', _currency);

      // Save cultural adaptations
      await prefs.setBool('i18n_localized_units', _useLocalizedUnits);
      await prefs.setBool('i18n_localized_dates', _useLocalizedDateFormats);
      await prefs.setBool('i18n_localized_numbers', _useLocalizedNumberFormats);
      await prefs.setBool('i18n_respect_rtl', _respectRtlLanguages);
    } catch (e) {
      debugPrint('Failed to save internationalization preferences: $e');
    }
  }

  /// Configure locale-specific settings
  Future<void> _configureLocale() async {
    try {
      // Set default Intl locale
      Intl.defaultLocale = _currentLocale.toString();

      // Configure locale-specific defaults
      _configureLocaleDefaults();
    } catch (e) {
      debugPrint('Failed to configure locale: $e');
    }
  }

  /// Configure locale-specific default values
  void _configureLocaleDefaults() {
    switch (_currentLocale.languageCode) {
      case 'en':
        if (_currentLocale.countryCode == 'US') {
          _measurementSystem = 'imperial';
          _dateFormat = 'us';
          _timeFormat = '12h';
          _currency = 'USD';
        } else {
          _measurementSystem = 'metric';
          _dateFormat = 'european';
          _timeFormat = '24h';
          _currency = 'GBP';
        }
        break;
      case 'es':
        _measurementSystem = 'metric';
        _dateFormat = 'european';
        _timeFormat = '24h';
        _currency = 'EUR';
        break;
      case 'fr':
        _measurementSystem = 'metric';
        _dateFormat = 'european';
        _timeFormat = '24h';
        _currency = 'EUR';
        break;
      case 'ar':
        _measurementSystem = 'metric';
        _dateFormat = 'default';
        _timeFormat = '12h';
        _currency = 'SAR';
        break;
      case 'de':
        _measurementSystem = 'metric';
        _dateFormat = 'european';
        _timeFormat = '24h';
        _currency = 'EUR';
        break;
      case 'ja':
        _measurementSystem = 'metric';
        _dateFormat = 'iso';
        _timeFormat = '24h';
        _currency = 'JPY';
        break;
      case 'zh':
        _measurementSystem = 'metric';
        _dateFormat = 'iso';
        _timeFormat = '24h';
        _currency = 'CNY';
        break;
      case 'pt':
        _measurementSystem = 'metric';
        _dateFormat = 'european';
        _timeFormat = '24h';
        _currency = 'BRL';
        break;
      case 'ru':
        _measurementSystem = 'metric';
        _dateFormat = 'european';
        _timeFormat = '24h';
        _currency = 'RUB';
        break;
      case 'hi':
        _measurementSystem = 'metric';
        _dateFormat = 'default';
        _timeFormat = '12h';
        _currency = 'INR';
        _numberFormat = 'indian';
        break;
    }

    _updateTextDirection();
  }

  /// Set current locale
  Future<void> setLocale(Locale locale) async {
    if (_supportedLocales.contains(locale)) {
      _currentLocale = locale;
      await _configureLocale();
      _configureLocaleDefaults();
      await _savePreferences();
      notifyListeners();
    }
  }

  /// Set measurement system
  Future<void> setMeasurementSystem(String system) async {
    if (['metric', 'imperial'].contains(system)) {
      _measurementSystem = system;
      await _savePreferences();
      notifyListeners();
    }
  }

  /// Set date format
  Future<void> setDateFormat(String format) async {
    if (['default', 'us', 'european', 'iso'].contains(format)) {
      _dateFormat = format;
      await _savePreferences();
      notifyListeners();
    }
  }

  /// Set time format
  Future<void> setTimeFormat(String format) async {
    if (['12h', '24h'].contains(format)) {
      _timeFormat = format;
      await _savePreferences();
      notifyListeners();
    }
  }

  /// Set number format
  Future<void> setNumberFormat(String format) async {
    if (['default', 'european', 'indian'].contains(format)) {
      _numberFormat = format;
      await _savePreferences();
      notifyListeners();
    }
  }

  /// Set currency
  Future<void> setCurrency(String currencyCode) async {
    _currency = currencyCode;
    await _savePreferences();
    notifyListeners();
  }

  /// Format distance based on measurement system and locale.
  /// Automatically switches units at sensible thresholds:
  /// - Imperial: feet → miles at 0.1 miles (528 feet)
  /// - Metric: meters → km at 100 meters (0.1 km)
  String formatDistance(double meters) {
    // Conversion constants
    const double metersPerMile = 1609.34;
    const double feetPerMeter = 3.28084;
    const double milesThreshold = 0.1; // Switch to miles at 0.1 mi
    const double kmThreshold = 0.1; // Switch to km at 0.1 km

    if (_measurementSystem == 'imperial') {
      final miles = meters / metersPerMile;
      if (miles < milesThreshold) {
        // Show in feet for short distances
        final feet = meters * feetPerMeter;
        return '${feet.toStringAsFixed(0)} ft';
      } else {
        // Show in miles for longer distances
        return '${miles.toStringAsFixed(2)} mi';
      }
    } else {
      final kilometers = meters / 1000;
      if (kilometers < kmThreshold) {
        // Show in meters for short distances
        return '${meters.toStringAsFixed(0)} m';
      } else {
        // Show in kilometers for longer distances
        return '${kilometers.toStringAsFixed(2)} km';
      }
    }
  }

  /// Format speed based on measurement system and locale
  String formatSpeed(double metersPerSecond) {
    if (_measurementSystem == 'imperial') {
      final mph = metersPerSecond * 2.237;
      return '${mph.toStringAsFixed(1)} mph';
    } else {
      final kmh = metersPerSecond * 3.6;
      return '${kmh.toStringAsFixed(1)} km/h';
    }
  }

  /// Format altitude based on measurement system and locale
  String formatAltitude(double meters) {
    if (_measurementSystem == 'imperial') {
      final feet = meters * 3.28084;
      return '${feet.toStringAsFixed(0)} ft';
    } else {
      return '${meters.toStringAsFixed(0)} m';
    }
  }

  /// Format date based on locale and preferences
  String formatDate(DateTime date) {
    try {
      switch (_dateFormat) {
        case 'us':
          return DateFormat('MM/dd/yyyy', _currentLocale.toString())
              .format(date);
        case 'european':
          return DateFormat('dd/MM/yyyy', _currentLocale.toString())
              .format(date);
        case 'iso':
          return DateFormat('yyyy-MM-dd', _currentLocale.toString())
              .format(date);
        default:
          return DateFormat.yMd(_currentLocale.toString()).format(date);
      }
    } catch (e) {
      return DateFormat.yMd().format(date);
    }
  }

  /// Format time based on locale and preferences
  String formatTime(DateTime time) {
    try {
      if (_timeFormat == '12h') {
        return DateFormat.jm(_currentLocale.toString()).format(time);
      } else {
        return DateFormat.Hm(_currentLocale.toString()).format(time);
      }
    } catch (e) {
      return DateFormat.Hm().format(time);
    }
  }

  /// Format number based on locale and preferences
  String formatNumber(double number) {
    try {
      switch (_numberFormat) {
        case 'european':
          return NumberFormat('#,##0.00', 'de').format(number);
        case 'indian':
          return NumberFormat('#,##,##0.00', 'hi_IN').format(number);
        default:
          return NumberFormat('#,##0.00', _currentLocale.toString())
              .format(number);
      }
    } catch (e) {
      return number.toStringAsFixed(2);
    }
  }

  /// Format currency based on locale and preferences
  String formatCurrency(double amount) {
    try {
      return NumberFormat.currency(
        locale: _currentLocale.toString(),
        symbol: _getCurrencySymbol(),
      ).format(amount);
    } catch (e) {
      return '${_getCurrencySymbol()}${amount.toStringAsFixed(2)}';
    }
  }

  /// Get currency symbol for current currency
  String _getCurrencySymbol() {
    switch (_currency) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CNY':
        return '¥';
      case 'INR':
        return '₹';
      case 'BRL':
        return r'R$';
      case 'RUB':
        return '₽';
      case 'SAR':
        return 'ر.س';
      default:
        return _currency;
    }
  }

  /// Get localized language name
  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'ar':
        return 'العربية';
      case 'de':
        return 'Deutsch';
      case 'ja':
        return '日本語';
      case 'zh':
        return '中文';
      case 'pt':
        return 'Português';
      case 'ru':
        return 'Русский';
      case 'hi':
        return 'हिन्दी';
      default:
        return languageCode.toUpperCase();
    }
  }

  /// Set measurement system synchronously (for testing)
  /// This bypasses persistence for unit tests
  @visibleForTesting
  void setMeasurementSystemForTesting(String system) {
    if (['metric', 'imperial'].contains(system)) {
      _measurementSystem = system;
    }
  }

  /// Check if current locale is RTL
  bool get isRtl => _textDirection == ui.TextDirection.rtl;

  /// Get appropriate text alignment for current locale
  TextAlign get textAlign => isRtl ? TextAlign.right : TextAlign.left;

  /// Get appropriate edge insets for current locale
  EdgeInsets getLocalizedPadding(EdgeInsets padding) {
    if (isRtl) {
      return EdgeInsets.fromLTRB(
        padding.right,
        padding.top,
        padding.left,
        padding.bottom,
      );
    }
    return padding;
  }

  /// Get appropriate border radius for current locale
  BorderRadius getLocalizedBorderRadius(BorderRadius radius) {
    if (isRtl) {
      return BorderRadius.only(
        topLeft: radius.topRight,
        topRight: radius.topLeft,
        bottomLeft: radius.bottomRight,
        bottomRight: radius.bottomLeft,
      );
    }
    return radius;
  }
}

/// Provider for internationalization service
final internationalizationServiceProvider =
    Provider<InternationalizationService>((ref) => InternationalizationService());
