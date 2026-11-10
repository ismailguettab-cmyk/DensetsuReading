import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../anilist/anilist.dart';
import '../core/activity.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/net.dart';
import '../core/services.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../sources/source.dart';
import '../translate/overlay.dart';
import '../translate/translator.dart';
import 'settings_page.dart';
import 'widgets.dart';

/// What one screen shows: one page, two pages side by side, or the end-of-chapter card.
class _Unit {
  const _Unit(this.pages);
  const _Unit.end() : pages = const [];
  final List<int> pages;
  bool get isEnd => pages.isEmpty;
}

/// The manga reader. Paged (right-to-left or left-to-right, single or double page)
/// or vertical scrolling. Pages can be translated into French on demand.
class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.source,
    required this.manga,
    required this.chapters,
    required this.index,
    this.startPage = 0,
    this.ani,
  });

  final MangaSource source;
  final SourceManga manga;
  final List<Chapter> chapters; // oldest first
  final int index;
  final int startPage;
  final AniMedia? ani;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final _settings = Services.i.settings;
  final _focus = FocusNode();
  late int _chapter = widget.index;
  List<PageImage> _pages = const [];
  final _aspects = <int, double>{};
  List<_Unit> _units = const [];
  bool _loading = true;
  Object? _error;

  PageController _pager = PageController();
  final _vertical = ScrollController();
  final _scrolls = <int, ScrollController>{};
  final _zoom = <int, TransformationController>{};
  int _unit = 0;
  int _page = 0;
  bool _zoomed = false;

  bool _chrome = true;
  Timer? _hideChrome;

  bool _translate = false;
  final _translations = <String, List<Bubble>>{};
  final _translating = <String>{};
  final _failed = <String>{};

  bool? _lastDouble;
  int _loadToken = 0;

  Chapter get chapter => widget.chapters[_chapter];
  bool get _vertical_ => _settings.direction == ReadDirection.vertical;
  bool get _rtl => _settings.direction == ReadDirection.rtl;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettings);
    // Full screen while reading: the system bars hide (a swipe from the edge brings them back).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _load(widget.startPage);
    _scheduleHide();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _settings.removeListener(_onSettings);
    _hideChrome?.cancel();
    _pager.dispose();
    _vertical.dispose();
    for (final c in _scrolls.values) {
      c.dispose();
    }
    for (final c in _zoom.values) {
      c.dispose();
    }
    _focus.dispose();
    super.dispose();
  }

  void _onSettings() {
    if (!mounted) return;
    _rebuildUnits(keepPage: true);
  }

  // ---------------------------------------------------------------- loading

  Future<void> _load(int startPage, {bool fromEnd = false}) async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _error = null;
      _pages = const [];
      _aspects.clear();
      _units = const [];
    });
    try {
      final pages = await widget.source.pages(chapter);
      if (token != _loadToken || !mounted) return;
      _pages = pages;
      _page = fromEnd ? pages.length - 1 : startPage.clamp(0, pages.isEmpty ? 0 : pages.length - 1);
      _loading = false;
      _rebuildUnits(keepPage: true, force: true);
      _resolveSizes(token);
      _logRead();
    } catch (e) {
      if (token == _loadToken && mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  final _retries = <int, int>{};

  /// Each failed attempt switches to the fallback address (if any) and busts the image cache.
  ImageProvider _provider(int i) {
    final p = _pages[i];
    final attempt = _retries[i] ?? 0;
    final url = attempt > 0 && p.fallback != null ? p.fallback! : p.url;
    final address = Net.image(url, p.headers);
    final key = attempt == 0 ? address : '$address${address.contains('?') ? '&' : '?'}retry=$attempt';
    return NetworkImage(key, headers: Net.nativeHeaders(url, p.headers));
  }

  /// Learns every page's proportions (and preloads it). Wide pages are spreads,
  /// so they are shown alone in double-page mode.
  Future<void> _resolveSizes(int token) async {
    var next = _page;
    final order = [
      for (var i = _page; i < _pages.length; i++) i,
      for (var i = _page - 1; i >= 0; i--) i,
    ];
    Future<void> worker() async {
      while (next >= 0 && order.isNotEmpty) {
        if (token != _loadToken || !mounted) return;
        final i = order.removeAt(0);
        final completer = Completer<void>();
        final stream = _provider(i).resolve(ImageConfiguration.empty);
        late ImageStreamListener listener;
        listener = ImageStreamListener((info, _) {
          final aspect = info.image.width / info.image.height;
          stream.removeListener(listener);
          if (token == _loadToken && mounted) {
            final before = _aspects[i];
            _aspects[i] = aspect;
            if (before == null || (before > 1.1) != (aspect > 1.1)) _rebuildUnits(keepPage: true);
          }
          if (!completer.isCompleted) completer.complete();
        }, onError: (_, __) {
          stream.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        });
        stream.addListener(listener);
        await completer.future.timeout(const Duration(seconds: 25), onTimeout: () {});
      }
    }

    next = 0;
    await Future.wait([worker(), worker(), worker()]);
  }

  // ------------------------------------------------------------------ units

  bool _isDouble(BuildContext context) {
    if (_vertical_) return false;
    return switch (_settings.layout) {
      PageLayout.single => false,
      PageLayout.double => true,
      PageLayout.auto => MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height,
    };
  }

  bool _wide(int i) => (_aspects[i] ?? 0.7) > 1.1;

  void _rebuildUnits({required bool keepPage, bool force = false}) {
    if (!mounted || _pages.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final double = _isDouble(context);
    final units = <_Unit>[];
    var i = 0;
    if (double && _settings.shiftDouble && _pages.isNotEmpty) {
      units.add(const _Unit([0]));
      i = 1;
    }
    while (i < _pages.length) {
      if (!double || _wide(i) || i + 1 >= _pages.length || _wide(i + 1)) {
        units.add(_Unit([i]));
        i++;
      } else {
        units.add(_Unit([i, i + 1]));
        i += 2;
      }
    }
    units.add(const _Unit.end());
    final target = units.indexWhere((u) => u.pages.contains(_page));
    final changed = force || units.length != _units.length || _lastDouble != double;
    _lastDouble = double;
    setState(() {
      _units = units;
      _unit = target < 0 ? 0 : target;
    });
    if (!changed || _vertical_) {
      if (_vertical_ && force) WidgetsBinding.instance.addPostFrameCallback((_) => _jumpVertical(_page));
      return;
    }
    final old = _pager;
    _pager = PageController(initialPage: _unit);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _jumpVertical(int page) {
    if (!_vertical.hasClients || page == 0) return;
    final w = MediaQuery.sizeOf(context).width.clamp(0.0, 900.0);
    var offset = 0.0;
    for (var i = 0; i < page; i++) {
      offset += w / (_aspects[i] ?? 0.7);
    }
    _vertical.jumpTo(offset.clamp(0, _vertical.position.maxScrollExtent));
  }

  // ------------------------------------------------------------- navigation

  void _onUnitChanged(int i) {
    final previous = _unit;
    setState(() {
      _unit = i;
      if (!_units[i].isEnd) _page = _units[i].pages.first;
      _zoomed = false;
    });
    _zoom[previous]?.value = Matrix4.identity();
    if (_units[i].isEnd || (i == _units.length - 2)) _markRead();
    _logRead();
    if (_translate) _translateAround();
  }

  void _go(int delta, {bool animate = true}) {
    if (_units.isEmpty) return;
    // In fill mode, a forward tap first scrolls what's below the fold.
    final scroll = _scrolls[_unit];
    if (delta > 0 && scroll != null && scroll.hasClients && scroll.position.extentAfter > 4) {
      scroll.animateTo(
        (scroll.offset + scroll.position.viewportDimension * 0.85).clamp(0, scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 320),
        curve: Motion.easeInOut,
      );
      return;
    }
    final target = _unit + delta;
    if (target >= _units.length) {
      _nextChapter();
      return;
    }
    if (target < 0) {
      _previousChapter();
      return;
    }
    if (animate && _settings.pageAnimation && !Motion.reduced(context)) {
      _pager.animateToPage(target, duration: const Duration(milliseconds: 300), curve: Motion.drawer);
    } else {
      _pager.jumpToPage(target);
    }
  }

  void _nextChapter() {
    if (_chapter + 1 >= widget.chapters.length) return;
    _markRead();
    setState(() => _chapter++);
    _load(0);
  }

  void _previousChapter() {
    if (_chapter == 0) return;
    setState(() => _chapter--);
    _load(0, fromEnd: true);
  }

  void _markRead() {
    final ani = widget.ani;
    final n = chapter.number;
    if (ani != null && n != null) Services.i.session.recordProgress(ani, n.floor());
  }

  void _logRead() {
    Services.i.activity.logRead(ReadEvent(
      sourceId: widget.source.id,
      mangaUrl: widget.manga.url,
      title: widget.ani?.title ?? widget.manga.title,
      cover: widget.manga.cover,
      chapterUrl: chapter.url,
      chapterName: chapter.name,
      page: _page,
      anilistId: widget.ani?.id,
      total: _pages.length,
      at: DateTime.now(),
    ));
  }

  void _onTap(TapUpDetails d, Size size) {
    final x = d.localPosition.dx / size.width;
    if (!_settings.tapZones || _vertical_ || (x > 0.3 && x < 0.7)) {
      _toggleChrome();
      return;
    }
    var left = x <= 0.3;
    if (_settings.invertTaps) left = !left;
    // Right-to-left manga: the left edge moves forward.
    final forward = _rtl ? left : !left;
    _go(forward ? 1 : -1);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (_vertical_) return KeyEventResult.ignored;
    // Keyboard turns are instant: no animation for a repeated action.
    if (k == LogicalKeyboardKey.arrowLeft) {
      _go(_rtl ? 1 : -1, animate: false);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _go(_rtl ? -1 : 1, animate: false);
    } else if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.pageDown) {
      _go(1, animate: false);
    } else if (k == LogicalKeyboardKey.pageUp) {
      _go(-1, animate: false);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _toggleChrome() {
    _hideChrome?.cancel();
    setState(() => _chrome = !_chrome);
  }

  void _scheduleHide() {
    _hideChrome?.cancel();
    _hideChrome = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _chrome = false);
    });
  }

  // ------------------------------------------------------------ translation

  void _toggleTranslate() {
    if (!Services.i.translator.ready) {
      toast(context, context.t('reader.noKey'));
      return;
    }
    setState(() {
      _translate = !_translate;
      _failed.clear();
    });
    if (_translate) _translateAround();
  }

  /// Translates what's on screen, then the next screen ahead.
  void _translateAround() {
    if (_units.isEmpty) return;
    final targets = <int>[];
    if (_vertical_) {
      for (var i = _page; i < _pages.length && i < _page + 3; i++) {
        targets.add(i);
      }
    } else {
      for (var u = _unit; u < _units.length && u <= _unit + 1; u++) {
        targets.addAll(_units[u].pages);
      }
    }
    for (final i in targets) {
      final page = _pages[i];
      if (_translations.containsKey(page.url) || _translating.contains(page.url) || _failed.contains(page.url)) continue;
      setState(() => _translating.add(page.url));
      Services.i.translator.page(page).then((bubbles) {
        if (!mounted) return;
        setState(() {
          _translations[page.url] = bubbles;
          _translating.remove(page.url);
        });
      }).catchError((Object e) {
        if (!mounted) return;
        setState(() {
          _translating.remove(page.url);
          _failed.add(page.url);
        });
      });
    }
  }

  // ------------------------------------------------------------------ build

  Color get _background => switch (_settings.background) {
        ReaderBackground.black => const Color(0xFF000000),
        ReaderBackground.gray => const Color(0xFF2B2B2E),
        ReaderBackground.white => const Color(0xFFF4F4F4),
      };

  @override
  Widget build(BuildContext context) {
    final double = _isDouble(context);
    if (_lastDouble != null && _lastDouble != double && _pages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildUnits(keepPage: true));
    }
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: _background,
        body: Stack(children: [
          Positioned.fill(child: _content(context)),
          _topBar(context),
          _bottomBar(context),
          if (!_chrome && _settings.showPageNumber && _pages.isNotEmpty) _pageBadge(context),
        ]),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final p = context.pal;
    if (_loading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(strokeWidth: 2, color: p.accent),
          const SizedBox(height: 14),
          Text(context.t('reader.loading'), style: Txt.caption(context)),
        ]),
      );
    }
    if (_error != null || _pages.isEmpty) {
      return EmptyState(
        icon: Icons.broken_image_rounded,
        title: context.t('reader.error'),
        action: AppButton(label: context.t('detail.retry'), tone: ButtonTone.quiet, onTap: () => _load(_page)),
      );
    }
    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      if (_vertical_) return _verticalView(context, size);
      return GestureDetector(
        onTapUp: (d) => _onTap(d, size),
        child: PageView.builder(
          controller: _pager,
          reverse: _rtl,
          physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
          onPageChanged: _onUnitChanged,
          itemCount: _units.length,
          itemBuilder: (context, i) => _units[i].isEnd ? _endCard(context) : _unitView(i, size),
        ),
      );
    });
  }

  /// One or two pages, joined edge to edge at a shared height, then fitted.
  Widget _unitView(int index, Size viewport) {
    final unit = _units[index];
    final shown = (_rtl != _settings.invertDouble) ? unit.pages.reversed.toList() : unit.pages;
    final aspects = [for (final i in shown) _aspects[i] ?? 0.7];
    final total = aspects.fold<double>(0, (a, b) => a + b);
    final fit = unit.pages.length > 1 ? _settings.doubleFit : _settings.singleFit;
    final spread = AspectRatio(
      aspectRatio: total,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var k = 0; k < shown.length; k++)
          Expanded(flex: (aspects[k] * 1000).round(), child: _pageImage(shown[k])),
      ]),
    );
    final screenAspect = viewport.width / viewport.height;
    final tall = total < screenAspect;
    // Double-page reading fills the screen without ever scrolling: the spread (or a lone
    // wide page) is shown whole, as big as the screen allows, proportions untouched.
    final spreadMode = _lastDouble == true && fit == PageFit.fill;

    if (fit == PageFit.fit || spreadMode || (fit == PageFit.width && !tall)) {
      return _zoomable(index, Center(child: spread));
    }
    if (tall) {
      // Fills the width; the rest of the page scrolls vertically. No borders, no stretching.
      final controller = _scrolls.putIfAbsent(index, ScrollController.new);
      return SingleChildScrollView(
        controller: controller,
        child: SizedBox(width: viewport.width, height: viewport.width / total, child: spread),
      );
    }
    // Wider than the screen: fill the height and crop the sides evenly.
    return _zoomable(
      index,
      SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(width: 1000 * total, height: 1000, child: spread),
        ),
      ),
    );
  }

  Widget _zoomable(int index, Widget child) {
    final controller = _zoom.putIfAbsent(index, TransformationController.new);
    return InteractiveViewer(
      transformationController: controller,
      minScale: 1,
      maxScale: 4,
      panEnabled: _zoomed,
      onInteractionEnd: (_) {
        final zoomed = controller.value.getMaxScaleOnAxis() > 1.02;
        if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
      },
      child: child,
    );
  }

  Widget _pageImage(int i) {
    final page = _pages[i];
    final bubbles = _translate ? _translations[page.url] : null;
    return Stack(fit: StackFit.expand, children: [
      Image(
        image: _provider(i),
        fit: BoxFit.fill, // the box already has the page's exact proportions
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, sync) => sync || frame != null
            ? child
            : Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: context.pal.text3))),
        errorBuilder: (context, _, _) {
          final attempt = _retries[i] ?? 0;
          if (attempt < 2) {
            // Retry by itself (fallback address first), a moment later.
            Future.delayed(Duration(milliseconds: 600 + 900 * attempt), () {
              if (mounted && (_retries[i] ?? 0) == attempt) setState(() => _retries[i] = attempt + 1);
            });
            return Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: context.pal.text3)));
          }
          return Center(
            child: Pressable(
              onTap: () => setState(() => _retries[i] = 1),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.refresh_rounded, color: context.pal.text2, size: 28),
                const SizedBox(height: 6),
                Text(context.isEn ? 'Reload page' : 'Recharger la page', style: Txt.caption(context).copyWith(color: context.pal.text2)),
              ]),
            ),
          );
        },
      ),
      if (bubbles != null)
        AnimatedOpacity(opacity: 1, duration: Motion.base, child: TranslationOverlay(bubbles: bubbles)),
      if (_translate && _translating.contains(page.url))
        Positioned(
          right: 10,
          top: 10,
          child: Glass(
            radius: 99,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: context.pal.accent)),
              const SizedBox(width: 7),
              Text(context.t('reader.translating'), style: Txt.caption(context).copyWith(color: context.pal.text)),
            ]),
          ),
        ),
      if (_translate && _failed.contains(page.url))
        Positioned(
          right: 10,
          top: 10,
          child: Pressable(
            onTap: () {
              setState(() => _failed.remove(page.url));
              _translateAround();
            },
            child: Glass(
              radius: 99,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.refresh_rounded, size: 14, color: context.pal.cta),
                const SizedBox(width: 6),
                Text(context.isEn ? 'Not translated · retry' : 'Non traduite · réessayer', style: Txt.caption(context).copyWith(color: context.pal.text)),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _verticalView(BuildContext context, Size size) {
    final width = size.width.clamp(0.0, 900.0);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        var offset = n.metrics.pixels + size.height * 0.4;
        var page = 0;
        for (var i = 0; i < _pages.length; i++) {
          offset -= width / (_aspects[i] ?? 0.7);
          if (offset < 0) break;
          page = i + 1;
        }
        page = page.clamp(0, _pages.length - 1);
        if (page != _page) {
          setState(() => _page = page);
          if (page == _pages.length - 1) _markRead();
          if (_translate) _translateAround();
        }
        return false;
      },
      child: GestureDetector(
        onTap: _toggleChrome,
        child: ListView.builder(
          controller: _vertical,
          itemCount: _pages.length + 1,
          itemBuilder: (context, i) {
            if (i == _pages.length) return SizedBox(height: size.height * 0.8, child: _endCard(context));
            return Center(
              child: SizedBox(width: width, child: AspectRatio(aspectRatio: _aspects[i] ?? 0.7, child: _pageImage(i))),
            );
          },
        ),
      ),
    );
  }

  Widget _endCard(BuildContext context) {
    final p = context.pal;
    final hasNext = _chapter + 1 < widget.chapters.length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(26)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(context.t('reader.end'), style: Txt.caption(context)),
            const SizedBox(height: 6),
            Text(chapter.name, textAlign: TextAlign.center, style: Txt.h2(context)),
            const SizedBox(height: 22),
            if (hasNext) ...[
              Text(widget.chapters[_chapter + 1].name, style: Txt.body(context)),
              const SizedBox(height: 14),
              AppButton(label: context.t('reader.next'), icon: Icons.arrow_forward_rounded, expand: true, onTap: _nextChapter),
              const SizedBox(height: 12),
              Text(context.t('reader.swipe'), textAlign: TextAlign.center, style: Txt.caption(context)),
            ] else ...[
              Text(context.t('reader.last'), textAlign: TextAlign.center, style: Txt.body(context)),
              const SizedBox(height: 16),
              AppButton(label: context.t('common.back'), tone: ButtonTone.quiet, onTap: () => Navigator.of(context).maybePop()),
            ],
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- chrome

  Widget _slideIn({required bool fromTop, required Widget child}) {
    final reduced = Motion.reduced(context);
    return IgnorePointer(
      ignoring: !_chrome,
      child: AnimatedOpacity(
        opacity: _chrome ? 1 : 0,
        duration: _chrome ? Motion.base : Motion.fast,
        curve: Motion.easeOut,
        child: AnimatedSlide(
          offset: _chrome || reduced ? Offset.zero : Offset(0, fromTop ? -0.35 : 0.35),
          duration: _chrome ? Motion.base : Motion.fast,
          curve: Motion.easeOut,
          child: child,
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final p = context.pal;
    final translating = _translating.isNotEmpty;
    return Positioned(
      left: 14,
      right: 14,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _slideIn(
            fromTop: true,
            child: Glass(
              radius: 20,
              padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
              child: Row(children: [
                IconCircle(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop(), size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.ani?.title ?? widget.manga.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.title(context)),
                    Text(
                      [chapter.name, if (chapter.title != null) chapter.title!].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Txt.caption(context),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                Pressable(
                  onTap: _toggleTranslate,
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: _translate ? p.accent : p.surface2, borderRadius: BorderRadius.circular(99)),
                    child: Row(children: [
                      if (_translate && translating)
                        SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: p.bg))
                      else
                        Icon(Icons.translate_rounded, size: 18, color: _translate ? p.bg : p.text),
                      const SizedBox(width: 8),
                      Text(
                        _translate ? (translating ? context.t('reader.translating') : context.t('reader.translated')) : 'FR',
                        style: Txt.label(context).copyWith(color: _translate ? p.bg : p.text),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                IconCircle(icon: Icons.tune_rounded, size: 40, tooltip: context.t('reader.settings'), onTap: _openSettings),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final p = context.pal;
    final total = _pages.length;
    final hasPrev = _chapter > 0;
    final hasNext = _chapter + 1 < widget.chapters.length;
    return Positioned(
      left: 14,
      right: 14,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _slideIn(
                fromTop: false,
                child: Glass(
                  radius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(children: [
                    IconCircle(
                      icon: Icons.skip_previous_rounded,
                      size: 40,
                      tooltip: context.t('reader.prev'),
                      onTap: hasPrev ? _previousChapter : null,
                    ),
                    const SizedBox(width: 14),
                    Text('${(_page + 1).clamp(1, total == 0 ? 1 : total)}', style: Txt.number(context, size: 14)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: total < 2 || _vertical_
                          ? LinearProgressIndicator(
                              value: total == 0 ? 0 : (_page + 1) / total,
                              color: p.accent,
                              backgroundColor: p.surface2,
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(2),
                            )
                          : Directionality(
                              textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
                              child: Slider(
                                value: _page.clamp(0, total - 1).toDouble(),
                                max: (total - 1).toDouble(),
                                onChanged: (v) {
                                  final target = _units.indexWhere((u) => u.pages.contains(v.round()));
                                  if (target >= 0) _pager.jumpToPage(target);
                                },
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Text('$total', style: Txt.number(context, size: 14).copyWith(color: p.text3)),
                    const SizedBox(width: 14),
                    IconCircle(
                      icon: Icons.skip_next_rounded,
                      size: 40,
                      tooltip: context.t('reader.next'),
                      onTap: hasNext ? _nextChapter : null,
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageBadge(BuildContext context) {
    final u = _units.isEmpty || _unit >= _units.length ? null : _units[_unit];
    final label = u == null || u.isEnd
        ? '${_pages.length} / ${_pages.length}'
        : '${u.pages.map((i) => i + 1).join('–')} / ${_pages.length}';
    return Positioned(
      bottom: 14,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(99)),
              child: Text(label, style: Txt.number(context, size: 12).copyWith(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  /// Settings panel: slides in from the right edge in landscape, from the bottom in portrait.
  Future<void> _openSettings() async {
    _hideChrome?.cancel();
    final wide = MediaQuery.sizeOf(context).width >= 820;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('common.close'),
      barrierColor: const Color(0x66000000),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, _, __) => _ReaderSettingsPanel(wide: wide),
      transitionBuilder: (context, a, _, child) {
        final t = CurvedAnimation(parent: a, curve: Motion.drawer, reverseCurve: Curves.easeIn);
        return SlideTransition(
          position: Tween(begin: wide ? const Offset(0.25, 0) : const Offset(0, 0.25), end: Offset.zero).animate(t),
          child: FadeTransition(opacity: t, child: child),
        );
      },
    );
  }
}

class _ReaderSettingsPanel extends StatelessWidget {
  const _ReaderSettingsPanel({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final panel = Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: ListView(padding: const EdgeInsets.fromLTRB(22, 22, 22, 22), shrinkWrap: true, children: [
        Row(children: [
          Expanded(child: Text(context.t('reader.settings'), style: Txt.h2(context))),
          IconCircle(icon: Icons.close_rounded, size: 38, onTap: () => Navigator.of(context).pop()),
        ]),
        const SizedBox(height: 8),
        const ReaderSettingsForm(),
      ]),
    );
    return SafeArea(
      child: Align(
        alignment: wide ? Alignment.centerRight : Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: wide ? 460 : 640,
              maxHeight: MediaQuery.sizeOf(context).height * (wide ? 1 : 0.8),
            ),
            child: panel,
          ),
        ),
      ),
    );
  }
}
