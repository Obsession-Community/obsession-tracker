import 'package:flutter/material.dart';

/// A customizable tile for settings items
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.title,
    super.key,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: leading,
        title: Text(
          title,
          style: TextStyle(
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).disabledColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  color: enabled
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).disabledColor,
                ),
              )
            : null,
        trailing: trailing ??
            (onTap != null ? const Icon(Icons.chevron_right) : null),
        onTap: enabled ? onTap : null,
        enabled: enabled,
      );
}

/// A switch tile for boolean settings
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
    this.leading,
    this.subtitle,
    this.enabled = true,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: leading,
        title: Text(
          title,
          style: TextStyle(
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).disabledColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  color: enabled
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).disabledColor,
                ),
              )
            : null,
        value: value,
        onChanged: enabled ? onChanged : null,
      );
}

/// A slider tile for numeric settings
class SettingsSliderTile extends StatelessWidget {
  const SettingsSliderTile({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    super.key,
    this.leading,
    this.subtitle,
    this.divisions,
    this.label,
    this.enabled = true,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            leading: leading,
            title: Text(
              title,
              style: TextStyle(
                color: enabled
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).disabledColor,
              ),
            ),
            subtitle: subtitle != null
                ? Text(
                    subtitle!,
                    style: TextStyle(
                      color: enabled
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).disabledColor,
                    ),
                  )
                : null,
            trailing: Text(
              label ?? value.toStringAsFixed(1),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: enabled
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).disabledColor,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: value,
              onChanged: enabled ? onChanged : null,
              min: min,
              max: max,
              divisions: divisions,
              label: label,
            ),
          ),
        ],
      );
}

/// A dropdown tile for selection settings
class SettingsDropdownTile<T> extends StatelessWidget {
  const SettingsDropdownTile({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
    this.leading,
    this.subtitle,
    this.enabled = true,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: leading,
        title: Text(
          title,
          style: TextStyle(
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).disabledColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  color: enabled
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).disabledColor,
                ),
              )
            : null,
        trailing: SizedBox(
          width: 120, // Constrain the dropdown width
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: enabled ? onChanged : null,
            underline: const SizedBox(),
            isExpanded: true, // Allow text to fill available space
            isDense: true, // Make dropdown more compact
          ),
        ),
      );
}
