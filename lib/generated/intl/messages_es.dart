// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a es locale. All the
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
  String get localeName => 'es';

  static String m0(degrees, direction) =>
      "Rumbo de brújula: ${degrees} grados ${direction}";

  static String m1(latitude, longitude) =>
      "Ubicación actualizada: ${latitude}, ${longitude}";

  static String m2(command) => "Comando de voz reconocido: ${command}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "accessibility": MessageLookupByLibrary.simpleMessage("Accesibilidad"),
    "accuracy": MessageLookupByLibrary.simpleMessage("Precisión"),
    "addWaypoint": MessageLookupByLibrary.simpleMessage(
      "Agregar punto de referencia",
    ),
    "altitude": MessageLookupByLibrary.simpleMessage("Altitud"),
    "appDescription": MessageLookupByLibrary.simpleMessage(
      "Tu brújula cuando nada cuadra. Una aplicación de rastreo GPS que prioriza la privacidad para cazadores de tesoros, exploradores y aventureros.",
    ),
    "appTitle": MessageLookupByLibrary.simpleMessage("Rastreador de Obsession"),
    "audioFeedback": MessageLookupByLibrary.simpleMessage(
      "Retroalimentación de audio",
    ),
    "colorFilters": MessageLookupByLibrary.simpleMessage("Filtros de color"),
    "compassHeading": m0,
    "currency": MessageLookupByLibrary.simpleMessage("Moneda"),
    "currentLocation": MessageLookupByLibrary.simpleMessage("Ubicación actual"),
    "dateFormat": MessageLookupByLibrary.simpleMessage("Formato de fecha"),
    "deuteranopia": MessageLookupByLibrary.simpleMessage("Deuteranopia"),
    "disabled": MessageLookupByLibrary.simpleMessage("Deshabilitado"),
    "distance": MessageLookupByLibrary.simpleMessage("Distancia"),
    "doubleTabToActivate": MessageLookupByLibrary.simpleMessage(
      "Toca dos veces para activar",
    ),
    "duration": MessageLookupByLibrary.simpleMessage("Duración"),
    "east": MessageLookupByLibrary.simpleMessage("Este"),
    "enabled": MessageLookupByLibrary.simpleMessage("Habilitado"),
    "enhancedFocus": MessageLookupByLibrary.simpleMessage("Enfoque mejorado"),
    "error": MessageLookupByLibrary.simpleMessage("Error"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("Extra grande"),
    "feet": MessageLookupByLibrary.simpleMessage("pies"),
    "focusIndicator": MessageLookupByLibrary.simpleMessage(
      "Indicador de enfoque",
    ),
    "fontScale": MessageLookupByLibrary.simpleMessage("Escala de fuente"),
    "grantPermission": MessageLookupByLibrary.simpleMessage("Conceder permiso"),
    "heading": MessageLookupByLibrary.simpleMessage("Rumbo"),
    "highContrast": MessageLookupByLibrary.simpleMessage("Alto contraste"),
    "home": MessageLookupByLibrary.simpleMessage("Inicio"),
    "imperial": MessageLookupByLibrary.simpleMessage("Imperial"),
    "information": MessageLookupByLibrary.simpleMessage("Información"),
    "keyboardNavigation": MessageLookupByLibrary.simpleMessage(
      "Navegación por teclado",
    ),
    "kilometers": MessageLookupByLibrary.simpleMessage("kilómetros"),
    "kilometersPerHour": MessageLookupByLibrary.simpleMessage(
      "kilómetros por hora",
    ),
    "language": MessageLookupByLibrary.simpleMessage("Idioma"),
    "large": MessageLookupByLibrary.simpleMessage("Grande"),
    "largeText": MessageLookupByLibrary.simpleMessage("Texto grande"),
    "latitude": MessageLookupByLibrary.simpleMessage("Latitud"),
    "leftToRight": MessageLookupByLibrary.simpleMessage("Izquierda a derecha"),
    "loading": MessageLookupByLibrary.simpleMessage("Cargando"),
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Se requiere permiso de ubicación para usar esta aplicación",
    ),
    "locationUpdated": m1,
    "longitude": MessageLookupByLibrary.simpleMessage("Longitud"),
    "map": MessageLookupByLibrary.simpleMessage("Mapa"),
    "measurementUnits": MessageLookupByLibrary.simpleMessage(
      "Unidades de medida",
    ),
    "meters": MessageLookupByLibrary.simpleMessage("metros"),
    "metersPerSecond": MessageLookupByLibrary.simpleMessage(
      "metros por segundo",
    ),
    "metric": MessageLookupByLibrary.simpleMessage("Métrico"),
    "microphonePermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Se requiere permiso de micrófono para el control por voz",
    ),
    "miles": MessageLookupByLibrary.simpleMessage("millas"),
    "milesPerHour": MessageLookupByLibrary.simpleMessage("millas por hora"),
    "monochrome": MessageLookupByLibrary.simpleMessage("Monocromo"),
    "none": MessageLookupByLibrary.simpleMessage("Ninguno"),
    "normal": MessageLookupByLibrary.simpleMessage("Normal"),
    "north": MessageLookupByLibrary.simpleMessage("Norte"),
    "northeast": MessageLookupByLibrary.simpleMessage("Noreste"),
    "northwest": MessageLookupByLibrary.simpleMessage("Noroeste"),
    "numberFormat": MessageLookupByLibrary.simpleMessage("Formato de números"),
    "protanopia": MessageLookupByLibrary.simpleMessage("Protanopia"),
    "regionalSettings": MessageLookupByLibrary.simpleMessage(
      "Configuración regional",
    ),
    "rightToLeft": MessageLookupByLibrary.simpleMessage("Derecha a izquierda"),
    "sayAddWaypoint": MessageLookupByLibrary.simpleMessage(
      "Di \'Agregar punto de referencia\' para marcar la ubicación actual",
    ),
    "sayShowMap": MessageLookupByLibrary.simpleMessage(
      "Di \'Mostrar mapa\' para ver el mapa",
    ),
    "sayStartTracking": MessageLookupByLibrary.simpleMessage(
      "Di \'Iniciar rastreo\' para comenzar el rastreo GPS",
    ),
    "sayStopTracking": MessageLookupByLibrary.simpleMessage(
      "Di \'Detener rastreo\' para finalizar el rastreo GPS",
    ),
    "screenReader": MessageLookupByLibrary.simpleMessage(
      "Soporte para lector de pantalla",
    ),
    "settings": MessageLookupByLibrary.simpleMessage("Configuración"),
    "small": MessageLookupByLibrary.simpleMessage("Pequeño"),
    "south": MessageLookupByLibrary.simpleMessage("Sur"),
    "southeast": MessageLookupByLibrary.simpleMessage("Sureste"),
    "southwest": MessageLookupByLibrary.simpleMessage("Suroeste"),
    "speed": MessageLookupByLibrary.simpleMessage("Velocidad"),
    "startTracking": MessageLookupByLibrary.simpleMessage("Iniciar rastreo"),
    "stopTracking": MessageLookupByLibrary.simpleMessage("Detener rastreo"),
    "success": MessageLookupByLibrary.simpleMessage("Éxito"),
    "swipeToNavigate": MessageLookupByLibrary.simpleMessage(
      "Desliza para navegar",
    ),
    "tapToActivate": MessageLookupByLibrary.simpleMessage("Toca para activar"),
    "textDirection": MessageLookupByLibrary.simpleMessage(
      "Dirección del texto",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("Tema"),
    "timeFormat": MessageLookupByLibrary.simpleMessage("Formato de hora"),
    "tracking": MessageLookupByLibrary.simpleMessage("Rastreo"),
    "trackingStarted": MessageLookupByLibrary.simpleMessage(
      "Rastreo GPS iniciado",
    ),
    "trackingStopped": MessageLookupByLibrary.simpleMessage(
      "Rastreo GPS detenido",
    ),
    "tritanopia": MessageLookupByLibrary.simpleMessage("Tritanopia"),
    "twelveHour": MessageLookupByLibrary.simpleMessage("12 horas"),
    "twentyFourHour": MessageLookupByLibrary.simpleMessage("24 horas"),
    "voiceCommandRecognized": m2,
    "voiceCommandsHelp": MessageLookupByLibrary.simpleMessage(
      "Ayuda de comandos de voz",
    ),
    "voiceControl": MessageLookupByLibrary.simpleMessage("Control por voz"),
    "warning": MessageLookupByLibrary.simpleMessage("Advertencia"),
    "waypointAdded": MessageLookupByLibrary.simpleMessage(
      "Punto de referencia agregado en la ubicación actual",
    ),
    "waypoints": MessageLookupByLibrary.simpleMessage("Puntos de referencia"),
    "west": MessageLookupByLibrary.simpleMessage("Oeste"),
  };
}
