import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n.dart';
import '../core/services.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/updater.dart';
import 'shell.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Services.i;
    final pad = pagePadding(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([s.settings, s.session]),
        builder: (context, _) {
          final set = s.settings;
          return ListView(padding: pad, children: [
            Text(context.t('settings.title'), style: Txt.display(context)),
            const SizedBox(height: 30),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SettingsGroup(title: context.t('settings.appearance'), children: [
                    SettingRow(
                      label: context.t('settings.theme'),
                      child: Segmented<ThemeMode>(
                        value: set.themeMode,
                        options: [
                          (ThemeMode.light, context.t('settings.light')),
                          (ThemeMode.dark, context.t('settings.dark')),
                          (ThemeMode.system, context.t('settings.system')),
                        ],
                        onChanged: (v) => set.update((x) => x.themeMode = v),
                      ),
                    ),
                    SettingRow(
                      label: context.t('settings.language'),
                      child: Segmented<String>(
                        value: set.language,
                        options: const [('fr', 'Français'), ('en', 'English')],
                        onChanged: (v) => set.update((x) => x.language = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 22),
                  SettingsGroup(title: context.t('settings.reader'), children: const [ReaderSettingsForm()]),
                  const SizedBox(height: 22),
                  SettingsGroup(title: context.t('settings.ai'), children: [_GeminiKey(settings: set)]),
                  const SizedBox(height: 22),
                  SettingsGroup(title: context.t('settings.account'), children: [
                    if (s.session.user != null)
                      SettingRow(
                        label: '${context.t('settings.signedAs')} ${s.session.user!.name}'
                            '${s.session.canWrite ? '' : ' (${context.t('settings.readOnly')})'}',
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AppButton(label: context.t('settings.signOut'), tone: ButtonTone.quiet, onTap: s.session.signOut),
                        ),
                      ),
                  ]),
                  if (AppUpdater.supported) ...[
                    const SizedBox(height: 22),
                    SettingsGroup(title: 'Application', children: [_UpdateSection(settings: set)]),
                  ],
                  const SizedBox(height: 22),
                  SettingsGroup(title: context.t('settings.data'), children: [
                    SettingRow(
                      label: context.t('settings.clearReco'),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AppButton(
                          label: 'OK',
                          tone: ButtonTone.quiet,
                          onTap: () {
                            s.reco.invalidate();
                            toast(context, context.t('settings.done'));
                          },
                        ),
                      ),
                    ),
                    SettingRow(
                      label: context.t('settings.clearSearch'),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AppButton(
                          label: 'OK',
                          tone: ButtonTone.quiet,
                          onTap: () {
                            s.activity.clearSearches();
                            toast(context, context.t('settings.done'));
                          },
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(title, style: Txt.label(context).copyWith(color: p.text3, fontSize: 13)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    ]);
  }
}

class SettingRow extends StatelessWidget {
  const SettingRow({super.key, required this.label, required this.child, this.note});
  final String label;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(builder: (context, box) {
        final stacked = box.maxWidth < 520;
        final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Txt.label(context)),
          if (note != null) ...[const SizedBox(height: 4), Text(note!, style: Txt.caption(context))],
        ]);
        if (stacked) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [text, const SizedBox(height: 10), child]);
        }
        return Row(children: [
          Expanded(flex: 5, child: text),
          const SizedBox(width: 20),
          Expanded(flex: 6, child: child),
        ]);
      }),
    );
  }
}

class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.label, required this.value, required this.onChanged, this.note});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Txt.label(context)),
            if (note != null) ...[const SizedBox(height: 4), Text(note!, style: Txt.caption(context))],
          ]),
        ),
        const SizedBox(width: 16),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}

/// Reader options, shared by the Settings tab and the in-reader panel.
class ReaderSettingsForm extends StatelessWidget {
  const ReaderSettingsForm({super.key});

  @override
  Widget build(BuildContext context) {
    final set = Services.i.settings;
    final fits = [
      (PageFit.fit, context.t('settings.fit')),
      (PageFit.fill, context.t('settings.fill')),
      (PageFit.width, context.t('settings.width')),
    ];
    return ListenableBuilder(
      listenable: set,
      builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SettingRow(
          label: context.t('settings.direction'),
          child: Segmented<ReadDirection>(
            value: set.direction,
            options: [
              (ReadDirection.rtl, context.t('settings.rtl')),
              (ReadDirection.ltr, context.t('settings.ltr')),
              (ReadDirection.vertical, context.t('settings.vertical')),
            ],
            onChanged: (v) => set.update((x) => x.direction = v),
          ),
        ),
        SettingRow(
          label: context.t('settings.layout'),
          note: context.t('settings.autoNote'),
          child: Segmented<PageLayout>(
            value: set.layout,
            options: [
              (PageLayout.single, context.t('settings.single')),
              (PageLayout.double, context.t('settings.double')),
              (PageLayout.auto, context.t('settings.auto')),
            ],
            onChanged: (v) => set.update((x) => x.layout = v),
          ),
        ),
        SettingRow(
          label: context.t('settings.doubleFit'),
          note: context.t('settings.fillNote'),
          child: Segmented<PageFit>(value: set.doubleFit, options: fits, onChanged: (v) => set.update((x) => x.doubleFit = v)),
        ),
        SettingRow(
          label: context.t('settings.singleFit'),
          child: Segmented<PageFit>(value: set.singleFit, options: fits, onChanged: (v) => set.update((x) => x.singleFit = v)),
        ),
        SettingRow(
          label: context.t('settings.background'),
          child: Segmented<ReaderBackground>(
            value: set.background,
            options: [
              (ReaderBackground.black, context.t('settings.black')),
              (ReaderBackground.gray, context.t('settings.gray')),
              (ReaderBackground.white, context.t('settings.white')),
            ],
            onChanged: (v) => set.update((x) => x.background = v),
          ),
        ),
        SwitchRow(label: context.t('settings.invertDouble'), value: set.invertDouble, onChanged: (v) => set.update((x) => x.invertDouble = v)),
        SwitchRow(
          label: context.t('settings.shiftDouble'),
          note: context.t('settings.shiftNote'),
          value: set.shiftDouble,
          onChanged: (v) => set.update((x) => x.shiftDouble = v),
        ),
        SwitchRow(label: context.t('settings.tapZones'), value: set.tapZones, onChanged: (v) => set.update((x) => x.tapZones = v)),
        SwitchRow(label: context.t('settings.invertTaps'), value: set.invertTaps, onChanged: (v) => set.update((x) => x.invertTaps = v)),
        SwitchRow(label: context.t('settings.pageNumber'), value: set.showPageNumber, onChanged: (v) => set.update((x) => x.showPageNumber = v)),
        SwitchRow(label: context.t('settings.pageAnimation'), value: set.pageAnimation, onChanged: (v) => set.update((x) => x.pageAnimation = v)),
      ]),
    );
  }
}

class _GeminiKey extends StatefulWidget {
  const _GeminiKey({required this.settings});
  final Settings settings;

  @override
  State<_GeminiKey> createState() => _GeminiKeyState();
}

class _GeminiKeyState extends State<_GeminiKey> {
  late final _c = TextEditingController(text: widget.settings.geminiKey);
  bool _hidden = true;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.t('settings.geminiKey'), style: Txt.label(context)),
        const SizedBox(height: 4),
        Text(context.t('settings.geminiKeyNote'), style: Txt.caption(context)),
        const SizedBox(height: 12),
        TextField(
          controller: _c,
          obscureText: _hidden,
          onChanged: (v) => widget.settings.update((x) => x.geminiKey = v.trim()),
          style: Txt.label(context).copyWith(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'AIza…',
            filled: true,
            fillColor: p.surface2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: context.t('settings.paste'),
                icon: Icon(Icons.content_paste_rounded, size: 19, color: p.text2),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  final text = data?.text?.trim();
                  if (text == null || text.isEmpty) return;
                  _c.text = text;
                  widget.settings.update((x) => x.geminiKey = text);
                },
              ),
              IconButton(
                icon: Icon(_hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 19, color: p.text2),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

enum _UpdateStep { idle, checking, upToDate, available, downloading, ready, error }

/// "Update the app": compares this build with the APK published on GitHub, downloads it
/// and opens Android's installer. While the repository is private, a read-only GitHub
/// token is needed to see the release.
class _UpdateSection extends StatefulWidget {
  const _UpdateSection({required this.settings});
  final Settings settings;

  @override
  State<_UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<_UpdateSection> {
  late final _token = TextEditingController(text: widget.settings.githubToken);
  _UpdateStep _step = _UpdateStep.idle;
  UpdateInfo? _info;
  double _progress = 0;
  String? _message;
  bool _needsToken = false;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _step = _UpdateStep.checking;
      _message = null;
    });
    try {
      final info = await AppUpdater.check(widget.settings.githubToken);
      if (!mounted) return;
      setState(() {
        _info = info;
        _needsToken = false;
        _step = info.newer ? _UpdateStep.available : _UpdateStep.upToDate;
      });
    } on UpdateError catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _UpdateStep.error;
        _needsToken = e.kind == UpdateErrorKind.notFound;
        _message = e.kind == UpdateErrorKind.notFound
            ? (context.isEn
                ? 'No update found. The repository is private: paste a read-only GitHub token below.'
                : 'Mise à jour introuvable. Le dépôt est privé : colle un jeton GitHub (lecture seule) ci-dessous.')
            : (context.isEn ? 'No connection to GitHub.' : 'Impossible de joindre GitHub.');
      });
    }
  }

  Future<void> _download() async {
    final info = _info;
    if (info == null) return;
    setState(() {
      _step = _UpdateStep.downloading;
      _progress = 0;
      _message = null;
    });
    try {
      await for (final p in AppUpdater.download(info, widget.settings.githubToken)) {
        if (mounted) setState(() => _progress = p);
      }
      if (!mounted) return;
      setState(() => _step = _UpdateStep.ready);
      await _install();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _step = _UpdateStep.error;
        _message = context.isEn ? 'The download failed. Try again.' : 'Le téléchargement a échoué. Réessaie.';
      });
    }
  }

  Future<void> _install() async {
    final error = await AppUpdater.install();
    if (!mounted || error == null) return;
    setState(() => _message = context.isEn
        ? 'Android blocked the install: allow “Install unknown apps” for Densetsu Reading, then tap Install again.'
        : 'Android a bloqué l’installation : autorise « Installer des applis inconnues » pour Densetsu Reading, puis touche Installer à nouveau.');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final en = context.isEn;
    final build = AppUpdater.currentBuild;
    final info = _info;
    final when = info == null ? '' : context.ago(info.date);
    final mb = info == null ? '' : (info.size / 1e6).toStringAsFixed(0);
    final status = switch (_step) {
      _UpdateStep.idle => en ? 'Checks the latest version published on GitHub.' : 'Vérifie la dernière version publiée sur GitHub.',
      _UpdateStep.checking => en ? 'Checking…' : 'Vérification…',
      _UpdateStep.upToDate => en ? 'You have the latest version.' : 'Tu as la dernière version.',
      _UpdateStep.available => en
          ? 'A new version is available ($when, $mb MB).'
          : 'Une nouvelle version est disponible ($when, $mb Mo).',
      _UpdateStep.downloading => '${en ? 'Downloading' : 'Téléchargement'} ${(100 * _progress).round()} %',
      _UpdateStep.ready => en ? 'Downloaded: confirm the install in the Android window.' : 'Téléchargée : confirme l’installation dans la fenêtre d’Android.',
      _UpdateStep.error => _message ?? '',
    };
    final busy = _step == _UpdateStep.checking || _step == _UpdateStep.downloading;
    final (label, action) = switch (_step) {
      _UpdateStep.available => (en ? 'Download and install' : 'Télécharger et installer', _download),
      _UpdateStep.ready => (en ? 'Install' : 'Installer', _install),
      _ => (en ? 'Check for updates' : 'Rechercher une mise à jour', _check),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(en ? 'Update the app' : 'Mettre à jour l’application', style: Txt.label(context)),
              const SizedBox(height: 4),
              Text(
                '${en ? 'Installed version' : 'Version installée'} : ${build.isEmpty ? (en ? 'local build' : 'version locale') : build.substring(0, 7)}',
                style: Txt.caption(context),
              ),
            ]),
          ),
          const SizedBox(width: 16),
          AppButton(label: label, tone: ButtonTone.accent, loading: busy, onTap: busy ? null : action),
        ]),
        const SizedBox(height: 10),
        Text(status, style: Txt.caption(context).copyWith(color: _step == _UpdateStep.error ? p.danger : null)),
        if (_step == _UpdateStep.downloading) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: _progress, minHeight: 6, color: p.accent, backgroundColor: p.surface2),
          ),
        ],
        if (_needsToken || widget.settings.githubToken.isNotEmpty) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _token,
            obscureText: true,
            onChanged: (v) => widget.settings.update((x) => x.githubToken = v.trim()),
            style: Txt.label(context).copyWith(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: en ? 'GitHub token (github_pat_…)' : 'Jeton GitHub (github_pat_…)',
              filled: true,
              fillColor: p.surface2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ]),
    );
  }
}
