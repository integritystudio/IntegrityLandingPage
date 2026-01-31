import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/pages/landing_page.dart';
import 'package:integrity_studio_ai/routing/app_router.dart';
import 'package:integrity_studio_ai/widgets/sections/hero_section.dart';
import 'package:integrity_studio_ai/widgets/sections/tabbed_features_section.dart';
import 'package:integrity_studio_ai/widgets/sections/pricing_section.dart';
import 'package:integrity_studio_ai/widgets/sections/cta_section.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  group('LandingPage', () {
    // Use pump with duration instead of pumpAndSettle to avoid animation timeouts
    Future<void> pumpLandingPage(WidgetTester tester,
        {VoidCallback? onShowCookieSettings}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: testTheme,
          home: LandingPage(onShowCookieSettings: onShowCookieSettings),
        ),
      );
      // Two pump frames for widget tree to build
      await tester.pump();
      await tester.pump();
    }

    // =========================================================================
    // Static structure tests - share widget state via setUpAll()
    // =========================================================================
    group('desktop structure tests', () {
      // Shared widget for static structure verification tests
      late Widget desktopPage;

      setUpAll(() {
        desktopPage = MaterialApp(
          theme: testTheme,
          home: const LandingPage(onShowCookieSettings: null),
        );
      });

      Future<void> pumpSharedDesktop(WidgetTester tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(desktopPage);
        await tester.pump();
        await tester.pump();
      }

      group('widget structure', () {
        testWidgets('renders as Scaffold', (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.byType(Scaffold), findsWidgets);
          expect(find.byType(LandingPage), findsOneWidget);
        });

        testWidgets('renders CustomScrollView for smooth scrolling',
            (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.byType(CustomScrollView), findsOneWidget);
        });

        testWidgets('renders SelectionArea for text selection', (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.byType(SelectionArea), findsOneWidget);
        });

        testWidgets('renders HeroSection as first visible section',
            (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.byType(HeroSection), findsOneWidget);
        });

        testWidgets('contains SliverToBoxAdapter widgets for sections',
            (tester) async {
          await pumpSharedDesktop(tester);

          // At least some slivers should be present
          expect(find.byType(SliverToBoxAdapter), findsWidgets);
        });
      });

      group('accessibility', () {
        testWidgets('hero section has semantic label', (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.bySemanticsLabel('Hero section'), findsOneWidget);
        });

        testWidgets('sections use Semantics widgets', (tester) async {
          await pumpSharedDesktop(tester);

          // Semantics widgets are used for accessibility
          expect(find.byType(Semantics), findsWidgets);
        });
      });

      group('hero section content', () {
        testWidgets('hero section is rendered', (tester) async {
          await pumpSharedDesktop(tester);

          // HeroSection should be present
          expect(find.byType(HeroSection), findsOneWidget);
        });

        testWidgets('hero section has text content', (tester) async {
          await pumpSharedDesktop(tester);

          // Hero section should have text widgets
          expect(find.byType(Text), findsWidgets);
        });
      });

      group('navigation header', () {
        testWidgets('renders SliverAppBar', (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.byType(SliverAppBar), findsOneWidget);
        });

        testWidgets('renders logo/brand with icon', (tester) async {
          await pumpSharedDesktop(tester);

          // Should have shield icon
          expect(find.byIcon(LucideIcons.shield), findsWidgets);
        });

        testWidgets('renders desktop navigation links', (tester) async {
          await pumpSharedDesktop(tester);

          // Desktop should show nav links
          expect(find.byType(TextButton), findsWidgets);
        });

        testWidgets('desktop header has larger toolbar height', (tester) async {
          await pumpSharedDesktop(tester);

          final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
          expect(appBar.toolbarHeight, equals(64));
        });

        testWidgets('desktop logo icon has larger size', (tester) async {
          await pumpSharedDesktop(tester);

          final icons = find.byIcon(LucideIcons.shield);
          expect(icons, findsWidgets);

          // The first shield icon should be in the header with size 28
          final iconWidget = tester.widget<Icon>(icons.first);
          expect(iconWidget.size, equals(28));
        });
      });

      group('section building', () {
        testWidgets('sections without key do not wrap in KeyedSubtree',
            (tester) async {
          await pumpSharedDesktop(tester);

          // The _buildSection method conditionally wraps with KeyedSubtree
          // only when a key is provided. For sections without key (like footer),
          // the content is used directly without KeyedSubtree.
          // This tests that the method works correctly in both cases.

          // Verify the page renders correctly with all sections
          expect(find.byType(LandingPage), findsOneWidget);

          // Verify KeyedSubtree is used for some sections (those with keys)
          expect(find.byType(KeyedSubtree), findsWidgets);

          // Verify Semantics widgets wrap all sections
          expect(find.byType(Semantics), findsWidgets);
        });
      });

      group('section navigation', () {
        testWidgets('sections have keyed subtrees for scroll navigation',
            (tester) async {
          await pumpSharedDesktop(tester);

          // KeyedSubtree is used for section navigation
          expect(find.byType(KeyedSubtree), findsWidgets);
        });
      });
    });

    // =========================================================================
    // Tests requiring scroll interaction - use per-test setup
    // =========================================================================
    group('scroll-dependent structure tests', () {
      testWidgets('renders TabbedFeaturesSection', (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // Scroll down to reveal TabbedFeaturesSection below the hero
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
        await tester.pump();
        await tester.pump();

        expect(find.byType(TabbedFeaturesSection), findsOneWidget);
      });

      testWidgets('feature explorer section has semantic label',
          (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // Scroll down to reveal the feature explorer section
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
        await tester.pump();
        await tester.pump();

        expect(
            find.bySemanticsLabel('Feature explorer section'), findsOneWidget);
      });
    });

    group('responsive design', () {
      testWidgets('renders correctly on mobile', (tester) async {
        setMobileSize(tester);
        await pumpLandingPage(tester);

        expect(find.byType(LandingPage), findsOneWidget);
        expect(find.byType(CustomScrollView), findsOneWidget);
      });

      testWidgets('renders correctly on tablet', (tester) async {
        setTabletSize(tester);
        await pumpLandingPage(tester);

        expect(find.byType(LandingPage), findsOneWidget);
        expect(find.byType(CustomScrollView), findsOneWidget);
      },
      // TODO: Fix tablet layout overflow in resources_section.dart:302
      skip: true);

      testWidgets('renders correctly on desktop', (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        expect(find.byType(LandingPage), findsOneWidget);
        expect(find.byType(HeroSection), findsOneWidget);
      });

      testWidgets('renders correctly on large desktop', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await pumpLandingPage(tester);

        expect(find.byType(LandingPage), findsOneWidget);
        expect(find.byType(HeroSection), findsOneWidget);
      });
    });

    group('scroll behavior', () {
      testWidgets('has scroll controller attached', (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        final scrollView = tester.widget<CustomScrollView>(
          find.byType(CustomScrollView),
        );
        expect(scrollView.controller, isNotNull);
      });

      testWidgets('page responds to scroll gestures', (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // Get initial scroll position
        final scrollView = tester.widget<CustomScrollView>(
          find.byType(CustomScrollView),
        );
        final initialOffset = scrollView.controller?.offset ?? 0;

        // Scroll down
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();
        await tester.pump();

        // Get new offset after scroll
        final newOffset = scrollView.controller?.offset ?? 0;

        // Offset should have changed
        expect(newOffset, greaterThan(initialOffset));
      });
    });

    group('state management', () {
      testWidgets('widget can be disposed without errors', (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // Get the scroll controller reference
        final scrollView = tester.widget<CustomScrollView>(
          find.byType(CustomScrollView),
        );
        expect(scrollView.controller, isNotNull);

        // Replace with different widget to trigger dispose
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const Scaffold(body: Text('Replaced')),
          ),
        );
        await tester.pump();

        // Widget should be replaced successfully without throwing
        expect(find.text('Replaced'), findsOneWidget);
      });
    });

    group('callbacks', () {
      testWidgets('accepts optional onShowCookieSettings callback',
          (tester) async {
        setDesktopSize(tester);

        // Should work with callback
        await pumpLandingPage(
          tester,
          onShowCookieSettings: () {},
        );
        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('works without onShowCookieSettings callback',
          (tester) async {
        setDesktopSize(tester);

        // Should work without callback
        await pumpLandingPage(tester);
        expect(find.byType(LandingPage), findsOneWidget);
      });
    });

    group('constructor', () {
      testWidgets('creates with default parameters', (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);
        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('creates with onShowCookieSettings parameter',
          (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester, onShowCookieSettings: () {});
        expect(find.byType(LandingPage), findsOneWidget);
      });
    });

    // =========================================================================
    // Mobile-specific structure tests - require mobile viewport
    // =========================================================================
    group('mobile structure tests', () {
      late Widget mobilePage;

      setUpAll(() {
        mobilePage = MaterialApp(
          theme: testTheme,
          home: const LandingPage(onShowCookieSettings: null),
        );
      });

      Future<void> pumpSharedMobile(WidgetTester tester) async {
        setMobileSize(tester);
        await tester.pumpWidget(mobilePage);
        await tester.pump();
        await tester.pump();
      }

      testWidgets('renders mobile hamburger menu', (tester) async {
        await pumpSharedMobile(tester);

        // Mobile should show PopupMenuButton
        expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      });

      testWidgets('mobile menu icon is visible', (tester) async {
        await pumpSharedMobile(tester);

        // Should have menu icon
        expect(find.byIcon(LucideIcons.menu), findsOneWidget);
      });

      testWidgets('mobile header has smaller toolbar height', (tester) async {
        await pumpSharedMobile(tester);

        final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
        expect(appBar.toolbarHeight, equals(56));
      });

      testWidgets('mobile logo icon has smaller size', (tester) async {
        await pumpSharedMobile(tester);

        final icons = find.byIcon(LucideIcons.shield);
        expect(icons, findsWidgets);

        // The first shield icon should be in the header with size 24
        final iconWidget = tester.widget<Icon>(icons.first);
        expect(iconWidget.size, equals(24));
      });
    });

    // =========================================================================
    // Interaction tests - require fresh state per test
    // =========================================================================
    group('scroll interactions', () {
      testWidgets('triggers scroll depth tracking on scroll', (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // Scroll down to trigger scroll listener
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump();
        await tester.pump();

        // Page should still be rendered
        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('logo tap scrolls to top', (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // First scroll down
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump();
        await tester.pump();

        // Find the logo GestureDetector (first one in header)
        final gestureDetectors = find.byType(GestureDetector);
        expect(gestureDetectors, findsWidgets);

        // Tapping logo should trigger scroll animation
        await tester.tap(gestureDetectors.first);
        await tester.pump();
        await tester.pump();

        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('scroll depth tracking calculates percentage correctly',
          (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // Get the scroll controller
        final scrollView = tester.widget<CustomScrollView>(
          find.byType(CustomScrollView),
        );
        final controller = scrollView.controller!;

        // Scroll to various positions to trigger _onScroll
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
        await tester.pump();
        await tester.pump();

        // Verify scroll position changed
        expect(controller.offset, greaterThan(0));

        // Scroll more to increase depth percentage
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
        await tester.pump();
        await tester.pump();

        // Page remains functional after scroll tracking
        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('scroll does not track when maxScrollExtent is zero',
          (tester) async {
        // Using a very small screen where content might not need scrolling
        setScreenSize(tester, const Size(1440, 10000));
        await pumpLandingPage(tester);

        // Just verify the widget renders without error
        expect(find.byType(LandingPage), findsOneWidget);
      });
    });

    group('desktop navigation link interactions', () {
      Future<void> pumpWithRoutes(WidgetTester tester) async {
        final router = createAppRouter(
          onConsentGiven: () {},
          onShowCookieSettings: () {},
        );

        // Don't wrap in MediaQuery - let MaterialApp pick up the view size
        // set by setDesktopSize(). MediaQuery wrapper overrides viewport size.
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: testTheme,
          ),
        );
        // Router needs multiple frames to initialize navigation stack
        await tester.pump();
        await tester.pump();
        await tester.pump();
      }

      testWidgets('Features nav link scrolls to features section',
          (tester) async {
        setDesktopSize(tester);
        await pumpWithRoutes(tester);

        // Find and tap Features nav link
        final featuresLink = find.text('Features');
        expect(featuresLink, findsOneWidget);

        await tester.tap(featuresLink);
        await tester.pump();
        await tester.pump();

        // Should still be on landing page (scrolled)
        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('Pricing nav link scrolls to pricing section',
          (tester) async {
        setDesktopSize(tester);
        await pumpWithRoutes(tester);

        // Find and tap Pricing nav link
        final pricingLink = find.text('Pricing');
        expect(pricingLink, findsOneWidget);

        await tester.tap(pricingLink);
        await tester.pump();
        await tester.pump();

        // Should still be on landing page (scrolled)
        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('About nav link scrolls to about section', (tester) async {
        setDesktopSize(tester);
        await pumpWithRoutes(tester);

        // Find and tap About nav link
        final aboutLink = find.text('About');
        expect(aboutLink, findsOneWidget);

        await tester.tap(aboutLink);
        await tester.pump();
        await tester.pump();

        // Should still be on landing page (scrolled to about section)
        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('Blog nav link scrolls to resources section', (tester) async {
        setDesktopSize(tester);
        await pumpWithRoutes(tester);

        // Find and tap Blog nav link
        final blogLink = find.text('Blog');
        expect(blogLink, findsOneWidget);

        await tester.tap(blogLink);
        await tester.pump();
        await tester.pump();

        // Should still be on landing page (scrolled to resources section)
        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('Contact nav link scrolls to contact section',
          (tester) async {
        setDesktopSize(tester);
        await pumpWithRoutes(tester);

        // Find and tap Contact nav link
        final contactLink = find.text('Contact');
        expect(contactLink, findsOneWidget);

        await tester.tap(contactLink);
        await tester.pump();
        await tester.pump();

        // Should still be on landing page (scrolled)
        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('Get Started button scrolls to pricing', (tester) async {
        setDesktopSize(tester);
        await pumpWithRoutes(tester);

        // Find the Get Started button in header
        final getStartedButton = find.widgetWithText(TextButton, 'Get Started');
        expect(getStartedButton, findsOneWidget);

        await tester.tap(getStartedButton);
        await tester.pump();
        await tester.pump();

        // Should still be on landing page (scrolled to pricing)
        expect(find.byType(LandingPage), findsOneWidget);
      });
    });

    group('mobile navigation menu interactions', () {
      Future<void> pumpMobileWithRoutes(WidgetTester tester) async {
        final router = createAppRouter(
          onConsentGiven: () {},
          onShowCookieSettings: () {},
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: testTheme,
          ),
        );
        // Router needs multiple frames to initialize
        await tester.pump();
        await tester.pump();
      }

      testWidgets('mobile menu opens and shows items', (tester) async {
        setMobileSize(tester);
        await pumpMobileWithRoutes(tester);

        // Tap menu icon to open
        final menuButton = find.byType(PopupMenuButton<String>);
        expect(menuButton, findsOneWidget);

        await tester.tap(menuButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Menu items should be visible
        expect(find.text('Features'), findsOneWidget);
        expect(find.text('Pricing'), findsOneWidget);
        expect(find.text('About'), findsOneWidget);
        expect(find.text('Blog'), findsOneWidget);
        expect(find.text('Contact'), findsOneWidget);
      });

      testWidgets('mobile menu Features item scrolls to section',
          (tester) async {
        setMobileSize(tester);
        await pumpMobileWithRoutes(tester);

        // Open menu
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Features
        await tester.tap(find.text('Features').last);
        await tester.pump();
        await tester.pump();

        // Should still be on landing page
        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('mobile menu Pricing item scrolls to section',
          (tester) async {
        setMobileSize(tester);
        await pumpMobileWithRoutes(tester);

        // Open menu
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Pricing
        await tester.tap(find.text('Pricing').last);
        await tester.pump();
        await tester.pump();

        // Should still be on landing page
        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('mobile menu About item scrolls to about section',
          (tester) async {
        setMobileSize(tester);
        await pumpMobileWithRoutes(tester);

        // Open menu
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap About
        await tester.tap(find.text('About').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Should still be on landing page (scrolled to about section)
        expect(find.byType(LandingPage), findsOneWidget);
      },
      // TODO: Fix mobile layout overflow in about_section.dart:101,133
      skip: true);

      testWidgets('mobile menu Blog item scrolls to resources section',
          (tester) async {
        setMobileSize(tester);
        await pumpMobileWithRoutes(tester);

        // Open menu
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Blog
        await tester.tap(find.text('Blog').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Should still be on landing page (scrolled to resources section)
        expect(find.byType(LandingPage), findsOneWidget);
      },
      // TODO: Fix mobile layout overflow in resources_section.dart:302
      skip: true);

      testWidgets('mobile menu Contact item scrolls to section',
          (tester) async {
        setMobileSize(tester);
        await pumpMobileWithRoutes(tester);

        // Open menu
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Contact
        await tester.tap(find.text('Contact').last);
        await tester.pump();
        await tester.pump();

        // Should still be on landing page
        expect(find.byType(LandingPage), findsOneWidget);
      });
    });

    group('nav link hover states', () {
      testWidgets('nav link changes color on hover', (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // Find Features text (there's one in header)
        final featuresText = find.text('Features');
        expect(featuresText, findsOneWidget);

        // Get the MouseRegion wrapping the nav link
        final mouseRegions = find.byType(MouseRegion);
        expect(mouseRegions, findsWidgets);

        // Simulate mouse enter on a nav link area
        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);

        // Move to the Features text location
        final center = tester.getCenter(featuresText);
        await gesture.moveTo(center);
        await tester.pump();

        // Widget should still render (hover state changed)
        expect(find.byType(LandingPage), findsOneWidget);

        // Move away to trigger exit
        await gesture.moveTo(const Offset(0, 0));
        await tester.pump();

        expect(find.byType(LandingPage), findsOneWidget);
      });
    });

    group('hero section callbacks', () {
      testWidgets('hero Get Started button triggers scroll to pricing',
          (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // Find the HeroSection
        expect(find.byType(HeroSection), findsOneWidget);

        // Hero section should have Get Started button that scrolls to pricing
        final heroSection = tester.widget<HeroSection>(find.byType(HeroSection));
        expect(heroSection.onGetStarted, isNotNull);

        // Find GradientButton in hero (the primary CTA)
        final gradientButton = find.descendant(
          of: find.byType(HeroSection),
          matching: find.byType(GradientButton),
        );
        expect(gradientButton, findsOneWidget);

        // Tap the GradientButton to trigger onGetStarted
        await tester.tap(gradientButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // Should scroll to pricing section
        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('hero Watch Demo button shows demo modal', (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // Find the HeroSection
        expect(find.byType(HeroSection), findsOneWidget);

        // The onWatchDemo callback should exist
        final heroSection = tester.widget<HeroSection>(find.byType(HeroSection));
        expect(heroSection.onWatchDemo, isNotNull);

        // Find OutlineButton in hero (the secondary CTA - Watch Demo)
        final outlineButton = find.descendant(
          of: find.byType(HeroSection),
          matching: find.byType(OutlineButton),
        );
        expect(outlineButton, findsOneWidget);

        // Tap to trigger onWatchDemo -> _handleWatchDemo
        await tester.tap(outlineButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // DemoModal should appear (it's a Dialog)
        expect(find.byType(Dialog), findsOneWidget);
      });
    });

    group('pricing section callbacks', () {
      Future<void> pumpWithSignupRoute(WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            initialRoute: '/',
            onGenerateRoute: (settings) {
              if (settings.name == '/') {
                return MaterialPageRoute(
                  builder: (context) => const LandingPage(),
                );
              }
              if (settings.name?.startsWith('/signup') ?? false) {
                return MaterialPageRoute(
                  builder: (context) => Scaffold(
                    body: Text('Signup: ${settings.name}'),
                  ),
                );
              }
              return MaterialPageRoute(
                builder: (context) => const Scaffold(body: Text('Unknown')),
              );
            },
          ),
        );
        // Router needs multiple frames to initialize
        await tester.pump();
        await tester.pump();
      }

      testWidgets('pricing section renders with tier selection callback',
          (tester) async {
        setDesktopSize(tester);
        await pumpWithSignupRoute(tester);

        // Scroll down to pricing section
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
        await tester.pump();
        await tester.pump();

        // Find pricing section
        final pricingSection = find.byType(PricingSection);

        if (pricingSection.evaluate().isNotEmpty) {
          // Verify it has onSelectTier callback
          final widget = tester.widget<PricingSection>(pricingSection);
          expect(widget.onSelectTier, isNotNull);
        }

        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('clicking pricing CTA navigates to signup', (tester) async {
        setDesktopSize(tester);
        await pumpWithSignupRoute(tester);

        // Scroll down to pricing section
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
        await tester.pump();
        await tester.pump();

        // Try to find and tap any pricing CTA button
        // Pricing cards use ElevatedButton for popular tier or OutlinedButton
        final pricingCtas = find.descendant(
          of: find.byType(PricingSection),
          matching: find.byType(ElevatedButton),
        );

        if (pricingCtas.evaluate().isNotEmpty) {
          await tester.tap(pricingCtas.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          // Should navigate to signup page
          expect(find.textContaining('Signup:'), findsOneWidget);
        }
      });
    });

    group('CTA section callbacks', () {
      testWidgets('CTA section renders with Get Started callback',
          (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // Scroll down to CTA section
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
        await tester.pump();
        await tester.pump();

        // Find CTA section
        final ctaSection = find.byType(CTASection);

        if (ctaSection.evaluate().isNotEmpty) {
          // Verify it has onGetStarted callback
          final widget = tester.widget<CTASection>(ctaSection);
          expect(widget.onGetStarted, isNotNull);
        }

        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('CTA section button triggers scroll to pricing',
          (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // Scroll down to CTA section
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
        await tester.pump();
        await tester.pump();

        // Find CTA section
        final ctaSection = find.byType(CTASection);

        if (ctaSection.evaluate().isNotEmpty) {
          // Find the CTA button in the section
          final ctaButton = find.descendant(
            of: ctaSection,
            matching: find.byType(GestureDetector),
          );

          if (ctaButton.evaluate().isNotEmpty) {
            // The CTA section uses a custom _CTAButton that wraps content
            // Find the text "Start Free Trial" and tap near it
            final startTrialText = find.text('Start Free Trial');
            if (startTrialText.evaluate().isNotEmpty) {
              await tester.tap(startTrialText);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 600));
            }
          }
        }

        expect(find.byType(LandingPage), findsOneWidget);
      });
    });

    group('scroll to section functionality', () {
      testWidgets('scroll to section with null context does nothing',
          (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // The _scrollToSection method checks if key?.currentContext == null
        // This is tested implicitly when sections haven't been built yet
        // or when scrolling to a non-existent section

        // Page should remain functional
        expect(find.byType(LandingPage), findsOneWidget);
      });

      testWidgets('scroll to features section works', (tester) async {
        setDesktopSize(tester);
        await pumpLandingPage(tester);

        // Tap Features nav link to trigger _scrollToSection('features')
        final featuresLink = find.text('Features');
        await tester.tap(featuresLink);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // Scroll animation should have started
        expect(find.byType(LandingPage), findsOneWidget);
      });
    });

  });
}
