import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DownloadAreaConfig {
  final String name;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusKm;

  const DownloadAreaConfig({
    required this.name,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusKm,
  });
}

class DownloadAreaDialog extends StatefulWidget {
  const DownloadAreaDialog({
    super.key,
    this.centerLatitude,
    this.centerLongitude,
  });

  final double? centerLatitude;
  final double? centerLongitude;

  @override
  State<DownloadAreaDialog> createState() => _DownloadAreaDialogState();
}

class _DownloadAreaDialogState extends State<DownloadAreaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _radiusController = TextEditingController(text: '5.0');

  final List<double> _predefinedRadii = [1.0, 2.5, 5.0, 10.0, 25.0];
  double _selectedRadius = 5.0;

  @override
  void initState() {
    super.initState();
    
    // Set initial values if provided
    if (widget.centerLatitude != null) {
      _latitudeController.text = widget.centerLatitude!.toStringAsFixed(6);
    }
    if (widget.centerLongitude != null) {
      _longitudeController.text = widget.centerLongitude!.toStringAsFixed(6);
    }

    // Generate a default name
    if (widget.centerLatitude != null && widget.centerLongitude != null) {
      _nameController.text = 'Area ${DateTime.now().month}/${DateTime.now().day}';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _onRadiusChanged(double radius) {
    setState(() {
      _selectedRadius = radius;
      _radiusController.text = radius.toString();
    });
  }

  String _getDownloadSizeEstimate(double radiusKm) {
    // Realistic estimate for processed BFF data (not raw geodatabase files)
    final areaKmSq = 3.14159 * radiusKm * radiusKm;
    final estimatedProperties = (areaKmSq * 50).round(); // ~50 properties per km²
    final estimatedSizeKB = (estimatedProperties * 0.5).round(); // ~0.5KB per processed property
    
    if (estimatedSizeKB < 1) {
      return '<1 KB';
    } else if (estimatedSizeKB < 1024) {
      return '~$estimatedSizeKB KB';
    } else {
      final sizeMB = estimatedSizeKB / 1024;
      return '~${sizeMB.toStringAsFixed(1)} MB';
    }
  }

  String _getPropertyCountEstimate(double radiusKm) {
    final areaKmSq = 3.14159 * radiusKm * radiusKm;
    final estimatedProperties = (areaKmSq * 50).round();
    
    if (estimatedProperties < 1000) {
      return '$estimatedProperties properties';
    } else {
      final countK = estimatedProperties / 1000;
      return '${countK.toStringAsFixed(1)}K properties';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Download Area for Offline Use'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Area name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Area Name',
                  hintText: 'e.g., Hunting Spot, Local Parks',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name for this area';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Center coordinates
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        prefixIcon: Icon(Icons.place),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^-?\d*\.?\d*'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final lat = double.tryParse(value);
                        if (lat == null || lat < -90 || lat > 90) {
                          return 'Invalid latitude';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^-?\d*\.?\d*'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final lng = double.tryParse(value);
                        if (lng == null || lng < -180 || lng > 180) {
                          return 'Invalid longitude';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Radius selection
              const Text(
                'Download Radius',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              
              // Predefined radius chips
              Wrap(
                spacing: 8,
                children: _predefinedRadii.map((radius) {
                  return ChoiceChip(
                    label: Text('${radius.toStringAsFixed(radius % 1 == 0 ? 0 : 1)} km'),
                    selected: _selectedRadius == radius,
                    onSelected: (selected) {
                      if (selected) {
                        _onRadiusChanged(radius);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              
              // Custom radius input
              TextFormField(
                controller: _radiusController,
                decoration: const InputDecoration(
                  labelText: 'Custom Radius (km)',
                  prefixIcon: Icon(Icons.circle),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (value) {
                  final radius = double.tryParse(value);
                  if (radius != null && radius > 0 && radius <= 50) {
                    setState(() {
                      _selectedRadius = radius;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a radius';
                  }
                  final radius = double.tryParse(value);
                  if (radius == null || radius <= 0) {
                    return 'Radius must be greater than 0';
                  }
                  if (radius > 50) {
                    return 'Maximum radius is 50 km';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Download estimates
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Download Estimates',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estimated properties:',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          _getPropertyCountEstimate(_selectedRadius),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estimated download size:',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          _getDownloadSizeEstimate(_selectedRadius),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() == true) {
              final config = DownloadAreaConfig(
                name: _nameController.text.trim(),
                centerLatitude: double.parse(_latitudeController.text),
                centerLongitude: double.parse(_longitudeController.text),
                radiusKm: double.parse(_radiusController.text),
              );
              Navigator.of(context).pop(config);
            }
          },
          child: const Text('Download'),
        ),
      ],
    );
  }
}