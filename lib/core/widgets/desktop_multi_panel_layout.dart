import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/services/desktop_service.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';

/// Multi-panel layout optimized for desktop screens
class DesktopMultiPanelLayout extends StatefulWidget {
  const DesktopMultiPanelLayout({
    required this.leftPanel,
    required this.centerPanel,
    super.key,
    this.rightPanel,
    this.bottomPanel,
    this.leftPanelWidth = 300,
    this.rightPanelWidth = 300,
    this.bottomPanelHeight = 200,
    this.showLeftPanel = true,
    this.showRightPanel = false,
    this.showBottomPanel = false,
    this.resizableLeftPanel = true,
    this.resizableRightPanel = true,
    this.resizableBottomPanel = true,
    this.onPanelToggle,
  });

  final Widget leftPanel;
  final Widget centerPanel;
  final Widget? rightPanel;
  final Widget? bottomPanel;
  final double leftPanelWidth;
  final double rightPanelWidth;
  final double bottomPanelHeight;
  final bool showLeftPanel;
  final bool showRightPanel;
  final bool showBottomPanel;
  final bool resizableLeftPanel;
  final bool resizableRightPanel;
  final bool resizableBottomPanel;
  final void Function(String panel, {required bool visible})? onPanelToggle;

  @override
  State<DesktopMultiPanelLayout> createState() =>
      _DesktopMultiPanelLayoutState();
}

class _DesktopMultiPanelLayoutState extends State<DesktopMultiPanelLayout> {
  late double _leftPanelWidth;
  late double _rightPanelWidth;
  late double _bottomPanelHeight;
  late bool _showLeftPanel;
  late bool _showRightPanel;
  late bool _showBottomPanel;

  @override
  void initState() {
    super.initState();
    _leftPanelWidth = widget.leftPanelWidth;
    _rightPanelWidth = widget.rightPanelWidth;
    _bottomPanelHeight = widget.bottomPanelHeight;
    _showLeftPanel = widget.showLeftPanel;
    _showRightPanel = widget.showRightPanel;
    _showBottomPanel = widget.showBottomPanel;
  }

  @override
  Widget build(BuildContext context) {
    if (!DesktopService.isDesktop || !context.isDesktop) {
      // Fallback to center panel only for non-desktop
      return widget.centerPanel;
    }

    return Shortcuts(
      shortcuts: DesktopService.getKeyboardShortcuts(),
      child: Actions(
        actions: DesktopService.getKeyboardActions(context),
        child: Focus(
          autofocus: true,
          child: _buildLayout(),
        ),
      ),
    );
  }

  Widget _buildLayout() => Column(
        children: [
          // Main horizontal layout
          Expanded(
            child: Row(
              children: [
                // Left panel
                if (_showLeftPanel) ...[
                  SizedBox(
                    width: _leftPanelWidth,
                    child: _buildPanelContainer(
                      child: widget.leftPanel,
                      title: 'Navigation',
                      onClose: () => _togglePanel('left', false),
                    ),
                  ),
                  if (widget.resizableLeftPanel)
                    _buildVerticalResizer(
                      onDrag: (delta) {
                        setState(() {
                          _leftPanelWidth =
                              (_leftPanelWidth + delta).clamp(200.0, 500.0);
                        });
                      },
                    ),
                ],

                // Center panel
                Expanded(
                  child: Column(
                    children: [
                      // Main content
                      Expanded(
                        child: _buildPanelContainer(
                          child: widget.centerPanel,
                          title: 'Main Content',
                          showClose: false,
                          actions: _buildCenterPanelActions(),
                        ),
                      ),

                      // Bottom panel
                      if (_showBottomPanel && widget.bottomPanel != null) ...[
                        if (widget.resizableBottomPanel)
                          _buildHorizontalResizer(
                            onDrag: (delta) {
                              setState(() {
                                _bottomPanelHeight =
                                    (_bottomPanelHeight - delta)
                                        .clamp(100.0, 400.0);
                              });
                            },
                          ),
                        SizedBox(
                          height: _bottomPanelHeight,
                          child: _buildPanelContainer(
                            child: widget.bottomPanel!,
                            title: 'Details',
                            onClose: () => _togglePanel('bottom', false),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Right panel
                if (_showRightPanel && widget.rightPanel != null) ...[
                  if (widget.resizableRightPanel)
                    _buildVerticalResizer(
                      onDrag: (delta) {
                        setState(() {
                          _rightPanelWidth =
                              (_rightPanelWidth - delta).clamp(200.0, 500.0);
                        });
                      },
                    ),
                  SizedBox(
                    width: _rightPanelWidth,
                    child: _buildPanelContainer(
                      child: widget.rightPanel!,
                      title: 'Properties',
                      onClose: () => _togglePanel('right', false),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );

  Widget _buildPanelContainer({
    required Widget child,
    required String title,
    bool showClose = true,
    VoidCallback? onClose,
    List<Widget>? actions,
  }) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            // Panel header
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  if (actions != null) ...actions,
                  if (showClose && onClose != null)
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                    ),
                ],
              ),
            ),
            // Panel content
            Expanded(child: child),
          ],
        ),
      );

  Widget _buildVerticalResizer({required void Function(double) onDrag}) =>
      MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          onPanUpdate: (details) => onDrag(details.delta.dx),
          child: Container(
            width: 4,
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      );

  Widget _buildHorizontalResizer({required void Function(double) onDrag}) =>
      MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: GestureDetector(
          onPanUpdate: (details) => onDrag(details.delta.dy),
          child: Container(
            height: 4,
            color: Colors.transparent,
            child: Center(
              child: Container(
                height: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      );

  List<Widget> _buildCenterPanelActions() => [
        // Toggle left panel
        IconButton(
          onPressed: () => _togglePanel('left', !_showLeftPanel),
          icon: Icon(_showLeftPanel
              ? Icons.view_sidebar
              : Icons.view_sidebar_outlined),
          iconSize: 16,
          tooltip: '${_showLeftPanel ? 'Hide' : 'Show'} Navigation Panel',
        ),

        // Toggle right panel
        if (widget.rightPanel != null)
          IconButton(
            onPressed: () => _togglePanel('right', !_showRightPanel),
            icon: Icon(_showRightPanel
                ? Icons.view_sidebar
                : Icons.view_sidebar_outlined),
            iconSize: 16,
            tooltip: '${_showRightPanel ? 'Hide' : 'Show'} Properties Panel',
          ),

        // Toggle bottom panel
        if (widget.bottomPanel != null)
          IconButton(
            onPressed: () => _togglePanel('bottom', !_showBottomPanel),
            icon: Icon(_showBottomPanel
                ? Icons.horizontal_split
                : Icons.horizontal_split_outlined),
            iconSize: 16,
            tooltip: '${_showBottomPanel ? 'Hide' : 'Show'} Details Panel',
          ),
      ];

  void _togglePanel(String panel, bool visible) {
    setState(() {
      switch (panel) {
        case 'left':
          _showLeftPanel = visible;
          break;
        case 'right':
          _showRightPanel = visible;
          break;
        case 'bottom':
          _showBottomPanel = visible;
          break;
      }
    });

    widget.onPanelToggle?.call(panel, visible: visible);
  }
}

/// Predefined layouts for common desktop scenarios
class DesktopLayoutPresets {
  /// Standard layout with navigation and main content
  static Widget standard({
    required Widget navigation,
    required Widget content,
  }) =>
      DesktopMultiPanelLayout(
        leftPanel: navigation,
        centerPanel: content,
      );

  /// Editor layout with navigation, content, and properties
  static Widget editor({
    required Widget navigation,
    required Widget content,
    required Widget properties,
  }) =>
      DesktopMultiPanelLayout(
        leftPanel: navigation,
        centerPanel: content,
        rightPanel: properties,
        showRightPanel: true,
      );

  /// Analysis layout with all panels
  static Widget analysis({
    required Widget navigation,
    required Widget content,
    required Widget properties,
    required Widget details,
  }) =>
      DesktopMultiPanelLayout(
        leftPanel: navigation,
        centerPanel: content,
        rightPanel: properties,
        bottomPanel: details,
        showRightPanel: true,
        showBottomPanel: true,
      );

  /// Comparison layout optimized for side-by-side content
  static Widget comparison({
    required Widget navigation,
    required Widget leftContent,
    required Widget rightContent,
  }) =>
      DesktopMultiPanelLayout(
        leftPanel: navigation,
        centerPanel: Row(
          children: [
            Expanded(child: leftContent),
            Container(
              width: 1,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            Expanded(child: rightContent),
          ],
        ),
        leftPanelWidth: 250,
      );
}
