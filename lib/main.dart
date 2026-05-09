import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const RootScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOT SCREEN — holds the nav state and switches pages
// ─────────────────────────────────────────────────────────────────────────────
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _currentIndex = 0;

  static const _pages = [
    _HomePage(),
    _ExplorePage(),
    _NotificationsPage(),
    _ProfilePage(),
  ];

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Global gradient background — shared across all pages
          const _GlobalBackground(),

          // Page content with AnimatedSwitcher for smooth crossfade
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: KeyedSubtree(
              key: ValueKey(_currentIndex),
              child: _pages[_currentIndex],
            ),
          ),

          // iOS 26 Liquid Glass Bottom Nav — floats above everything
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _LiquidGlassNavBar(
              currentIndex: _currentIndex,
              onTap: _onTabTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// iOS 26 LIQUID GLASS BOTTOM NAV BAR
// ─────────────────────────────────────────────────────────────────────────────
class _LiquidGlassNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<_LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<_LiquidGlassNavBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _bounceCtrl;
  late List<Animation<double>> _bounceAnim;

  late AnimationController _pillCtrl;
  late Animation<double> _pillAnim;
  int _prevIndex = 0;

  static const _items = [
    _NavItem(icon: Icons.house_rounded, label: 'Home'),
    _NavItem(icon: Icons.compass_calibration_rounded, label: 'Explore'),
    _NavItem(icon: Icons.notifications_rounded, label: 'Alerts'),
    _NavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _bounceCtrl = List.generate(
      _items.length,
          (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
      ),
    );
    _bounceAnim = _bounceCtrl.map((ctrl) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.28).chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.28, end: 0.88).chain(CurveTween(curve: Curves.easeIn)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.88, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
          weight: 40,
        ),
      ]).animate(ctrl);
    }).toList();

    _pillCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pillAnim = Tween<double>(
      begin: widget.currentIndex.toDouble(),
      end: widget.currentIndex.toDouble(),
    ).animate(CurvedAnimation(parent: _pillCtrl, curve: Curves.easeOutQuart));
  }

  @override
  void didUpdateWidget(_LiquidGlassNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _pillAnim = Tween<double>(
        begin: _prevIndex.toDouble(),
        end: widget.currentIndex.toDouble(),
      ).animate(CurvedAnimation(parent: _pillCtrl, curve: Curves.easeOutQuart));
      _pillCtrl..reset()..forward();
      _bounceCtrl[widget.currentIndex]..reset()..forward();
      _prevIndex = widget.currentIndex;
    }
  }

  @override
  void dispose() {
    for (final c in _bounceCtrl) {
      c.dispose();
    }
    _pillCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final safeBottom = mq.padding.bottom;
    final screenW = mq.size.width;

    const double barHeight = 72.0;
    const double sidePadding = 20.0;
    final double barWidth = screenW - sidePadding * 2;
    final double itemW = barWidth / _items.length;

    const double pillH = 52.0;
    final double pillW = itemW - 12.0;

    return Padding(
      padding: EdgeInsets.only(bottom: safeBottom + 12),
      child: Center(
        child: SizedBox(
          width: barWidth,
          height: barHeight,
          child: OCLiquidGlassGroup(
            settings: const OCLiquidGlassSettings(
              refractStrength: -0.055,
              blurRadiusPx: 2.5,
              specStrength: 22.0,
              specAngle: 140.0,
              specPower: 16.0,
              specWidth: 2.5,
              lightbandColor: Color(0xCCFFFFFF),
              lightbandStrength: 0.65,
              lightbandWidthPx: 3.0,
              lightbandOffsetPx: 1.8,
              blendPx: 8.0,
              distortFalloffPx: 40.0,
              distortExponent: 2.5,
            ),
            child: Stack(
              children: [
                OCLiquidGlass(
                  width: barWidth,
                  height: barHeight,
                  borderRadius: barHeight / 2,
                  color: Colors.white.withOpacity(0.09),
                  shadow: BoxShadow(
                    color: Colors.black.withOpacity(0.30),
                    blurRadius: 40,
                    spreadRadius: -4,
                    offset: const Offset(0, 14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(barHeight / 2),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(barHeight / 2),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.22),
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.16),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.32),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _pillAnim,
                  builder: (context, _) {
                    final pillLeft = _pillAnim.value * itemW + (itemW - pillW) / 2;
                    return Positioned(
                      left: pillLeft,
                      top: (barHeight - pillH) / 2,
                      child: OCLiquidGlass(
                        width: pillW,
                        height: pillH,
                        borderRadius: pillH / 2,
                        color: Colors.white.withOpacity(0.18),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(pillH / 2),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(pillH / 2),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.32),
                                    Colors.white.withOpacity(0.12),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.50),
                                  width: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(
                  width: barWidth,
                  height: barHeight,
                  child: Row(
                    children: _items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final bool sel = widget.currentIndex == i;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onTap(i),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedBuilder(
                            animation: _bounceAnim[i],
                            builder: (context, _) {
                              return Transform.scale(
                                scale: sel ? _bounceAnim[i].value : 1.0,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 220),
                                      transitionBuilder: (child, anim) =>
                                          ScaleTransition(scale: anim, child: child),
                                      child: Icon(
                                        item.icon,
                                        key: ValueKey(sel),
                                        color: sel ? Colors.white : Colors.white.withOpacity(0.40),
                                        size: sel ? 26 : 24,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 220),
                                      style: TextStyle(
                                        color: sel ? Colors.white : Colors.white.withOpacity(0.40),
                                        fontSize: 10,
                                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                        letterSpacing: sel ? 0.2 : 0.0,
                                      ),
                                      child: Text(item.label),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// GLOBAL BACKGROUND
// ─────────────────────────────────────────────────────────────────────────────
class _GlobalBackground extends StatelessWidget {
  const _GlobalBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF060612),
                Color(0xFF0B1530),
                Color(0xFF111D45),
                Color(0xFF0E2340),
                Color(0xFF0A1A28),
              ],
              stops: [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
        ),
        Positioned(top: -100, left: -80, child: _GlowOrb(color: const Color(0xFF4A7FFF), size: 320)),
        Positioned(top: 160, right: -90, child: _GlowOrb(color: const Color(0xFFAA44FF), size: 260)),
        Positioned(bottom: 220, left: -50, child: _GlowOrb(color: const Color(0xFF00AAFF), size: 240)),
        Positioned(bottom: -80, right: 30, child: _GlowOrb(color: const Color(0xFF22DDAA), size: 200)),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.26),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS CARD — Single Unified Definition
// ─────────────────────────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;

  const _GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.16),
                Colors.white.withOpacity(0.06),
                Colors.white.withOpacity(0.12),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.28),
              width: 0.7,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET SYSTEM
// ─────────────────────────────────────────────────────────────────────────────
class LiquidGlassAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const LiquidGlassAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}

class LiquidGlassBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool showHandle = true,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.40),
      isScrollControlled: true,
      builder: (ctx) => _LiquidSheetContent(
        title: title,
        showHandle: showHandle,
        child: child,
      ),
    );
  }

  static Future<void> showActions({
    required BuildContext context,
    required List<LiquidGlassAction> actions,
    String? title,
    String? message,
    bool isDismissible = true,
  }) {
    return show(
      context: context,
      title: title,
      isDismissible: isDismissible,
      child: _ActionsContent(actions: actions, message: message),
    );
  }
}

class _LiquidSheetContent extends StatefulWidget {
  final Widget child;
  final String? title;
  final bool showHandle;
  const _LiquidSheetContent({required this.child, this.title, this.showHandle = true});

  @override
  State<_LiquidSheetContent> createState() => _LiquidSheetContentState();
}

class _LiquidSheetContentState extends State<_LiquidSheetContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slide, _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(_slide),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, safeBottom + 12),
            child: OCLiquidGlassGroup(
              settings: const OCLiquidGlassSettings(
                refractStrength: -0.06,
                blurRadiusPx: 3.0,
                specStrength: 20.0,
                specAngle: 135.0,
                specPower: 14.0,
                specWidth: 2.8,
                lightbandColor: Color(0xCCFFFFFF),
                lightbandStrength: 0.60,
                lightbandWidthPx: 3.5,
                lightbandOffsetPx: 2.0,
                blendPx: 6.0,
                distortFalloffPx: 36.0,
                distortExponent: 2.4,
              ),
              child: OCLiquidGlass(
                borderRadius: 28,
                color: Colors.white.withOpacity(0.10),
                shadow: BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 48,
                  spreadRadius: -4,
                  offset: const Offset(0, 16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.20),
                            Colors.white.withOpacity(0.08),
                            Colors.white.withOpacity(0.14),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        border: Border.all(color: Colors.white.withOpacity(0.35), width: 0.8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.showHandle) ...[
                            const SizedBox(height: 12),
                            _Handle(),
                          ],
                          if (widget.title != null) ...[
                            const SizedBox(height: 16),
                            _SheetTitle(title: widget.title!),
                            _Separator(),
                          ] else
                            const SizedBox(height: 8),
                          widget.child,
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionsContent extends StatelessWidget {
  final List<LiquidGlassAction> actions;
  final String? message;
  const _ActionsContent({required this.actions, this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withOpacity(0.50), height: 1.45)),
          ),
        ...actions.asMap().entries.map((e) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionTile(action: e.value),
            if (e.key != actions.length - 1) _Separator(),
          ],
        )),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ActionTile extends StatefulWidget {
  final LiquidGlassAction action;
  const _ActionTile({required this.action});
  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.action.isDestructive ? const Color(0xFFFF453A) : Colors.white;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop();
        widget.action.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _pressed ? Colors.white.withOpacity(0.10) : Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.action.isDestructive
                    ? const Color(0xFFFF453A).withOpacity(0.16)
                    : Colors.white.withOpacity(0.12),
                border: Border.all(color: Colors.white.withOpacity(0.18), width: 0.5),
              ),
              child: Icon(widget.action.icon, color: color, size: 19),
            ),
            const SizedBox(width: 14),
            Text(widget.action.label,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: -0.2)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.25), size: 20),
          ]),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.30), borderRadius: BorderRadius.circular(2)),
    ),
  );
}

class _SheetTitle extends StatelessWidget {
  final String title;
  const _SheetTitle({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
    child: Text(title,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3)),
  );
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 0.4,
    color: Colors.white.withOpacity(0.14),
    indent: 20,
    endIndent: 20,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE 1 — HOME
// ─────────────────────────────────────────────────────────────────────────────
class _HomePage extends StatelessWidget {
  const _HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, mq.padding.top + 20, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Good Morning ☀️',
                    style: TextStyle(
                        fontSize: 13, color: Colors.white.withOpacity(0.55), letterSpacing: 0.2)),
                const SizedBox(height: 3),
                const Text('Welcome Back',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1.0)),
              ]),
              _GlassIconButton(
                  icon: Icons.notifications_rounded, onTap: () => _showNotifSheet(context)),
            ],
          ),
          const SizedBox(height: 28),
          _GlassCard(
            padding: const EdgeInsets.all(24),
            radius: 26,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF4A7FFF), Color(0xFFAA44FF)]),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Your Progress',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('This week', style: TextStyle(color: Colors.white.withOpacity(0.50), fontSize: 12)),
                ]),
                const Spacer(),
                const Text('↑ 24%',
                    style: TextStyle(
                        color: Color(0xFF22DDAA), fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 20),
              _GlassProgressBar(value: 0.72),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('72% complete', style: TextStyle(color: Colors.white.withOpacity(0.60), fontSize: 12)),
                Text('Goal: 100%', style: TextStyle(color: Colors.white.withOpacity(0.40), fontSize: 12)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Quick Actions',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4)),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.1,
            children: [
              _QuickActionCard(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  color: const Color(0xFF4A7FFF),
                  onTap: () => _showShareSheet(context)),
              _QuickActionCard(
                  icon: Icons.tune_rounded,
                  label: 'Settings',
                  color: const Color(0xFFAA44FF),
                  onTap: () => _showSettingsSheet(context)),
              _QuickActionCard(
                  icon: Icons.more_horiz_rounded,
                  label: 'Options',
                  color: const Color(0xFF00AAFF),
                  onTap: () => _showActionsSheet(context)),
              _QuickActionCard(
                  icon: Icons.add_circle_rounded,
                  label: 'New',
                  color: const Color(0xFF22DDAA),
                  onTap: () => _showNewSheet(context)),
            ],
          ),
          const SizedBox(height: 20),
          const Row(children: [
            Expanded(
                child: _StatCard(
                    value: '2.4k',
                    label: 'Points',
                    icon: Icons.stars_rounded,
                    color: Color(0xFFFFAA00))),
            SizedBox(width: 14),
            Expanded(
                child: _StatCard(
                    value: '18',
                    label: 'Streak',
                    icon: Icons.local_fire_department_rounded,
                    color: Color(0xFFFF5A3C))),
            SizedBox(width: 14),
            Expanded(
                child: _StatCard(
                    value: '94%',
                    label: 'Score',
                    icon: Icons.trending_up_rounded,
                    color: Color(0xFF22DDAA))),
          ]),
          const SizedBox(height: 28),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Recent Activity',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4)),
            GestureDetector(
              onTap: () {},
              child: const Text('See all',
                  style: TextStyle(
                      color: Color(0xFF4A7FFF), fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 16),
          ..._activityItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ActivityRow(item: item),
          )),

        ],
      ),
    );
  }

  static const _activityItems = [
    _Activity(
        icon: Icons.check_circle_rounded,
        label: 'Completed Task #12',
        time: '2m ago',
        color: Color(0xFF22DDAA)),
    _Activity(
        icon: Icons.star_rounded, label: 'Earned 50 points', time: '1h ago', color: Color(0xFFFFAA00)),
    _Activity(
        icon: Icons.message_rounded,
        label: 'New message received',
        time: '3h ago',
        color: Color(0xFF4A7FFF)),
    _Activity(
        icon: Icons.upload_rounded,
        label: 'Report uploaded',
        time: 'Yesterday',
        color: Color(0xFFAA44FF)),
  ];

  void _showNotifSheet(BuildContext context) => LiquidGlassBottomSheet.showActions(
    context: context,
    title: 'Notifications',
    actions: [
      LiquidGlassAction(icon: Icons.check_circle_rounded, label: 'Mark all as read', onTap: () {}),
      LiquidGlassAction(icon: Icons.settings_rounded, label: 'Notification settings', onTap: () {}),
      LiquidGlassAction(
          icon: Icons.delete_rounded, label: 'Clear all', onTap: () {}, isDestructive: true),
    ],
  );

  void _showShareSheet(BuildContext context) => LiquidGlassBottomSheet.showActions(
    context: context,
    title: 'Share',
    message: 'Choose how you\'d like to share',
    actions: [
      LiquidGlassAction(icon: Icons.copy_rounded, label: 'Copy Link', onTap: () {}),
      LiquidGlassAction(icon: Icons.mail_rounded, label: 'Email', onTap: () {}),
      LiquidGlassAction(icon: Icons.message_rounded, label: 'Message', onTap: () {}),
    ],
  );

  void _showSettingsSheet(BuildContext context) => LiquidGlassBottomSheet.show(
      context: context, title: 'Preferences', child: const _SettingsSheetBody());

  void _showActionsSheet(BuildContext context) => LiquidGlassBottomSheet.showActions(
    context: context,
    title: 'Options',
    actions: [
      LiquidGlassAction(icon: Icons.edit_rounded, label: 'Edit', onTap: () {}),
      LiquidGlassAction(icon: Icons.bookmark_rounded, label: 'Save', onTap: () {}),
      LiquidGlassAction(
          icon: Icons.delete_rounded, label: 'Delete', onTap: () {}, isDestructive: true),
    ],
  );

  void _showNewSheet(BuildContext context) => LiquidGlassBottomSheet.show(
      context: context, title: 'Create New', child: const _NewItemSheetBody());
}

class _Activity {
  final IconData icon;
  final String label;
  final String time;
  final Color color;
  const _Activity({required this.icon, required this.label, required this.time, required this.color});
}

class _ActivityRow extends StatelessWidget {
  final _Activity item;
  const _ActivityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 16,
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.color.withOpacity(0.18),
              border: Border.all(color: item.color.withOpacity(0.35), width: 0.6)),
          child: Icon(item.icon, color: item.color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Text(item.label,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
        Text(item.time, style: TextStyle(color: Colors.white.withOpacity(0.40), fontSize: 12)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      radius: 18,
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.50), fontSize: 11)),
      ]),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard(
      {required this.icon, required this.label, required this.color, required this.onTap});

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _s = Tween(begin: 1.0, end: 0.93).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: _GlassCard(
          radius: 22,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(0.18),
                  border: Border.all(color: widget.color.withOpacity(0.38), width: 0.7)),
              child: Icon(widget.icon, color: widget.color, size: 25),
            ),
            const SizedBox(height: 12),
            Text(widget.label,
                style:
                const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _GlassProgressBar extends StatelessWidget {
  final double value;
  const _GlassProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(children: [
        Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.white.withOpacity(0.12),
            )),
        FractionallySizedBox(
          widthFactor: value,
          child: Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(colors: [Color(0xFF4A7FFF), Color(0xFF22DDAA)]),
              )),
        ),
      ]),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: Colors.white.withOpacity(0.14),
              border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.7),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE 2 — EXPLORE
// ─────────────────────────────────────────────────────────────────────────────
class _ExplorePage extends StatelessWidget {
  const _ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, mq.padding.top + 20, 24, 120),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Explore',
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.0)),
        const SizedBox(height: 6),
        Text('Discover something new',
            style: TextStyle(color: Colors.white.withOpacity(0.50), fontSize: 15)),
        const SizedBox(height: 24),
        _GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          radius: 18,
          child: Row(children: [
            Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.50), size: 20),
            const SizedBox(width: 12),
            Text('Search anything...',
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 15)),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('Categories',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: ['All', 'Design', 'Tech', 'Art', 'Music', 'Sport'].asMap().entries.map((e) {
              final bool sel = e.key == 0;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: sel ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.09),
                        border: Border.all(color: Colors.white.withOpacity(sel ? 0.45 : 0.18), width: 0.7),
                      ),
                      child: Text(e.value,
                          style: TextStyle(
                              color: sel ? Colors.white : Colors.white.withOpacity(0.55),
                              fontSize: 13,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.85),
          itemCount: _exploreItems.length,
          itemBuilder: (context, i) {
            final item = _exploreItems[i];
            return _GlassCard(
              padding: const EdgeInsets.all(16),
              radius: 20,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                        colors: [item.color.withOpacity(0.4), item.color.withOpacity(0.15)]),
                  ),
                  child: Center(child: Icon(item.icon, color: item.color, size: 36)),
                ),
                const SizedBox(height: 12),
                Text(item.title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(item.subtitle, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
              ]),
            );
          },
        ),
      ]),
    );
  }

  static const _exploreItems = [
    _ExploreItem(
        icon: Icons.palette_rounded, title: 'UI Design', subtitle: '240 items', color: Color(0xFF4A7FFF)),
    _ExploreItem(
        icon: Icons.code_rounded, title: 'Development', subtitle: '180 items', color: Color(0xFFAA44FF)),
    _ExploreItem(
        icon: Icons.music_note_rounded, title: 'Music', subtitle: '95 items', color: Color(0xFFFF5A3C)),
    _ExploreItem(
        icon: Icons.camera_alt_rounded,
        title: 'Photography',
        subtitle: '312 items',
        color: Color(0xFF22DDAA)),
    _ExploreItem(
        icon: Icons.sports_rounded, title: 'Sports', subtitle: '67 items', color: Color(0xFFFFAA00)),
    _ExploreItem(
        icon: Icons.restaurant_rounded, title: 'Food', subtitle: '145 items', color: Color(0xFFFF6B9D)),
  ];
}

class _ExploreItem {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _ExploreItem({required this.icon, required this.title, required this.subtitle, required this.color});
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE 3 — NOTIFICATIONS
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage({super.key});

  static const _notifs = [
    _Notif(
        icon: Icons.check_circle_rounded,
        title: 'Task completed!',
        body: 'Your task "Design Review" was completed.',
        time: '2m',
        color: Color(0xFF22DDAA),
        unread: true),
    _Notif(
        icon: Icons.star_rounded,
        title: 'You earned a badge',
        body: 'Congratulations! You unlocked Gold badge.',
        time: '1h',
        color: Color(0xFFFFAA00),
        unread: true),
    _Notif(
        icon: Icons.message_rounded,
        title: 'New message',
        body: 'Alex: "Hey, can we sync up tomorrow?"',
        time: '3h',
        color: Color(0xFF4A7FFF),
        unread: false),
    _Notif(
        icon: Icons.upload_rounded,
        title: 'Upload successful',
        body: 'Your report has been uploaded.',
        time: '5h',
        color: Color(0xFFAA44FF),
        unread: false),
  ];

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, mq.padding.top + 20, 24, 120),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Notifications',
              style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.0)),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF4A7FFF).withOpacity(0.22),
                  border: Border.all(color: const Color(0xFF4A7FFF).withOpacity(0.45), width: 0.7),
                ),
                child: const Text('2 new',
                    style: TextStyle(color: Color(0xFF4A7FFF), fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        ..._notifs.map((n) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _NotifCard(notif: n),
        )),
      ]),
    );
  }
}

class _Notif {
  final IconData icon;
  final String title, body, time;
  final Color color;
  final bool unread;
  const _Notif({required this.icon, required this.title, required this.body, required this.time, required this.color, required this.unread});
}

class _NotifCard extends StatelessWidget {
  final _Notif notif;
  const _NotifCard({required this.notif});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      radius: 18,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: notif.color.withOpacity(0.18),
              border: Border.all(color: notif.color.withOpacity(0.35), width: 0.6)),
          child: Icon(notif.icon, color: notif.color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(notif.title,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: notif.unread ? FontWeight.w700 : FontWeight.w500))),
                if (notif.unread)
                  Container(
                      width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4A7FFF))),
              ]),
              const SizedBox(height: 4),
              Text(notif.body,
                  style: TextStyle(color: Colors.white.withOpacity(0.50), fontSize: 12, height: 1.4)),
              const SizedBox(height: 6),
              Text('${notif.time} ago', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
            ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE 4 — PROFILE
// ─────────────────────────────────────────────────────────────────────────────
class _ProfilePage extends StatelessWidget {
  const _ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, mq.padding.top + 20, 24, 120),
      child: Column(children: [
        Column(children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4A7FFF), Color(0xFFAA44FF)]),
              border: Border.all(color: Colors.white.withOpacity(0.35), width: 2.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFF4A7FFF).withOpacity(0.40), blurRadius: 24, spreadRadius: -4)
              ],
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 14),
          const Text('Alex Johnson',
              style: TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('alex@example.com', style: TextStyle(color: Colors.white.withOpacity(0.50), fontSize: 14)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const _ProfileStat(value: '2.4k', label: 'Points'),
            _VertDivider(),
            const _ProfileStat(value: '18', label: 'Streak'),
            _VertDivider(),
            const _ProfileStat(value: '47', label: 'Tasks'),
          ]),
        ]),
        const SizedBox(height: 28),
        const _SectionLabel('Account'),
        const SizedBox(height: 12),
        _GlassCard(
          padding: EdgeInsets.zero,
          radius: 20,
          child: Column(children: [
            _ProfileMenuRow(icon: Icons.edit_rounded, label: 'Edit Profile', onTap: () {}),
            _Separator(),
            _ProfileMenuRow(icon: Icons.security_rounded, label: 'Privacy & Security', onTap: () {}),
            _Separator(),
            _ProfileMenuRow(icon: Icons.palette_rounded, label: 'Appearance', onTap: () {}),
          ]),
        ),
        const SizedBox(height: 20),
        const _SectionLabel('Support'),
        const SizedBox(height: 12),
        _GlassCard(
          padding: EdgeInsets.zero,
          radius: 20,
          child: Column(children: [
            _ProfileMenuRow(icon: Icons.help_outline_rounded, label: 'Help Center', onTap: () {}),
            _Separator(),
            _ProfileMenuRow(icon: Icons.star_outline_rounded, label: 'Rate the App', onTap: () {}),
          ]),
        ),
        const SizedBox(height: 20),
        _GlassCard(
          padding: EdgeInsets.zero,
          radius: 20,
          child: _ProfileMenuRow(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            onTap: () => LiquidGlassBottomSheet.showActions(
              context: context,
              title: 'Sign Out',
              message: 'Are you sure you want to sign out?',
              actions: [
                LiquidGlassAction(icon: Icons.logout_rounded, label: 'Sign Out', onTap: () {}, isDestructive: true),
              ],
            ),
            isDestructive: true,
          ),
        ),
      ]),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value, label;
  const _ProfileStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(children: [
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
    ]),
  );
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 0.6, height: 36, color: Colors.white.withOpacity(0.18));
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(label,
        style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8)),
  );
}

class _ProfileMenuRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const _ProfileMenuRow({required this.icon, required this.label, required this.onTap, this.isDestructive = false});
  @override
  State<_ProfileMenuRow> createState() => _ProfileMenuRowState();
}

class _ProfileMenuRowState extends State<_ProfileMenuRow> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive ? const Color(0xFFFF453A) : Colors.white;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _pressed ? Colors.white.withOpacity(0.08) : Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(children: [
            Icon(widget.icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(widget.label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.25), size: 20),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET BODY WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsSheetBody extends StatefulWidget {
  const _SettingsSheetBody({super.key});
  @override
  State<_SettingsSheetBody> createState() => _SettingsSheetBodyState();
}

class _SettingsSheetBodyState extends State<_SettingsSheetBody> {
  bool _notif = true, _dark = true, _haptics = true;
  double _brightness = 0.7;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _ToggleRow(
          icon: Icons.notifications_rounded,
          label: 'Notifications',
          value: _notif,
          onChanged: (v) => setState(() => _notif = v)),
      _Separator(),
      _ToggleRow(
          icon: Icons.dark_mode_rounded,
          label: 'Dark Mode',
          value: _dark,
          onChanged: (v) => setState(() => _dark = v)),
      _Separator(),
      _ToggleRow(
          icon: Icons.vibration_rounded,
          label: 'Haptics',
          value: _haptics,
          onChanged: (v) => setState(() => _haptics = v)),
      _Separator(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                  border: Border.all(color: Colors.white.withOpacity(0.18), width: 0.5)),
              child: const Icon(Icons.brightness_6_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Brightness',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white.withOpacity(0.8),
                    inactiveTrackColor: Colors.white.withOpacity(0.2),
                    thumbColor: Colors.white,
                    trackHeight: 3,
                    overlayColor: Colors.white.withOpacity(0.1),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(value: _brightness, onChanged: (v) => setState(() => _brightness = v)),
                ),
              ])),
        ]),
      ),
    ]);
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
                border: Border.all(color: Colors.white.withOpacity(0.18), width: 0.5)),
            child: Icon(icon, color: Colors.white, size: 18)),
        const SizedBox(width: 14),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
        const Spacer(),
        Switch.adaptive(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF34C759),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white24),
      ]),
    );
  }
}

class _NewItemSheetBody extends StatelessWidget {
  const _NewItemSheetBody({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.task_alt_rounded, 'New Task', const Color(0xFF22DDAA)),
      (Icons.folder_rounded, 'New Project', const Color(0xFF4A7FFF)),
      (Icons.note_add_rounded, 'New Note', const Color(0xFFAA44FF)),
      (Icons.calendar_today_rounded, 'New Event', const Color(0xFFFFAA00)),
    ];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ...actions.asMap().entries.map((e) {
        final isLast = e.key == actions.length - 1;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          _ActionTile(action: LiquidGlassAction(icon: e.value.$1, label: e.value.$2, onTap: () {})),
          if (!isLast) _Separator(),
        ]);
      }),
      const SizedBox(height: 8),
    ]);
  }
}