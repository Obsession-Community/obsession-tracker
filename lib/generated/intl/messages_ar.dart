// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ar locale. All the
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
  String get localeName => 'ar';

  static String m0(degrees, direction) =>
      "اتجاه البوصلة: ${degrees} درجة ${direction}";

  static String m1(latitude, longitude) =>
      "تم تحديث الموقع: ${latitude}، ${longitude}";

  static String m2(command) => "تم التعرف على الأمر الصوتي: ${command}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "accessibility": MessageLookupByLibrary.simpleMessage("إمكانية الوصول"),
    "accuracy": MessageLookupByLibrary.simpleMessage("الدقة"),
    "addWaypoint": MessageLookupByLibrary.simpleMessage("إضافة نقطة طريق"),
    "altitude": MessageLookupByLibrary.simpleMessage("الارتفاع"),
    "appDescription": MessageLookupByLibrary.simpleMessage(
      "بوصلتك عندما لا يتطابق شيء. تطبيق تتبع GPS يركز على الخصوصية للباحثين عن الكنوز والمستكشفين والمغامرين.",
    ),
    "appTitle": MessageLookupByLibrary.simpleMessage("متتبع أرض العجائب"),
    "audioFeedback": MessageLookupByLibrary.simpleMessage(
      "التغذية الراجعة الصوتية",
    ),
    "colorFilters": MessageLookupByLibrary.simpleMessage("مرشحات الألوان"),
    "compassHeading": m0,
    "currency": MessageLookupByLibrary.simpleMessage("العملة"),
    "currentLocation": MessageLookupByLibrary.simpleMessage("الموقع الحالي"),
    "dateFormat": MessageLookupByLibrary.simpleMessage("تنسيق التاريخ"),
    "deuteranopia": MessageLookupByLibrary.simpleMessage("عمى الألوان الأخضر"),
    "disabled": MessageLookupByLibrary.simpleMessage("معطل"),
    "distance": MessageLookupByLibrary.simpleMessage("المسافة"),
    "doubleTabToActivate": MessageLookupByLibrary.simpleMessage(
      "اضغط مرتين للتفعيل",
    ),
    "duration": MessageLookupByLibrary.simpleMessage("المدة"),
    "east": MessageLookupByLibrary.simpleMessage("شرق"),
    "enabled": MessageLookupByLibrary.simpleMessage("مفعل"),
    "enhancedFocus": MessageLookupByLibrary.simpleMessage("تركيز محسن"),
    "error": MessageLookupByLibrary.simpleMessage("خطأ"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("كبير جداً"),
    "feet": MessageLookupByLibrary.simpleMessage("قدم"),
    "focusIndicator": MessageLookupByLibrary.simpleMessage("مؤشر التركيز"),
    "fontScale": MessageLookupByLibrary.simpleMessage("مقياس الخط"),
    "grantPermission": MessageLookupByLibrary.simpleMessage("منح الإذن"),
    "heading": MessageLookupByLibrary.simpleMessage("الاتجاه"),
    "highContrast": MessageLookupByLibrary.simpleMessage("تباين عالي"),
    "home": MessageLookupByLibrary.simpleMessage("الرئيسية"),
    "imperial": MessageLookupByLibrary.simpleMessage("إمبراطوري"),
    "information": MessageLookupByLibrary.simpleMessage("معلومات"),
    "keyboardNavigation": MessageLookupByLibrary.simpleMessage(
      "التنقل بلوحة المفاتيح",
    ),
    "kilometers": MessageLookupByLibrary.simpleMessage("كيلومتر"),
    "kilometersPerHour": MessageLookupByLibrary.simpleMessage(
      "كيلومتر في الساعة",
    ),
    "language": MessageLookupByLibrary.simpleMessage("اللغة"),
    "large": MessageLookupByLibrary.simpleMessage("كبير"),
    "largeText": MessageLookupByLibrary.simpleMessage("نص كبير"),
    "latitude": MessageLookupByLibrary.simpleMessage("خط العرض"),
    "leftToRight": MessageLookupByLibrary.simpleMessage("من اليسار إلى اليمين"),
    "loading": MessageLookupByLibrary.simpleMessage("جاري التحميل"),
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "مطلوب إذن الموقع لاستخدام هذا التطبيق",
    ),
    "locationUpdated": m1,
    "longitude": MessageLookupByLibrary.simpleMessage("خط الطول"),
    "map": MessageLookupByLibrary.simpleMessage("الخريطة"),
    "measurementUnits": MessageLookupByLibrary.simpleMessage("وحدات القياس"),
    "meters": MessageLookupByLibrary.simpleMessage("متر"),
    "metersPerSecond": MessageLookupByLibrary.simpleMessage("متر في الثانية"),
    "metric": MessageLookupByLibrary.simpleMessage("متري"),
    "microphonePermissionRequired": MessageLookupByLibrary.simpleMessage(
      "مطلوب إذن الميكروفون للتحكم الصوتي",
    ),
    "miles": MessageLookupByLibrary.simpleMessage("ميل"),
    "milesPerHour": MessageLookupByLibrary.simpleMessage("ميل في الساعة"),
    "monochrome": MessageLookupByLibrary.simpleMessage("أحادي اللون"),
    "none": MessageLookupByLibrary.simpleMessage("لا شيء"),
    "normal": MessageLookupByLibrary.simpleMessage("عادي"),
    "north": MessageLookupByLibrary.simpleMessage("شمال"),
    "northeast": MessageLookupByLibrary.simpleMessage("شمال شرق"),
    "northwest": MessageLookupByLibrary.simpleMessage("شمال غرب"),
    "numberFormat": MessageLookupByLibrary.simpleMessage("تنسيق الأرقام"),
    "protanopia": MessageLookupByLibrary.simpleMessage("عمى الألوان الأحمر"),
    "regionalSettings": MessageLookupByLibrary.simpleMessage(
      "الإعدادات الإقليمية",
    ),
    "rightToLeft": MessageLookupByLibrary.simpleMessage("من اليمين إلى اليسار"),
    "sayAddWaypoint": MessageLookupByLibrary.simpleMessage(
      "قل \'إضافة نقطة طريق\' لتحديد الموقع الحالي",
    ),
    "sayShowMap": MessageLookupByLibrary.simpleMessage(
      "قل \'إظهار الخريطة\' لعرض الخريطة",
    ),
    "sayStartTracking": MessageLookupByLibrary.simpleMessage(
      "قل \'بدء التتبع\' لبدء تتبع GPS",
    ),
    "sayStopTracking": MessageLookupByLibrary.simpleMessage(
      "قل \'إيقاف التتبع\' لإنهاء تتبع GPS",
    ),
    "screenReader": MessageLookupByLibrary.simpleMessage("دعم قارئ الشاشة"),
    "settings": MessageLookupByLibrary.simpleMessage("الإعدادات"),
    "small": MessageLookupByLibrary.simpleMessage("صغير"),
    "south": MessageLookupByLibrary.simpleMessage("جنوب"),
    "southeast": MessageLookupByLibrary.simpleMessage("جنوب شرق"),
    "southwest": MessageLookupByLibrary.simpleMessage("جنوب غرب"),
    "speed": MessageLookupByLibrary.simpleMessage("السرعة"),
    "startTracking": MessageLookupByLibrary.simpleMessage("بدء التتبع"),
    "stopTracking": MessageLookupByLibrary.simpleMessage("إيقاف التتبع"),
    "success": MessageLookupByLibrary.simpleMessage("نجح"),
    "swipeToNavigate": MessageLookupByLibrary.simpleMessage("اسحب للتنقل"),
    "tapToActivate": MessageLookupByLibrary.simpleMessage("اضغط للتفعيل"),
    "textDirection": MessageLookupByLibrary.simpleMessage("اتجاه النص"),
    "theme": MessageLookupByLibrary.simpleMessage("المظهر"),
    "timeFormat": MessageLookupByLibrary.simpleMessage("تنسيق الوقت"),
    "tracking": MessageLookupByLibrary.simpleMessage("التتبع"),
    "trackingStarted": MessageLookupByLibrary.simpleMessage("تم بدء تتبع GPS"),
    "trackingStopped": MessageLookupByLibrary.simpleMessage(
      "تم إيقاف تتبع GPS",
    ),
    "tritanopia": MessageLookupByLibrary.simpleMessage("عمى الألوان الأزرق"),
    "twelveHour": MessageLookupByLibrary.simpleMessage("12 ساعة"),
    "twentyFourHour": MessageLookupByLibrary.simpleMessage("24 ساعة"),
    "voiceCommandRecognized": m2,
    "voiceCommandsHelp": MessageLookupByLibrary.simpleMessage(
      "مساعدة الأوامر الصوتية",
    ),
    "voiceControl": MessageLookupByLibrary.simpleMessage("التحكم الصوتي"),
    "warning": MessageLookupByLibrary.simpleMessage("تحذير"),
    "waypointAdded": MessageLookupByLibrary.simpleMessage(
      "تمت إضافة نقطة طريق في الموقع الحالي",
    ),
    "waypoints": MessageLookupByLibrary.simpleMessage("نقاط الطريق"),
    "west": MessageLookupByLibrary.simpleMessage("غرب"),
  };
}
