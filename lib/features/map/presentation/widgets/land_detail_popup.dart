import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:url_launcher/url_launcher.dart';

/// Popup widget that displays detailed information about a tapped land ownership polygon
class LandDetailPopup extends StatelessWidget {
  const LandDetailPopup({
    required this.landOwnership,
    required this.onClose,
    super.key,
    this.onNavigateToDetails,
  });

  final LandOwnership landOwnership;
  final VoidCallback onClose;
  final VoidCallback? onNavigateToDetails;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350, maxHeight: 500),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with owner name and close button
            Row(
              children: [
                Expanded(
                  child: Text(
                    landOwnership.unitName ?? landOwnership.ownerName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Land type with color indicator
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(landOwnership.ownershipType.defaultColor),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    landOwnership.ownershipType.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Fee indicator badge
            _buildFeeIndicator(context),

            const SizedBox(height: 16),

            // Details section
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Owner information
                    if (landOwnership.ownerName != (landOwnership.unitName ?? landOwnership.ownerName))
                      _buildDetailRow(
                        'Owner',
                        landOwnership.ownerName,
                        Icons.account_balance,
                      ),

                    if (landOwnership.agencyName != null)
                      _buildDetailRow(
                        'Agency',
                        landOwnership.agencyName!,
                        Icons.business,
                      ),

                    if (landOwnership.designation != null)
                      _buildDetailRow(
                        'Designation',
                        landOwnership.designation!,
                        Icons.flag,
                      ),

                    // Access information
                    _buildDetailRow(
                      'Access',
                      landOwnership.accessType.displayName,
                      _getAccessIcon(landOwnership.accessType),
                      textColor: _getAccessColor(landOwnership.accessType),
                    ),

                    if (landOwnership.fees != null)
                      _buildDetailRow(
                        'Fees',
                        landOwnership.fees!,
                        Icons.attach_money,
                        textColor: Colors.orange.shade700,
                      ),

                    if (landOwnership.seasonalInfo != null)
                      _buildDetailRow(
                        'Seasonal Info',
                        landOwnership.seasonalInfo!,
                        Icons.calendar_month,
                      ),

                    // Activity permissions
                    if (landOwnership.allowedUses.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Allowed Activities',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: landOwnership.allowedUses
                            .map((use) => Chip(
                                  label: Text(
                                    use.displayName,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: Colors.green.shade50,
                                  side: BorderSide(color: Colors.green.shade200),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ],

                    // Restrictions
                    if (landOwnership.restrictions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Restrictions',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...landOwnership.restrictions.map((restriction) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning,
                                  size: 14,
                                  color: Colors.red.shade600,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    restriction,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],

                    // Contact information
                    if (landOwnership.contactInfo != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Contact',
                        landOwnership.contactInfo!,
                        Icons.contact_phone,
                      ),
                    ],

                    // Data source
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Data Source',
                      landOwnership.dataSource,
                      Icons.dataset,
                      textStyle: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            const SizedBox(height: 16),
            Row(
              children: [
                if (landOwnership.website != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO(dev): Launch URL
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Website link feature coming soon'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.launch, size: 16),
                      label: const Text('Website'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),

                if (landOwnership.website != null && onNavigateToDetails != null)
                  const SizedBox(width: 8),

                if (onNavigateToDetails != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Show more details dialog instead of navigating to new page
                        showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(landOwnership.unitName ?? landOwnership.ownerName),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildSimpleDetailRow('Owner', landOwnership.ownerName),
                                  _buildSimpleDetailRow('Type', landOwnership.ownershipType.displayName),
                                  if (landOwnership.agencyName != null)
                                    _buildSimpleDetailRow('Agency', landOwnership.agencyName!),
                                  if (landOwnership.designation != null)
                                    _buildSimpleDetailRow('Designation', landOwnership.designation!),
                                  _buildSimpleDetailRow('Access', landOwnership.accessType.displayName),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Location',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildSimpleDetailRow('Center',
                                    '${landOwnership.centroid.latitude.toStringAsFixed(6)}, ${landOwnership.centroid.longitude.toStringAsFixed(6)}'),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Bounds',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildSimpleDetailRow('North', landOwnership.bounds.north.toStringAsFixed(6)),
                                  _buildSimpleDetailRow('South', landOwnership.bounds.south.toStringAsFixed(6)),
                                  _buildSimpleDetailRow('East', landOwnership.bounds.east.toStringAsFixed(6)),
                                  _buildSimpleDetailRow('West', landOwnership.bounds.west.toStringAsFixed(6)),
                                  if (landOwnership.fees != null) ...[
                                    const SizedBox(height: 16),
                                    _buildSimpleDetailRow('Fees', landOwnership.fees!),
                                  ],
                                  if (landOwnership.website != null) ...[
                                    const SizedBox(height: 8),
                                    _buildSimpleDetailRow('Website', landOwnership.website!),
                                  ],
                                  const SizedBox(height: 24),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Open in Map App',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildMapAppButton(
                                        context,
                                        'Apple Maps',
                                        Icons.map,
                                        () => _openInAppleMaps(landOwnership.centroid.latitude, landOwnership.centroid.longitude, landOwnership.ownerName),
                                      ),
                                      _buildMapAppButton(
                                        context,
                                        'Google Maps',
                                        Icons.map_outlined,
                                        () => _openInGoogleMaps(landOwnership.centroid.latitude, landOwnership.centroid.longitude, landOwnership.ownerName),
                                      ),
                                      _buildMapAppButton(
                                        context,
                                        'Waze',
                                        Icons.navigation,
                                        () => _openInWaze(landOwnership.centroid.latitude, landOwnership.centroid.longitude),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                        onNavigateToDetails?.call();
                      },
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('More Details'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    Color? textColor,
    TextStyle? textStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: textColor ?? Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textStyle ?? TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: textStyle ?? TextStyle(
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapAppButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  Future<void> _openInAppleMaps(double lat, double lon, String label) async {
    final url = Uri.parse('http://maps.apple.com/?q=$label&ll=$lat,$lon');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openInGoogleMaps(double lat, double lon, String label) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to comgooglemaps:// scheme for iOS
      final iosUrl = Uri.parse('comgooglemaps://?q=$lat,$lon&center=$lat,$lon&zoom=14');
      if (await canLaunchUrl(iosUrl)) {
        await launchUrl(iosUrl, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _openInWaze(double lat, double lon) async {
    final url = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  IconData _getAccessIcon(AccessType accessType) {
    switch (accessType) {
      case AccessType.publicOpen:
        return Icons.public;
      case AccessType.permitRequired:
        return Icons.assignment;
      case AccessType.seasonalRestrictions:
        return Icons.schedule;
      case AccessType.feeRequired:
        return Icons.attach_money;
      case AccessType.huntingLicenseRequired:
        return Icons.verified_user;
      case AccessType.restrictedAccess:
        return Icons.lock;
      case AccessType.noPublicAccess:
        return Icons.block;
    }
  }

  Color? _getAccessColor(AccessType accessType) {
    switch (accessType) {
      case AccessType.publicOpen:
        return Colors.green.shade700;
      case AccessType.permitRequired:
      case AccessType.seasonalRestrictions:
      case AccessType.huntingLicenseRequired:
        return Colors.orange.shade700;
      case AccessType.feeRequired:
        return Colors.blue.shade700;
      case AccessType.restrictedAccess:
      case AccessType.noPublicAccess:
        return Colors.red.shade700;
    }
  }

  Widget _buildFeeIndicator(BuildContext context) {
    // Determine if the area is free or requires a fee
    final bool isFree = landOwnership.fees != null &&
                        (landOwnership.fees!.toLowerCase().contains('free') ||
                         landOwnership.fees!.toLowerCase().contains('no entrance fee'));

    final bool requiresFee = landOwnership.fees != null &&
                             (landOwnership.fees!.toLowerCase().contains('fee required') ||
                              landOwnership.fees!.toLowerCase().contains('entrance fee') ||
                              landOwnership.fees!.contains(r'$'));

    if (!isFree && !requiresFee) {
      return const SizedBox.shrink(); // Don't show if we don't have clear info
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isFree ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFree ? Colors.green.shade300 : Colors.orange.shade300,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFree ? Icons.check_circle : Icons.attach_money,
            color: isFree ? Colors.green.shade700 : Colors.orange.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isFree ? 'FREE - No Entrance Fee' : 'ENTRANCE FEE REQUIRED',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isFree ? Colors.green.shade800 : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}