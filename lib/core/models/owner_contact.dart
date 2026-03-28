import 'package:flutter/foundation.dart';

/// Property owner contact information for permission requests
@immutable
class OwnerContact {
  const OwnerContact({
    required this.ownerName,
    this.mailingAddress,
    this.phoneNumber,
    this.email,
    this.contactPreference,
    this.lastVerified,
  });

  final String ownerName;
  final String? mailingAddress;
  final String? phoneNumber;
  final String? email;
  final String? contactPreference; // mail, phone, email, website
  final DateTime? lastVerified;

  /// Create from GraphQL response data
  factory OwnerContact.fromJson(Map<String, dynamic> json) {
    return OwnerContact(
      ownerName: (json['ownerName'] as String?) ?? '',
      mailingAddress: json['mailingAddress'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      email: json['email'] as String?,
      contactPreference: json['contactPreference'] as String?,
      lastVerified: json['lastVerified'] != null
          ? DateTime.parse(json['lastVerified'] as String)
          : null,
    );
  }

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'ownerName': ownerName,
      'mailingAddress': mailingAddress,
      'phoneNumber': phoneNumber,
      'email': email,
      'contactPreference': contactPreference,
      'lastVerified': lastVerified?.toIso8601String().split('T')[0],
    };
  }

  /// Get preferred contact method
  ContactMethod get preferredMethod {
    switch (contactPreference?.toLowerCase()) {
      case 'phone':
        return phoneNumber != null ? ContactMethod.phone : ContactMethod.mail;
      case 'email':
        return email != null ? ContactMethod.email : ContactMethod.mail;
      case 'mail':
      default:
        return ContactMethod.mail;
    }
  }

  /// Check if contact information is available
  bool get hasContactInfo {
    return mailingAddress != null || phoneNumber != null || email != null;
  }

  /// Get formatted contact summary for display
  String get contactSummary {
    if (!hasContactInfo) return 'No contact information available';
    
    final methods = <String>[];
    if (mailingAddress != null) methods.add('Mail');
    if (phoneNumber != null) methods.add('Phone');
    if (email != null) methods.add('Email');
    
    return 'Contact via: ${methods.join(', ')}';
  }

  /// Get the best available contact method
  String? get bestContactInfo {
    switch (preferredMethod) {
      case ContactMethod.phone:
        return phoneNumber;
      case ContactMethod.email:
        return email;
      case ContactMethod.mail:
        return mailingAddress;
    }
  }

  /// Check if contact information is recently verified (within 1 year)
  bool get isRecentlyVerified {
    if (lastVerified == null) return false;
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    return lastVerified!.isAfter(oneYearAgo);
  }

  /// Get verification status
  String get verificationStatus {
    if (lastVerified == null) return 'Not verified';
    if (isRecentlyVerified) return 'Recently verified';
    
    final daysSinceVerification = DateTime.now().difference(lastVerified!).inDays;
    if (daysSinceVerification < 730) { // Less than 2 years
      return 'Verified ${(daysSinceVerification / 365).floor()} year(s) ago';
    }
    return 'Verification outdated';
  }

  /// Get verification status color
  int get verificationColor {
    if (lastVerified == null) return 0xFF9E9E9E; // Grey
    if (isRecentlyVerified) return 0xFF4CAF50; // Green
    
    final daysSinceVerification = DateTime.now().difference(lastVerified!).inDays;
    if (daysSinceVerification < 730) return 0xFFFF9800; // Orange
    return 0xFFF44336; // Red
  }

  OwnerContact copyWith({
    String? ownerName,
    String? mailingAddress,
    String? phoneNumber,
    String? email,
    String? contactPreference,
    DateTime? lastVerified,
  }) {
    return OwnerContact(
      ownerName: ownerName ?? this.ownerName,
      mailingAddress: mailingAddress ?? this.mailingAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      contactPreference: contactPreference ?? this.contactPreference,
      lastVerified: lastVerified ?? this.lastVerified,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OwnerContact &&
        other.ownerName == ownerName &&
        other.mailingAddress == mailingAddress &&
        other.phoneNumber == phoneNumber &&
        other.email == email &&
        other.contactPreference == contactPreference &&
        other.lastVerified == lastVerified;
  }

  @override
  int get hashCode {
    return Object.hash(
      ownerName,
      mailingAddress,
      phoneNumber,
      email,
      contactPreference,
      lastVerified,
    );
  }

  @override
  String toString() {
    return 'OwnerContact('
        'ownerName: $ownerName, '
        'mailingAddress: $mailingAddress, '
        'phoneNumber: $phoneNumber, '
        'email: $email, '
        'contactPreference: $contactPreference, '
        'lastVerified: $lastVerified)';
  }
}

/// Contact method preference
enum ContactMethod {
  mail('Mail'),
  phone('Phone'),
  email('Email');

  const ContactMethod(this.displayName);
  final String displayName;

  String get icon {
    switch (this) {
      case ContactMethod.mail:
        return '📮';
      case ContactMethod.phone:
        return '📞';
      case ContactMethod.email:
        return '📧';
    }
  }
}