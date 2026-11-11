import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import 'ink.dart';
import 'widgets.dart';

/// A site the app can't read by itself (protected against apps), shown inside the app:
/// the user searches and reads on the site's own pages, full screen, without leaving.
class WebReaderPage extends StatefulWidget {
  const WebReaderPage({super.key, required this.title, required this.url});
  final String title;
  final Uri url;

  /// Opens the site in the app (on the web version, a new browser tab).
  static Future<void> open(BuildContext context, {required String title, required Uri url}) async {
    if (kIsWeb) {
      await launchUrl(url, webOnlyWindowName: '_blank');
      return;
    }
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => WebReaderPage(title: title, url: url)));
  }

  @override
  State<WebReaderPage> createState() => _WebReaderPageState();
}

class _WebReaderPageState extends State<WebReaderPage> {
  late final WebViewController _web;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      }))
      ..loadRequest(widget.url);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Back goes back in the site first, then closes the page.
  Future<void> _back() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(child: WebViewWidget(controller: _web)),
          if (_progress < 100)
            Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator(value: _progress / 100, minHeight: 3, color: inkRed, backgroundColor: Colors.transparent)),
          // Small ink bar: close, and the site's name.
          Positioned(
            left: 12,
            bottom: 14,
            child: SafeArea(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconCircle(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop(), tooltip: context.t('common.close')),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  color: inkBlack,
                  child: Text(widget.title, style: Txt.label(context).copyWith(color: inkPaper, fontSize: 13)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
