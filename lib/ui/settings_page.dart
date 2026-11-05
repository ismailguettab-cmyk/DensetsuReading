import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n.dart';
import '../core/services.dart';
import '../core/settings.dart';
import '../core/theme.dart';
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
