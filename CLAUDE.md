# Densetsu Reading

Application de lecture de mangas, pensée tablette en paysage (portrait fonctionnel). Répondre en français.
Dépôt : https://github.com/ismailguettab-cmyk/DensetsuReading (branche `main`).

## Environnement
- PC pro Windows **sans droits admin** : Flutter installé en portable dans `%LOCALAPPDATA%\Programs\flutter`
  (`flutter.bat`), Node dans `%LOCALAPPDATA%\Programs\node`. Ne jamais proposer d'installation admin.
- Commits **sans ligne Co-Authored-By** ; identité Git `ismailguettab-cmyk` / `344953067+ismailguettab-cmyk@users.noreply.github.com`.
- L'utilisateur débute : expliquer simplement, montrer l'avancement dans l'aperçu.

## Aperçu
- `flutter build web --release --no-tree-shake-icons` puis `node tool/dev_server.mjs` (port 5173).
- Le serveur sert `build/web` et relaie les sites de mangas via `/proxy?url=…&referer=…` (CORS, Referer).
  Sur tablette ce relais est inutile : `lib/core/net.dart` appelle directement.
- `google_fonts` est figé en ^8 : la v9 dépend de `material_ui` et casse avec Flutter 3.47.

## Architecture (`lib/`)
- `core/` : réglages (`settings.dart`), thème et typo (`theme.dart`, classe `Txt`), animations (`motion.dart` :
  `Pressable`, `Reveal`, `CountUp`, ressorts façon Apple), textes FR/EN (`l10n.dart`, `context.t('clé')`).
- `anilist/` : API GraphQL (limite 30 req/min → requêtes groupées par alias), session (jeton OAuth ou pseudo
  public en lecture seule), recommandeur.
- `sources/` : contrat inspiré de TachiyomiSY (`MangaSource` : popular, search + filtres, details, chapters, pages).
  Moteurs communs `Madara` et `MangaThemesia` + classes par site (`fr_sites.dart`, `en_sites.dart`, `ja_sites.dart`).
  Langues : FR, EN, JA uniquement. Pages avec adresse de secours (MangaDex : uploads.mangadex.org) et nouvel essai auto.
- `translate/` : traduction des bulles avec Google Gemini **gratuit** (clé aistudio.google.com, Flash puis Flash-Lite,
  requêtes en file espacées). Pas d’option payante (demande de l’utilisateur). On efface seulement le texte d’origine.
- `ui/` : shell (barre latérale en paysage, barre flottante en portrait, une pile de navigation par onglet),
  pages Accueil, Recommandations, Recherche, Sources, Paramètres, fiche manga, lecteur.

## Décisions
- Design maison, sobre (bleu nuit, accent pervenche, ambre pour l'action principale). Rien copié de TachiyomiSY
  côté design : seulement les fonctions techniques.
- Recommandations : profil de goûts (genres, tags pondérés par statut, note, récence, recherches), signal
  collaboratif AniList, tirage pondéré ; un tirage est gardé 5 min puis renouvelé à chaque visite.
- Lecteur : sens droite→gauche / gauche→droite / vertical, simple / double / auto, remplissage « Remplir l'écran »
  (sans bordure ni déformation, le surplus défile), pages larges affichées seules, décalage et inversion des doubles.
- Traduction : garde noms, honorifiques et techniques en japonais ; police Comic Neue (la police d'origine ne peut
  pas être reconnue), taille plafonnée à celle d'origine, texte ajusté pour ne jamais dépasser la bulle.
- Sources testées et écartées : CrunchyScan (redirige vers un site douteux), Epsilon Scan (Cloudflare),
  Lelscan / Inovascan / Phenix Scans (hors ligne), sushiscan.fr (504). Scantrad Union possible plus tard (thème maison).

## À faire
- Connexion AniList OAuth : l'utilisateur doit créer un client sur anilist.co (redirection `http://localhost:5173/auth`).
- Clé Gemini gratuite à saisir dans Paramètres pour tester la traduction (pas encore testée).
- APK via GitHub Actions (prochaine session).
- Version tablette Android / iPad (SDK Android ou Mac requis), sources anglaises de everythingmoe.com.
