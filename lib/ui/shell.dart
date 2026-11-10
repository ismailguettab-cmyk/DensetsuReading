import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/services.dart';
import '../core/theme.dart';
import 'home_page.dart';
import 'reco_page.dart';
import 'anilist_search_page.dart';
import 'settings_page.dart';
import 'sources_page.dart';
import 'widgets.dart';

class _Tab {
  const _Tab(this.key, this.kanji);
  final String key;

  /// Kanji drawn above the label; null for Settings, which shows an icon at the bottom.
  final String? kanji;
}

const _tabs = [
  _Tab('nav.home', '家'),
  _Tab('nav.reco', '薦'),
  _Tab('nav.search', '探'),
  _Tab('nav.sources', '源'),
  _Tab('nav.settings', null),
];
const _settingsTab = 4;

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

  /// Bumped each time a tab comes back into view: its page is rebuilt, so its entrance plays again.
  final _visits = List.generate(_tabs.length, (_) => ValueNotifier(0));

  void _select(int i) {
    if (i == _index) {
      // Tapping the current tab again goes back to its root.
      _navigators[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    _visits[i].value++;
    setState(() {
      _index = i;
      _current.value = i;
      _visited.add(i);
    });
    if (i == 1) Services.i.reco.onVisit();
  }

  Widget _page(int i) => ValueListenableBuilder(
        valueListenable: _visits[i],
        builder: (_, visit, _) => KeyedSubtree(key: ValueKey(visit), child: _root(i)),
      );

  Widget _root(int i) => switch (i) {
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
                  Expanded(child: ColoredBox(color: p.bg, child: content)),
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

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      width: 96,
      decoration: BoxDecoration(color: p.sidebar, border: Border(right: BorderSide(color: p.text, width: 2))),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(children: [
            const BrandMark(),
            const SizedBox(height: 26),
            for (var i = 0; i < _tabs.length; i++)
              if (i != _settingsTab) _NavItem(tab: _tabs[i], active: i == index, onTap: () => onSelect(i)),
            const Spacer(),
            Tooltip(
              message: context.t(_tabs[_settingsTab].key),
              child: Pressable(
                onTap: () => onSelect(_settingsTab),
                scale: 0.94,
                child: SizedBox(
                  width: 64,
                  height: 58,
                  child: Stack(alignment: Alignment.center, children: [
                    if (index == _settingsTab) InkBlot(width: 58, height: 52, dot: p.cta),
                    Icon(Icons.tune_rounded, size: 22, color: index == _settingsTab ? p.bg : p.text2),
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

/// A tab: its kanji over the label; the active one sits on an ink blot with a red drop.
class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.active, required this.onTap, this.compact = false});

  final _Tab tab;
  final bool active, compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fg = active ? p.bg : p.text2;
    return Semantics(
      selected: active,
      button: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.94,
        child: SizedBox(
          width: compact ? 96 : 84,
          height: compact ? 62 : 72,
          child: Stack(alignment: Alignment.center, children: [
            AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: Motion.fast,
              child: InkBlot(width: compact ? 84 : 78, height: compact ? 58 : 66, dot: p.cta),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(tab.kanji ?? '', style: Txt.kanji(context, size: compact ? 21 : 24).copyWith(color: active ? p.bg : p.text)),
              const SizedBox(height: 5),
              // Short labels only: the rail is narrow ("Recommandations" would wrap mid-word).
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  context.t(tab.key == 'nav.reco' ? 'nav.recoShort' : tab.key),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: Txt.caption(context).copyWith(fontSize: 11, height: 1.1, color: fg, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// The red seal with 伝, slightly tilted like a stamp.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 1, this.withName = false});
  final double size;

  /// Adds "Densetsu" next to the seal (login screen).
  final bool withName;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final seal = Transform.rotate(
      angle: -0.07,
      child: Container(
        width: 50 * size,
        height: 50 * size,
        decoration: BoxDecoration(color: p.cta, borderRadius: BorderRadius.circular(6 * size)),
        alignment: Alignment.center,
        child: Text('伝', style: Txt.kanji(context, size: 26 * size).copyWith(color: p.onCta)),
      ),
    );
    if (!withName) return seal;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      seal,
      SizedBox(width: 14 * size),
      Text('Densetsu Reading', style: Txt.h2(context).copyWith(fontSize: 22 * size)),
    ]);
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
        constraints: const BoxConstraints(maxWidth: 640),
        child: Glass(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(children: [
            for (var i = 0; i < _tabs.length; i++)
              if (i != _settingsTab)
                Expanded(child: Center(child: _NavItem(tab: _tabs[i], active: i == index, compact: true, onTap: () => onSelect(i)))),
            Pressable(
              onTap: () => onSelect(_settingsTab),
              scale: 0.94,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Stack(alignment: Alignment.center, children: [
                  if (index == _settingsTab) InkBlot(width: 52, height: 48, dot: p.cta),
                  Icon(Icons.tune_rounded, size: 22, color: index == _settingsTab ? p.bg : p.text2),
                ]),
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
