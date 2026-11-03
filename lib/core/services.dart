import 'package:shared_preferences/shared_preferences.dart';

import '../anilist/recommender.dart';
import '../anilist/session.dart';
import '../sources/catalog.dart';
import '../translate/translator.dart';
import 'activity.dart';
import 'platform.dart';
import 'settings.dart';

/// App-wide state, created once at startup.
class Services {
  Services._(SharedPreferences prefs)
      : settings = Settings(prefs),
        session = Session(prefs),
        activity = Activity(prefs),
        sources = SourceStore(prefs) {
    reco = Recommender(prefs, session, activity);
    translator = Translator(settings);
  }

  static late final Services i;

  final Settings settings;
  final Session session;
  final Activity activity;
  final SourceStore sources;
  late final Recommender reco;
  late final Translator translator;

  static Future<void> init() async {
    i = Services._(await SharedPreferences.getInstance());
    final token = takeRedirectToken();
    if (token != null) {
      i.session.signInWithToken(token);
    } else {
      i.session.refresh();
    }
  }
}
