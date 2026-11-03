import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../anilist/anilist.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/platform.dart';
import '../core/services.dart';
import '../core/theme.dart';
import 'shell.dart';
import 'widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  late final Future<List<AniMedia>> _covers = _trending();

  static Future<List<AniMedia>> _trending() async {
    try {
      final data = await AniList().query(
        'query { Page(perPage: 24) { media(type: MANGA, sort: TRENDING_DESC, isAdult: false) { ...M } } } $mediaFragment',
      );
      return ((data['Page']?['media'] as List?) ?? const []).map((m) => AniMedia.fromJson(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _anilist() async {
    final id = Services.i.settings.anilistClientId.trim();
    if (id.isEmpty) {
      await _setup();
      return;
    }
    if (kIsWeb) {
      await openAuthorize(AniList.authorizeUrl(id));
    } else {
      await openAuthorize(AniList.authorizeUrl(id));
      if (mounted) await _pasteToken();
    }
  }

  Future<void> _username() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await Services.i.session.signInWithUsername(name);
      if (!ok && mounted) setState(() => _error = context.t('login.notFound'));
    } catch (_) {
      if (mounted) setState(() => _error = context.t('login.error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setup() async {
    final controller = TextEditingController(text: Services.i.settings.anilistClientId);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _Sheet(
        title: context.t('login.setup'),
        children: [
          Text(context.t('login.setupText'), style: Txt.body(context)),
          const SizedBox(height: 12),
          _CopyField(AniList.redirectUri),
          const SizedBox(height: 18),
          _Field(controller: controller, hint: context.t('login.clientId'), keyboard: TextInputType.number),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(label: context.t('login.save'), tone: ButtonTone.accent, onTap: () => Navigator.pop(context, true)),
          ),
        ],
      ),
    );
    if (saved == true && controller.text.trim().isNotEmpty) {
      Services.i.settings.update((s) => s.anilistClientId = controller.text.trim());
      await _anilist();
    }
  }

  Future<void> _pasteToken() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _Sheet(
        title: context.t('login.token'),
        children: [
          _Field(controller: controller, hint: 'eyJ0eXAiOiJKV1Qi…'),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(label: context.t('login.go'), tone: ButtonTone.accent, onTap: () => Navigator.pop(context, true)),
          ),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) await Services.i.session.signInWithToken(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 820;
    final form = _form(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: wide
          ? Row(children: [
              Expanded(flex: 11, child: _Mosaic(covers: _covers)),
              Expanded(
                flex: 9,
                child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(56), child: form)),
              ),
            ])
          : Stack(children: [
              SizedBox(height: size.height * 0.42, child: _Mosaic(covers: _covers)),
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, size.height * 0.34, 24, 40),
                  child: form,
                ),
              ),
            ]),
    );
  }

  Widget _form(BuildContext context) {
    final p = context.pal;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Reveal(child: BrandMark(size: 1.15)),
        const SizedBox(height: 40),
        Reveal(index: 1, child: Text(context.t('login.title'), style: Txt.display(context))),
        const SizedBox(height: 16),
        Reveal(index: 2, child: Text(context.t('login.subtitle'), style: Txt.body(context).copyWith(fontSize: 15.5))),
        const SizedBox(height: 36),
        Reveal(
          index: 3,
          child: AppButton(label: context.t('login.anilist'), icon: Icons.login_rounded, expand: true, onTap: _anilist),
        ),
        const SizedBox(height: 28),
        Reveal(
          index: 4,
          child: Row(children: [
            Expanded(child: Divider(color: p.line)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(context.isEn ? 'or' : 'ou', style: Txt.caption(context))),
            Expanded(child: Divider(color: p.line)),
          ]),
        ),
        const SizedBox(height: 22),
        Reveal(
          index: 5,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.t('login.username'), style: Txt.label(context)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _Field(controller: _name, hint: context.t('login.usernameHint'), onSubmit: (_) => _username())),
              const SizedBox(width: 10),
              AppButton(label: context.t('login.go'), tone: ButtonTone.quiet, loading: _busy, onTap: _username),
            ]),
            const SizedBox(height: 10),
            Text(
              _error ?? context.t('login.usernameNote'),
              style: Txt.caption(context).copyWith(color: _error != null ? p.danger : null),
            ),
          ]),
        ),
        const SizedBox(height: 26),
        Reveal(
          index: 6,
          child: Pressable(
            onTap: _setup,
            child: Text(context.t('login.setup'), style: Txt.caption(context).copyWith(decoration: TextDecoration.underline)),
          ),
        ),
      ]),
    );
  }
}

/// Tilted wall of trending covers, fading into the background.
class _Mosaic extends StatelessWidget {
  const _Mosaic({required this.covers});
  final Future<List<AniMedia>> covers;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ClipRect(
      child: Stack(fit: StackFit.expand, children: [
        FutureBuilder<List<AniMedia>>(
          future: covers,
          builder: (context, snap) {
            final items = snap.data ?? const [];
            return OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.rotate(
                angle: -0.12,
                child: SizedBox(
                  width: 1100,
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < 24; i++)
                        SizedBox(
                          width: 128,
                          height: 192,
                          child: i < items.length
                              ? Reveal(index: i % 12, offset: 22, child: CoverImage(url: items[i].cover, radius: 14))
                              : Skeleton(radius: 14),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.bg.withValues(alpha: 0.15), p.bg.withValues(alpha: 0.55), p.bg],
              stops: const [0, 0.6, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [p.bg.withValues(alpha: 0), p.bg.withValues(alpha: 0.9)], begin: Alignment.centerLeft, end: Alignment.centerRight, stops: const [0.55, 1]),
          ),
        ),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, this.onSubmit, this.keyboard});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmit;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return TextField(
      controller: controller,
      onSubmitted: onSubmit,
      keyboardType: keyboard,
      style: Txt.label(context).copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Txt.label(context).copyWith(color: p.text3, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.accent, width: 1.4)),
      ),
    );
  }
}

class _CopyField extends StatelessWidget {
  const _CopyField(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Pressable(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        toast(context, context.isEn ? 'Copied' : 'Copié');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: SelectableText(value, style: Txt.label(context).copyWith(fontFamily: 'monospace', fontSize: 13))),
          Icon(Icons.copy_rounded, size: 17, color: p.text2),
        ]),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Txt.h2(context)),
            const SizedBox(height: 14),
            ...children,
          ]),
        ),
      ),
    );
  }
}
