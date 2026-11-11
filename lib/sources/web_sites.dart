/// Sites the app can't read itself (protected against apps), opened in the browser instead,
/// already searching for the manga.
class WebSite {
  const WebSite(this.name, this.lang, this._search);
  final String name, lang;
  final String Function(String query) _search;

  Uri searchUri(String title) => Uri.parse(_search(Uri.encodeQueryComponent(title)));
}

final webSites = [
  WebSite('Comix', 'en', (q) => 'https://comix.to/browse?keyword=$q'),
  // The site blocks automated visits, so its own search page can't be checked: a web search
  // limited to the site lands on the manga's page just as well.
  WebSite('MangaDot', 'en', (q) => 'https://www.google.com/search?q=site%3Amangadot.net+$q'),
];
