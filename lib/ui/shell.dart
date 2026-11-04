import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/net.dart';
import '../core/services.dart';
import '../core/theme.dart';
import 'home_page.dart';
import 'reco_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'sources_page.dart';
import 'widgets.dart';

class _Tab {
  const _Tab(this.key, this.icon, this.activeIcon);
  final String key;
  final IconData icon, activeIcon;
}

const _tabs = [
  _Tab('nav.home', Icons.home_outlined, Icons.home_rounded),
  _Tab('nav.reco', Icons.auto_awesome_outlined, Icons.auto_awesome_rounded),
  _Tab('nav.search', Icons.search_rounded, Icons.manage_search_rounded),
  _Tab('nav.sources', Icons.extension_outlined, Icons.extension_rounded),
  _Tab('nav.settings', Icons.tune_rounded, Icons.tune_rounded),
];

/// Lets a page switch tabs (e.g. "go install a source").
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.select, required this.current, required super.child});
  final ValueChanged<int> select;
  final ValueListenable<int> current;

  static ShellScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellScope>()!;

  @override
  bool updateShouldNotify(ShellScope old) => false;
}

/// Tablet-first frame: a sidebar in landscape, a floating tab bar in portrait.
/// Each tab keeps its own navigation stack, so a manga page opens beside the sidebar.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  final _current = ValueNotifier(0);
  final _visited = <int>{0};
  final _navigators = List.generate(_tabs.length, (_) => GlobalKey<NavigatorState>());

  void _select(int i) {
    if (i == _index) {
      // Tapping the current tab again goes back to its root.
      _navigators[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _index = i;
      _current.value = i;
      _visited.add(i);
    });
    if (i == 1) Services.i.reco.onVisit();
  }

  Widget _page(int i) => switch (i) {
        0 => const HomePage(),
        1 => const RecoPage(),
        2 => const SearchPage(),
        3 => const SourcesPage(),
        _ => const SettingsPage(),
      };

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 820;
    final content = Stack(children: [
      for (var i = 0; i < _tabs.length; i++)
        if (_visited.contains(i))
          Offstage(
            offstage: i != _index,
            child: TickerMode(
              enabled: i == _index,
              child: _FadeIn(
                visible: i == _index,
                child: HeroControllerScope(
                  controller: MaterialApp.createMaterialHeroController(),
                  child: Navigator(
                    key: _navigators[i],
                    onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _page(i)),
                  ),
                ),
              ),
            ),
          ),
    ]);

    return ShellScope(
      current: _current,
      select: _select,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final nav = _navigators[_index].currentState;
          if (nav != null && nav.canPop()) {
            nav.pop();
          } else if (_index != 0) {
            _select(0);
          }
        },
        child: Scaffold(
          backgroundColor: p.bg,
          body: wide
              ? Row(children: [
                  _Sidebar(index: _index, onSelect: _select),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
                      child: ColoredBox(color: p.bg, child: content),
                    ),
                  ),
                ])
              : Stack(children: [
                  Positioned.fill(child: content),
                  Positioned(left: 16, right: 16, bottom: 14, child: SafeArea(top: false, child: _BottomBar(index: _index, onSelect: _select))),
                ]),
        ),
      ),
    );
  }
}

class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: 1);

  @override
  void didUpdateWidget(_FadeIn old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: CurvedAnimation(parent: _c, curve: Motion.easeOut), child: widget.child);
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _itemHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      width: 236,
      color: p.sidebar,
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 30, 18, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(left: 8), child: BrandMark()),
            const SizedBox(height: 46),
            SizedBox(
              height: _itemHeight * _tabs.length,
              child: Stack(children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 340),
                  curve: Motion.easeOut,
                  top: index * _itemHeight,
                  left: 0,
                  right: 0,
                  height: _itemHeight - 6,
                  child: DecoratedBox(decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(14))),
                ),
                Column(children: [
                  for (var i = 0; i < _tabs.length; i++)
                    SizedBox(
                      height: _itemHeight,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Pressable(
                          onTap: () => onSelect(i),
                          scale: 0.98,
                          child: SizedBox(
                            height: _itemHeight - 6,
                            child: Row(children: [
                              const SizedBox(width: 14),
                              Icon(i == index ? _tabs[i].activeIcon : _tabs[i].icon, size: 21, color: i == index ? p.accent : p.text3),
                              const SizedBox(width: 14),
                              Expanded(
                                child: AnimatedDefaultTextStyle(
                                  duration: Motion.fast,
                                  style: Txt.label(context).copyWith(
                                    fontSize: 14.5,
                                    color: i == index ? p.text : p.text2,
                                    fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                  child: Text(context.t(_tabs[i].key)),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ]),
              ]),
            ),
            const Spacer(),
            const _ProfileChip(),
          ]),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 1});
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 34 * size,
        height: 34 * size,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [p.accent, Color.lerp(p.accent, p.cta, 0.55)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(10 * size),
        ),
        alignment: Alignment.center,
        child: Text('伝', style: TextStyle(fontSize: 18 * size, fontWeight: FontWeight.w700, color: p.bg, height: 1)),
      ),
      SizedBox(width: 11 * size),
      Text('Densetsu', style: Txt.h2(context).copyWith(fontSize: 21 * size, letterSpacing: -0.6)),
    ]);
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: Services.i.session,
      builder: (context, _) {
        final user = Services.i.session.user;
        if (user == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: p.surface2,
              backgroundImage: user.avatar == null ? null : NetworkImage(Net.image(user.avatar!)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(context)),
                const SizedBox(height: 2),
                Text('AniList', style: Txt.caption(context)),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Glass(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: Pressable(
                  onTap: () => onSelect(i),
                  scale: 0.94,
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.easeOut,
                    height: 54,
                    decoration: BoxDecoration(color: i == index ? p.accentSoft : null, borderRadius: BorderRadius.circular(18)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(i == index ? _tabs[i].activeIcon : _tabs[i].icon, size: 21, color: i == index ? p.accent : p.text3),
                      const SizedBox(height: 3),
                      Text(
                        context.t(_tabs[i].key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Txt.caption(context).copyWith(fontSize: 10.5, color: i == index ? p.text : p.text3),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Standard page padding: generous on tablets, room for the floating bar in portrait.
EdgeInsets pagePadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  final wide = w >= 820;
  return EdgeInsets.fromLTRB(wide ? 44 : 20, wide ? 40 : 28, wide ? 44 : 20, wide ? 40 : 110);
}
