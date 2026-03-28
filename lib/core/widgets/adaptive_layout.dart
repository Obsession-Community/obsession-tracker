import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';

/// Adaptive layout widget that switches between different layouts based on screen size
class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    required this.phone,
    super.key,
    this.tablet,
    this.desktop,
  });

  /// Layout for phone screens
  final Widget phone;

  /// Layout for tablet screens (falls back to phone if not provided)
  final Widget? tablet;

  /// Layout for desktop screens (falls back to tablet or phone if not provided)
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    final deviceType = context.deviceType;

    switch (deviceType) {
      case DeviceType.phone:
        return phone;
      case DeviceType.tablet:
        return tablet ?? phone;
      case DeviceType.desktop:
        return desktop ?? tablet ?? phone;
    }
  }
}

/// Master-detail layout for tablets and desktop
class MasterDetailLayout extends StatefulWidget {
  const MasterDetailLayout({
    required this.masterBuilder,
    required this.detailBuilder,
    super.key,
    this.masterWidth,
    this.showMasterInPortrait = false,
    this.masterTitle,
    this.detailTitle,
    this.floatingActionButton,
    this.backgroundColor,
  });

  /// Builder for the master panel
  final Widget Function(BuildContext context, {required bool isSelected})
      masterBuilder;

  /// Builder for the detail panel
  final Widget Function(BuildContext context) detailBuilder;

  /// Width of the master panel (auto-calculated if not provided)
  final double? masterWidth;

  /// Whether to show master panel in portrait mode on tablets
  final bool showMasterInPortrait;

  /// Title for the master panel
  final String? masterTitle;

  /// Title for the detail panel
  final String? detailTitle;

  /// Floating action button
  final Widget? floatingActionButton;

  /// Background color
  final Color? backgroundColor;

  @override
  State<MasterDetailLayout> createState() => _MasterDetailLayoutState();
}

class _MasterDetailLayoutState extends State<MasterDetailLayout> {
  bool _showDetail = false;

  @override
  Widget build(BuildContext context) {
    final shouldUseMasterDetail = context.shouldUseMasterDetail;
    final isLandscape = context.isLandscape;
    final showMaster =
        shouldUseMasterDetail && (isLandscape || widget.showMasterInPortrait);

    if (!showMaster) {
      // Single panel layout for phones or tablets in portrait
      return _buildSinglePanel();
    }

    // Master-detail layout for tablets in landscape or large tablets
    return _buildMasterDetailPanel();
  }

  Widget _buildSinglePanel() => Scaffold(
        backgroundColor: widget.backgroundColor,
        appBar: AppBar(
          title: Text(widget.masterTitle ?? 'Gallery'),
          centerTitle: true,
        ),
        body: widget.masterBuilder(context, isSelected: false),
        floatingActionButton: widget.floatingActionButton,
      );

  Widget _buildMasterDetailPanel() {
    final masterWidth = widget.masterWidth ?? context.masterPanelWidth;

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Row(
        children: [
          // Master panel
          SizedBox(
            width: masterWidth,
            child: Column(
              children: [
                if (widget.masterTitle != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Text(
                      widget.masterTitle!,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                Expanded(
                  child: widget.masterBuilder(context, isSelected: _showDetail),
                ),
              ],
            ),
          ),

          // Divider
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),

          // Detail panel
          Expanded(
            child: _showDetail
                ? Column(
                    children: [
                      if (widget.detailTitle != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          child: Text(
                            widget.detailTitle!,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      Expanded(child: widget.detailBuilder(context)),
                    ],
                  )
                : _buildEmptyDetailPanel(),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  Widget _buildEmptyDetailPanel() => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Select a photo to view',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );

  void showDetail() {
    setState(() {
      _showDetail = true;
    });
  }

  void hideDetail() {
    setState(() {
      _showDetail = false;
    });
  }
}

/// Responsive grid widget that adapts column count based on screen size
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    required this.children,
    super.key,
    this.phoneColumns = 2,
    this.tabletPortraitColumns = 3,
    this.tabletLandscapeColumns = 4,
    this.desktopColumns = 6,
    this.aspectRatio = 1.0,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
  });

  /// Grid items
  final List<Widget> children;

  /// Number of columns on phone
  final int phoneColumns;

  /// Number of columns on tablet in portrait
  final int tabletPortraitColumns;

  /// Number of columns on tablet in landscape
  final int tabletLandscapeColumns;

  /// Number of columns on desktop
  final int desktopColumns;

  /// Aspect ratio of grid items
  final double aspectRatio;

  /// Spacing between columns
  final double crossAxisSpacing;

  /// Spacing between rows
  final double mainAxisSpacing;

  /// Grid padding
  final EdgeInsets? padding;

  /// Scroll physics
  final ScrollPhysics? physics;

  /// Whether to shrink wrap
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final columnCount = ResponsiveUtils.getGridColumnCount(
      context,
      phoneColumns: phoneColumns,
      tabletPortraitColumns: tabletPortraitColumns,
      tabletLandscapeColumns: tabletLandscapeColumns,
      desktopColumns: desktopColumns,
    );

    return GridView.builder(
      padding: padding ?? context.responsivePadding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// Adaptive navigation widget that switches between different navigation patterns
class AdaptiveNavigation extends StatelessWidget {
  const AdaptiveNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
    this.leading,
    this.trailing,
  });

  /// Navigation destinations
  final List<NavigationDestination> destinations;

  /// Currently selected index
  final int selectedIndex;

  /// Callback when destination is selected
  final ValueChanged<int> onDestinationSelected;

  /// Leading widget for navigation rail
  final Widget? leading;

  /// Trailing widget for navigation rail
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final deviceType = context.deviceType;
    final isLandscape = context.isLandscape;

    // Use navigation rail on tablets in landscape or desktop
    if ((deviceType == DeviceType.tablet && isLandscape) ||
        deviceType == DeviceType.desktop) {
      return NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        labelType: NavigationRailLabelType.all,
        leading: leading,
        trailing: trailing,
        destinations: destinations
            .map((dest) => NavigationRailDestination(
                  icon: dest.icon,
                  selectedIcon: dest.selectedIcon,
                  label: Text(dest.label),
                ))
            .toList(),
      );
    }

    // Use navigation bar for phones and tablets in portrait
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
    );
  }
}

/// Floating panel widget for tablet-optimized dialogs
class FloatingPanel extends StatelessWidget {
  const FloatingPanel({
    required this.child,
    super.key,
    this.width,
    this.height,
    this.margin,
    this.borderRadius,
    this.elevation,
    this.backgroundColor,
  });

  /// Panel content
  final Widget child;

  /// Panel width
  final double? width;

  /// Panel height
  final double? height;

  /// Panel margin from screen edges
  final EdgeInsets? margin;

  /// Border radius
  final BorderRadius? borderRadius;

  /// Elevation
  final double? elevation;

  /// Background color
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final defaultMargin = context.responsiveMargin;
    final screenSize = MediaQuery.of(context).size;

    return Center(
      child: Container(
        width: width ?? (screenSize.width * 0.8).clamp(300.0, 600.0),
        height: height,
        margin: margin ?? defaultMargin,
        decoration: BoxDecoration(
          color: backgroundColor ?? Theme.of(context).colorScheme.surface,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: elevation ?? 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          child: child,
        ),
      ),
    );
  }
}

/// Show adaptive dialog that uses floating panels on tablets
Future<T?> showAdaptiveDialog<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  double? width,
  double? height,
}) {
  if (context.shouldUseFloatingPanels) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      builder: (context) => FloatingPanel(
        width: width,
        height: height,
        child: child,
      ),
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    builder: (context) => child,
  );
}

/// Show adaptive bottom sheet that uses floating panels on tablets
Future<T?> showAdaptiveBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  double? height,
}) {
  if (context.shouldUseFloatingPanels) {
    return showAdaptiveDialog<T>(
      context: context,
      child: child,
      height: height,
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    builder: (context) => child,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
  );
}
