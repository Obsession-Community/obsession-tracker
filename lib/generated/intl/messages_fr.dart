// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a fr locale. All the
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
  String get localeName => 'fr';

  static String m0(degrees, direction) =>
      "Cap de la boussole : ${degrees} degrés ${direction}";

  static String m1(latitude, longitude) =>
      "Position mise à jour : ${latitude}, ${longitude}";

  static String m2(command) => "Commande vocale reconnue : ${command}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "accessibility": MessageLookupByLibrary.simpleMessage("Accessibilité"),
    "accuracy": MessageLookupByLibrary.simpleMessage("Précision"),
    "addWaypoint": MessageLookupByLibrary.simpleMessage(
      "Ajouter un point de repère",
    ),
    "altitude": MessageLookupByLibrary.simpleMessage("Altitude"),
    "appDescription": MessageLookupByLibrary.simpleMessage(
      "Votre boussole quand rien ne s\'additionne. Une application de suivi GPS axée sur la confidentialité pour les chasseurs de trésors, explorateurs et aventuriers.",
    ),
    "appTitle": MessageLookupByLibrary.simpleMessage("Traqueur de Obsession"),
    "audioFeedback": MessageLookupByLibrary.simpleMessage("Retour audio"),
    "colorFilters": MessageLookupByLibrary.simpleMessage("Filtres de couleur"),
    "compassHeading": m0,
    "currency": MessageLookupByLibrary.simpleMessage("Devise"),
    "currentLocation": MessageLookupByLibrary.simpleMessage(
      "Position actuelle",
    ),
    "dateFormat": MessageLookupByLibrary.simpleMessage("Format de date"),
    "deuteranopia": MessageLookupByLibrary.simpleMessage("Deutéranopie"),
    "disabled": MessageLookupByLibrary.simpleMessage("Désactivé"),
    "distance": MessageLookupByLibrary.simpleMessage("Distance"),
    "doubleTabToActivate": MessageLookupByLibrary.simpleMessage(
      "Appuyez deux fois pour activer",
    ),
    "duration": MessageLookupByLibrary.simpleMessage("Durée"),
    "east": MessageLookupByLibrary.simpleMessage("Est"),
    "enabled": MessageLookupByLibrary.simpleMessage("Activé"),
    "enhancedFocus": MessageLookupByLibrary.simpleMessage("Focus amélioré"),
    "error": MessageLookupByLibrary.simpleMessage("Erreur"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("Très grand"),
    "feet": MessageLookupByLibrary.simpleMessage("pieds"),
    "focusIndicator": MessageLookupByLibrary.simpleMessage(
      "Indicateur de focus",
    ),
    "fontScale": MessageLookupByLibrary.simpleMessage("Échelle de police"),
    "grantPermission": MessageLookupByLibrary.simpleMessage(
      "Accorder l\'autorisation",
    ),
    "heading": MessageLookupByLibrary.simpleMessage("Cap"),
    "highContrast": MessageLookupByLibrary.simpleMessage("Contraste élevé"),
    "home": MessageLookupByLibrary.simpleMessage("Accueil"),
    "imperial": MessageLookupByLibrary.simpleMessage("Impérial"),
    "information": MessageLookupByLibrary.simpleMessage("Information"),
    "keyboardNavigation": MessageLookupByLibrary.simpleMessage(
      "Navigation au clavier",
    ),
    "kilometers": MessageLookupByLibrary.simpleMessage("kilomètres"),
    "kilometersPerHour": MessageLookupByLibrary.simpleMessage(
      "kilomètres par heure",
    ),
    "language": MessageLookupByLibrary.simpleMessage("Langue"),
    "large": MessageLookupByLibrary.simpleMessage("Grand"),
    "largeText": MessageLookupByLibrary.simpleMessage("Texte large"),
    "latitude": MessageLookupByLibrary.simpleMessage("Latitude"),
    "leftToRight": MessageLookupByLibrary.simpleMessage("Gauche à droite"),
    "loading": MessageLookupByLibrary.simpleMessage("Chargement"),
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "L\'autorisation de localisation est requise pour utiliser cette application",
    ),
    "locationUpdated": m1,
    "longitude": MessageLookupByLibrary.simpleMessage("Longitude"),
    "map": MessageLookupByLibrary.simpleMessage("Carte"),
    "measurementUnits": MessageLookupByLibrary.simpleMessage(
      "Unités de mesure",
    ),
    "meters": MessageLookupByLibrary.simpleMessage("mètres"),
    "metersPerSecond": MessageLookupByLibrary.simpleMessage(
      "mètres par seconde",
    ),
    "metric": MessageLookupByLibrary.simpleMessage("Métrique"),
    "microphonePermissionRequired": MessageLookupByLibrary.simpleMessage(
      "L\'autorisation du microphone est requise pour le contrôle vocal",
    ),
    "miles": MessageLookupByLibrary.simpleMessage("miles"),
    "milesPerHour": MessageLookupByLibrary.simpleMessage("miles par heure"),
    "monochrome": MessageLookupByLibrary.simpleMessage("Monochrome"),
    "none": MessageLookupByLibrary.simpleMessage("Aucun"),
    "normal": MessageLookupByLibrary.simpleMessage("Normal"),
    "north": MessageLookupByLibrary.simpleMessage("Nord"),
    "northeast": MessageLookupByLibrary.simpleMessage("Nord-est"),
    "northwest": MessageLookupByLibrary.simpleMessage("Nord-ouest"),
    "numberFormat": MessageLookupByLibrary.simpleMessage("Format des nombres"),
    "protanopia": MessageLookupByLibrary.simpleMessage("Protanopie"),
    "regionalSettings": MessageLookupByLibrary.simpleMessage(
      "Paramètres régionaux",
    ),
    "rightToLeft": MessageLookupByLibrary.simpleMessage("Droite à gauche"),
    "sayAddWaypoint": MessageLookupByLibrary.simpleMessage(
      "Dites \'Ajouter un point de repère\' pour marquer la position actuelle",
    ),
    "sayShowMap": MessageLookupByLibrary.simpleMessage(
      "Dites \'Afficher la carte\' pour voir la carte",
    ),
    "sayStartTracking": MessageLookupByLibrary.simpleMessage(
      "Dites \'Démarrer le suivi\' pour commencer le suivi GPS",
    ),
    "sayStopTracking": MessageLookupByLibrary.simpleMessage(
      "Dites \'Arrêter le suivi\' pour terminer le suivi GPS",
    ),
    "screenReader": MessageLookupByLibrary.simpleMessage(
      "Support de lecteur d\'écran",
    ),
    "settings": MessageLookupByLibrary.simpleMessage("Paramètres"),
    "small": MessageLookupByLibrary.simpleMessage("Petit"),
    "south": MessageLookupByLibrary.simpleMessage("Sud"),
    "southeast": MessageLookupByLibrary.simpleMessage("Sud-est"),
    "southwest": MessageLookupByLibrary.simpleMessage("Sud-ouest"),
    "speed": MessageLookupByLibrary.simpleMessage("Vitesse"),
    "startTracking": MessageLookupByLibrary.simpleMessage("Démarrer le suivi"),
    "stopTracking": MessageLookupByLibrary.simpleMessage("Arrêter le suivi"),
    "success": MessageLookupByLibrary.simpleMessage("Succès"),
    "swipeToNavigate": MessageLookupByLibrary.simpleMessage(
      "Glissez pour naviguer",
    ),
    "tapToActivate": MessageLookupByLibrary.simpleMessage(
      "Appuyez pour activer",
    ),
    "textDirection": MessageLookupByLibrary.simpleMessage("Direction du texte"),
    "theme": MessageLookupByLibrary.simpleMessage("Thème"),
    "timeFormat": MessageLookupByLibrary.simpleMessage("Format d\'heure"),
    "tracking": MessageLookupByLibrary.simpleMessage("Suivi"),
    "trackingStarted": MessageLookupByLibrary.simpleMessage(
      "Suivi GPS démarré",
    ),
    "trackingStopped": MessageLookupByLibrary.simpleMessage("Suivi GPS arrêté"),
    "tritanopia": MessageLookupByLibrary.simpleMessage("Tritanopie"),
    "twelveHour": MessageLookupByLibrary.simpleMessage("12 heures"),
    "twentyFourHour": MessageLookupByLibrary.simpleMessage("24 heures"),
    "voiceCommandRecognized": m2,
    "voiceCommandsHelp": MessageLookupByLibrary.simpleMessage(
      "Aide des commandes vocales",
    ),
    "voiceControl": MessageLookupByLibrary.simpleMessage("Contrôle vocal"),
    "warning": MessageLookupByLibrary.simpleMessage("Avertissement"),
    "waypointAdded": MessageLookupByLibrary.simpleMessage(
      "Point de repère ajouté à la position actuelle",
    ),
    "waypoints": MessageLookupByLibrary.simpleMessage("Points de repère"),
    "west": MessageLookupByLibrary.simpleMessage("Ouest"),
  };
}
