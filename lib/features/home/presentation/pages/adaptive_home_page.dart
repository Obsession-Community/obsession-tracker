import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:obsession_tracker/core/providers/announcements_provider.dart';
import 'package:obsession_tracker/core/providers/data_update_provider.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/services/desktop_service.dart';
import 'package:obsession_tracker/core/services/navigation_service.dart';
import 'package:obsession_tracker/core/services/platform_service.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/core/widgets/adaptive_layout.dart';
import 'package:obsession_tracker/features/achievements/presentation/pages/achievements_page.dart';
import 'package:obsession_tracker/features/hunts/presentation/pages/hunts_page.dart';
import 'package:obsession_tracker/features/journal/presentation/pages/journal_list_page.dart';
import 'package:obsession_tracker/features/map/presentation/pages/map_page.dart';
import 'package:obsession_tracker/features/offline/presentation/pages/land_trail_data_page.dart';
import 'package:obsession_tracker/features/routes/presentation/pages/route_library_page.dart';
import 'package:obsession_tracker/features/sessions/presentation/pages/session_list_page.dart';
import 'package:obsession_tracker/features/settings/presentation/pages/announcements_history_page.dart';
import 'package:obsession_tracker/features/settings/presentation/pages/camera_settings_page.dart';
import 'package:obsession_tracker/features/settings/presentation/pages/data_management_page.dart';
import 'package:obsession_tracker/features/settings/presentation/pages/data_sources_page.dart';
import 'package:obsession_tracker/features/settings/presentation/pages/general_settings_page.dart';
import 'package:obsession_tracker/features/settings/presentation/pages/security_settings_page.dart';
import 'package:obsession_tracker/features/settings/presentation/pages/subscription_settings_page.dart';
import 'package:obsession_tracker/features/settings/presentation/pages/sun_moon_page.dart';
import 'package:obsession_tracker/features/settings/presentation/pages/tracking_settings_page.dart';
import 'package:obsession_tracker/features/settings/presentation/widgets/announcements_card.dart';
import 'package:obsession_tracker/features/settings/presentation/widgets/legal_update_banner.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Adaptive home page that provides optimal navigation experience across all screen sizes
class AdaptiveHomePage extends ConsumerStatefulWidget {
  const AdaptiveHomePage({super.key});

  @override
  ConsumerState<AdaptiveHomePage> createState() => _AdaptiveHomePageState();
}

class _AdaptiveHomePageState extends ConsumerState<AdaptiveHomePage> {
  int _selectedIndex = 0;
  final NavigationService _navigationService = NavigationService();

  static const String _communityUrl = 'https://obsession.community';

  @override
  void initState() {
    super.initState();
    // Listen to navigation service for programmatic tab changes
    _navigationService.selectedTabIndex.addListener(_onTabChangeRequested);
    debugPrint('📱 AdaptiveHomePage: Initialized, listening to NavigationService');

    // Check for legal updates after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        LegalUpdateDialog.showIfNeeded(context, ref);
      }
    });
  }

  @override
  void dispose() {
    _navigationService.selectedTabIndex.removeListener(_onTabChangeRequested);
    super.dispose();
  }

  void _onTabChangeRequested() {
    debugPrint('🔔 AdaptiveHomePage: Tab change requested to ${_navigationService.selectedTabIndex.value}');
    if (mounted) {
      setState(() {
        _selectedIndex = _navigationService.selectedTabIndex.value;
        debugPrint('✅ AdaptiveHomePage: Updated _selectedIndex to $_selectedIndex');
      });
    } else {
      debugPrint('⚠️ AdaptiveHomePage: Not mounted, cannot update tab');
    }
  }

  List<NavigationDestination> _buildDestinations({
    required int unreadAnnouncementsCount,
    required bool hasDataUpdates,
  }) {
    // Show badge if there are unread announcements OR data updates
    final showMoreBadge = unreadAnnouncementsCount > 0 || hasDataUpdates;
    // If we have announcements, show the count; otherwise just show a dot for updates
    final badgeLabel = unreadAnnouncementsCount > 0 ? '$unreadAnnouncementsCount' : '';

    return [
      const NavigationDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map),
        label: 'Map',
      ),
      const NavigationDestination(
        icon: Icon(Icons.history),
        selectedIcon: Icon(Icons.history),
        label: 'Sessions',
      ),
      const NavigationDestination(
        icon: Icon(Icons.book_outlined),
        selectedIcon: Icon(Icons.book),
        label: 'Journal',
      ),
      const NavigationDestination(
        icon: Icon(Icons.route_outlined),
        selectedIcon: Icon(Icons.route),
        label: 'Routes',
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: showMoreBadge,
          label: badgeLabel.isNotEmpty ? Text(badgeLabel) : null,
          child: const Icon(Icons.more_horiz),
        ),
        selectedIcon: Badge(
          isLabelVisible: showMoreBadge,
          label: badgeLabel.isNotEmpty ? Text(badgeLabel) : null,
          child: const Icon(Icons.more_horiz),
        ),
        label: 'More',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(announcementsUnreadCountProvider);
    final hasDataUpdates = ref.watch(hasDataUpdatesProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final destinations = _buildDestinations(
      unreadAnnouncementsCount: unreadCount,
      // Only show data updates badge for premium users
      hasDataUpdates: isPremium && hasDataUpdates,
    );

    final layout = AdaptiveLayout(
      phone: _buildPhoneLayout(destinations),
      tablet: _buildTabletLayout(destinations),
      desktop: _buildDesktopLayout(destinations),
    );

    // Wrap with keyboard shortcuts on desktop platforms
    if (DesktopService.isDesktop) {
      return Shortcuts(
        shortcuts: DesktopService.getKeyboardShortcuts(),
        child: Actions(
          actions: DesktopService.getKeyboardActions(context),
          child: Focus(
            autofocus: true,
            child: layout,
          ),
        ),
      );
    }

    return layout;
  }

  /// Phone layout with bottom navigation
  Widget _buildPhoneLayout(List<NavigationDestination> destinations) => Scaffold(
        body: _buildCurrentPage(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: destinations,
        ),
      );

  /// Tablet layout with adaptive navigation (rail in landscape, bottom in portrait)
  Widget _buildTabletLayout(List<NavigationDestination> destinations) {
    final isLandscape = context.isLandscape;

    if (isLandscape) {
      return Scaffold(
        body: Row(
          children: [
            // Navigation rail
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              leading: _buildNavigationRailHeader(),
              trailing: _buildNavigationRailTrailing(),
              destinations: destinations
                  .map((NavigationDestination dest) => NavigationRailDestination(
                        icon: dest.icon,
                        selectedIcon: dest.selectedIcon,
                        label: Text(dest.label),
                      ))
                  .toList(),
            ),

            // Main content
            Expanded(child: _buildCurrentPage()),
          ],
        ),
      );
    } else {
      // Portrait mode - use bottom navigation like phone
      return _buildPhoneLayout(destinations);
    }
  }

  /// Desktop layout with persistent navigation rail
  Widget _buildDesktopLayout(List<NavigationDestination> destinations) => Scaffold(
        body: Row(
          children: [
            // Extended navigation rail
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              extended: true,
              leading: _buildNavigationRailHeader(),
              trailing: _buildNavigationRailTrailing(),
              destinations: destinations
                  .map((NavigationDestination dest) => NavigationRailDestination(
                        icon: dest.icon,
                        selectedIcon: dest.selectedIcon,
                        label: Text(dest.label),
                      ))
                  .toList(),
            ),

            // Main content
            Expanded(child: _buildCurrentPage()),
          ],
        ),
      );

  Widget _buildNavigationRailHeader() => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.explore,
              size: context.isDesktop ? 48 : 40,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            if (context.isDesktop)
              Text(
                'Obsession\nTracker',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
          ],
        ),
      );

  // Navigation rail trailing - currently empty (Help page has no content yet)
  Widget _buildNavigationRailTrailing() => const SizedBox.shrink();

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return const MapPage(); // Map tab (default landing)
      case 1:
        return const SessionListPage(); // Sessions tab
      case 2:
        return const JournalListPage(); // Journal tab (field journal)
      case 3:
        return const RouteLibraryPage(); // Routes tab
      case 4:
        return _buildMorePage(); // More tab
      default:
        return const MapPage();
    }
  }

  Widget _buildMorePage() {
    final unreadCount = ref.watch(announcementsUnreadCountProvider);

    return Scaffold(
      appBar: !context.isTablet
          ? AppBar(
              title: const Text('More'),
              centerTitle: true,
            )
          : null,
      body: ListView(
        padding: context.responsivePadding,
        children: [
          SizedBox(height: context.isTablet ? 16 : 8),

          // Announcements Section (shown at top if there are any)
          const AnnouncementsCard(),

          // Legal Update Banner (shown when Terms/Privacy updated)
          const LegalUpdateBanner(),

          // Announcements History link
          ListTile(
            leading: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.campaign),
            ),
            title: const Text('Announcements'),
            subtitle: const Text('View all announcements and updates'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToPage(context, const AnnouncementsHistoryPage()),
          ),
          const Divider(),

          // Map Data Section (prominent placement for core feature)
          _buildSectionHeader(context, 'Map Data'),
          // Show Map Data for premium users, Upgrade prompt for free users
          if (ref.watch(isPremiumProvider))
            ListTile(
              leading: Badge(
                isLabelVisible: ref.watch(hasDataUpdatesProvider),
                child: const Icon(Icons.layers),
              ),
              title: const Text('Map Data'),
              subtitle: const Text('Land ownership, trails, and historical places'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _navigateToPage(context, const LandTrailDataPage()),
            )
          else
            _buildMapDataUpgradeTile(context, ref),
          const Divider(),

          // Your Journey Section
          _buildSectionHeader(context, 'Your Journey'),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Treasure Hunts'),
            subtitle: const Text('Track and organize your hunts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToPage(context, const HuntsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events),
            title: const Text('Achievements'),
            subtitle: const Text('Stats, badges, and state collection'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToPage(context, const AchievementsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.wb_twilight),
            title: const Text('Sun & Moon'),
            subtitle: const Text('Sunrise, sunset, moon phase, golden hour'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToPage(context, const SunMoonPage()),
          ),
          const Divider(),

          // Settings Section
          _buildSectionHeader(context, 'Settings'),
          // Only show subscription management for premium users
          if (ref.watch(isPremiumProvider)) _buildSubscriptionTile(context, ref),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Security'),
            subtitle: const Text('Face ID, Touch ID, and app lock'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToPage(context, const SecuritySettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('General'),
            subtitle: const Text('Theme, units, and time format'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToPage(context, const GeneralSettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.gps_fixed),
            title: const Text('GPS Tracking'),
            subtitle: const Text('Accuracy and intervals'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToPage(context, const TrackingSettingsPage()),
          ),
          if (PlatformService().isMobile)
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            subtitle: const Text('Photo quality and settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToPage(context, const CameraSettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Data Management'),
            subtitle: const Text('Backup, restore, and export'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToPage(context, const DataManagementPage()),
          ),
          const Divider(),

          // Community Section
          _buildSectionHeader(context, 'Community'),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: const Text('Obsession Community'),
            subtitle: const Text('Discord, Trail Tales, and more'),
            trailing: const Icon(Icons.open_in_new),
            onTap: _openCommunity,
          ),
          // TODO(help): Uncomment when help content is available
          // ListTile(
          //   leading: const Icon(Icons.help_outline),
          //   title: const Text('Help & Support'),
          //   subtitle: const Text('Get help using Obsession Tracker'),
          //   trailing: const Icon(Icons.chevron_right),
          //   onTap: _showHelp,
          // ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Contact Support'),
            subtitle: const Text('Send feedback, report issues, or request features'),
            trailing: const Icon(Icons.open_in_new),
            onTap: _contactSupport,
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rate the App'),
            subtitle: const Text('Help others discover Obsession Tracker'),
            trailing: const Icon(Icons.open_in_new),
            onTap: _rateApp,
          ),
          const Divider(),

          // About Section
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('About'),
            subtitle: const Text('App version and information'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAbout,
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Licenses'),
            subtitle: const Text('Open source licenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showLicenses,
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('How we protect your data'),
            trailing: const Icon(Icons.open_in_new),
            onTap: _openPrivacyPolicy,
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms of Service'),
            subtitle: const Text('Usage terms and conditions'),
            trailing: const Icon(Icons.open_in_new),
            onTap: _openTermsOfService,
          ),
          ListTile(
            leading: const Icon(Icons.source_outlined),
            title: const Text('Data Sources & Legal'),
            subtitle: const Text('Government data attribution & disclaimer'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToPage(context, const DataSourcesPage()),
          ),
          const Divider(),
          Padding(
            padding: EdgeInsets.all(context.isTablet ? 20 : 16),
            child: Column(
              children: [
                Icon(
                  Icons.explore,
                  size: context.isTablet ? 64 : 48,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Obsession Tracker',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your compass when nothing adds up',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onDestinationSelected(int index) {
    // Update both local state and NavigationService to keep them in sync
    // Don't call setState here - let the listener handle it to avoid redundant rebuilds
    _navigationService.selectedTabIndex.value = index;
  }

  Widget _buildSectionHeader(BuildContext context, String title) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.isTablet ? 20 : 16,
          vertical: 8,
        ),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
        ),
      );

  /// Upgrade tile shown in the Map Data section for non-premium users
  Widget _buildMapDataUpgradeTile(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.08),
            Colors.orange.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        leading: const Icon(
          Icons.layers,
          color: Colors.amber,
          size: 28,
        ),
        title: const Text(
          'Upgrade to Premium',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Unlock offline land data, trails, and historical places'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'TRY FREE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _navigateToPage(context, const SubscriptionSettingsPage()),
      ),
    );
  }

  /// Subscription management tile - only shown for premium users
  /// (non-premium users see the upgrade tile in Map Data section instead)
  Widget _buildSubscriptionTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(
        Icons.workspace_premium,
        color: Colors.amber,
        size: 28,
      ),
      title: const Text('Premium'),
      subtitle: const Text('Manage your premium subscription'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _navigateToPage(context, const SubscriptionSettingsPage()),
    );
  }

  void _navigateToPage(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => page),
    );
  }

  Future<void> _showAbout() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = '${packageInfo.version} (${packageInfo.buildNumber})';

      if (!mounted) return;

      showAboutDialog(
        context: context,
        applicationName: 'Obsession Tracker',
        applicationVersion: version,
        applicationIcon: const Icon(
          Icons.explore,
          size: 64,
        ),
        applicationLegalese: '© 2025 Obsession Community LLC\nObsession Tracker\nPrivacy-first GPS tracking',
        children: [
          const SizedBox(height: 16),
          const Text(
            'Your compass when nothing adds up. Track your adventures with complete privacy and control.',
          ),
        ],
      );
    } catch (e) {
      debugPrint('❌ _showAbout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to show about: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showLicenses() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = '${packageInfo.version} (${packageInfo.buildNumber})';

      if (!mounted) return;

      showLicensePage(
        context: context,
        applicationName: 'Obsession Tracker',
        applicationVersion: version,
        applicationIcon: const Icon(Icons.explore, size: 48),
      );
    } catch (e) {
      debugPrint('❌ _showLicenses error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to show licenses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openCommunity() async {
    try {
      final uri = Uri.parse(_communityUrl);
      final canLaunch = await canLaunchUrl(uri);
      debugPrint('🔗 Community: canLaunch=$canLaunch');
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot open browser. Visit obsession.community'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ _openCommunity error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open community site: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      final uri = Uri.parse('https://obsessiontracker.com/privacy.html');
      final canLaunch = await canLaunchUrl(uri);
      debugPrint('🔗 Privacy Policy: canLaunch=$canLaunch');
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot open browser. Visit obsessiontracker.com/privacy.html'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ _openPrivacyPolicy error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open privacy policy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openTermsOfService() async {
    try {
      final uri = Uri.parse('https://obsessiontracker.com/terms.html');
      final canLaunch = await canLaunchUrl(uri);
      debugPrint('🔗 Terms of Service: canLaunch=$canLaunch');
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot open browser. Visit obsessiontracker.com/terms.html'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ _openTermsOfService error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open terms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _contactSupport() async {
    // Manually encode to avoid + symbols (queryParameters encodes spaces as +)
    const subject = 'Obsession Tracker Feedback';
    const body = 'Hi,\n\nI would like to share the following feedback:\n\n';
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body);
    final uri = Uri.parse(
      'mailto:support@obsessiontracker.com?subject=$encodedSubject&body=$encodedBody',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback: show a dialog with the email address
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email support@obsessiontracker.com'),
          ),
        );
      }
    }
  }

  Future<void> _rateApp() async {
    // Use in_app_review's openStoreListing for user-initiated rate requests
    // Note: requestReview() is for organic prompts and may silently fail
    // openStoreListing() reliably opens the store page
    final inAppReview = InAppReview.instance;
    await inAppReview.openStoreListing(
      appStoreId: '6753697879',
    );
  }
}
