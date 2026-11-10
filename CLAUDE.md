# Densetsu Reading


> Reprise : lire d’abord `SAUVEGARDE.md` (synthèse de tout le projet, maquettes Claude Design comprises).
Application de lecture de mangas, pensée tablette en paysage (portrait fonctionnel). Répondre en français.
Dépôt **public** : https://github.com/ismailguettab-cmyk/DensetsuReading (branche `main`).

## Environnement
- PC perso Windows **sans Flutter ni Java ni SDK Android** (l’utilisateur préfère ne rien installer) : tout se compile
  sur **GitHub Actions** (`.github/workflows/apk.yml`). Ne jamais proposer d'installation admin. Node est disponible.
  (Ancien PC pro : Flutter portable dans `%LOCALAPPDATA%\Programs\flutter`, aperçu web via `tool/dev_server.mjs`.)
- **Pousser directement sur `main`** (pas de branche intermédiaire : chaque build prend ~7 min).
  Chaque push = `flutter analyze --no-fatal-infos` (erreurs ET avertissements bloquent) + APK signé + release `apk-latest`.
  Lien fixe : https://github.com/ismailguettab-cmyk/DensetsuReading/releases/download/apk-latest/DensetsuReading.apk
- Commits **sans ligne Co-Authored-By** ; identité Git (config du dépôt) `ismailguettab-cmyk` / `344953067+ismailguettab-cmyk@users.noreply.github.com`.
- Fichiers en CRLF : préférer l’outil Edit aux scripts `node -e` (les apostrophes cassent le shell).
- L'utilisateur débute : expliquer simplement.

## Build et signature
- APK signé avec une **clé fixe** (sinon Android refuse la mise à jour : « package en conflit »).
  Clé PKCS12 hors dépôt : `C:\Users\ismai\DensetsuReading-signature\` (`release.p12`, `password.txt`, alias `densetsu`).
  Secrets GitHub : `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` ; lus par `android/app/build.gradle.kts`.
- `--build-number=${{ github.run_number }}` et `--dart-define=BUILD_SHA=${{ github.sha }}` (version comparée par la mise à jour intégrée).
- `google_fonts` figé en 8.0.0 (la v9 casse). Plugins natifs : `flutter_web_auth_2` (connexion AniList), `open_filex` + `path_provider` (mise à jour).

## Architecture (`lib/`)
- `core/` : réglages (`settings.dart`, dont jeton GitHub facultatif), thème (`theme.dart`, `Txt`), animations (`motion.dart`),
  textes FR/EN (`l10n.dart`), `activity.dart` (recherches, lectures, marques de chapitres effacées),
  `platform*.dart` (connexion AniList : Android = `flutter_web_auth_2` + `densetsureading://auth`, web = redirection),
  `updater*.dart` (mise à jour depuis la release GitHub, uniquement Android).
- `anilist/` : API GraphQL (30 req/min → alias groupés ; `browse()` = recherche catalogue avec filtres), session
  (OAuth ou pseudo en lecture seule ; `markCompleted`, `addToPlan`), recommandeur.
- `sources/` : contrat inspiré de TachiyomiSY ; moteurs `Madara` / `MangaThemesia` + sites FR/EN/JA.
- `translate/` : bulles traduites avec Gemini **gratuit** (jamais testé avec une vraie clé).
- `ui/` : shell (une pile de navigation par onglet ; chaque retour sur un onglet reconstruit sa page pour rejouer
  les animations), `login_page` (planches de manga + carte AniList), `home_page`, `reco_page` (rayons) + `reco_book`
  (livre ouvert en double page manga) + `reco_symbols.dart` (silhouettes générées depuis la maquette Reco),
  `anilist_search_page` (onglet Recherche), `search_page` (parcourir une source, ouvert depuis Sources), `manga_page`,
  `reader_page`, `settings_page` (section Application = mise à jour), `ink.dart` (kit d’encre : `OneShot`, `PaintReveal`,
  `HankoStamp`, `InkRoute`, `InkSweepPainter`, `InkReload`, `InkStretchTag`…).

## Décisions
- DA « mode jour » (canevas https://claude.ai/artifact/HRHK6btamwDs8rjdf9hFck) : crème #F2EBDD, papier #FBF8F1,
  encre #121010, rouge sang #B5121B ; Noto Serif JP + Noto Sans JP ; formes carrées, bordures 2 px, ombres décalées.
  Kanji seulement dans les onglets et sur les tampons. Animations : transformations et opacité uniquement.
- AniList : client **55950** (redirection `densetsureading://auth`) codé dans `AniList.appClientId`.
  Client web pas encore créé (`webClientId` vide).
- Recommandations : goûts d’abord (profil par catégorie, tags pondérés), pas de bonus note/popularité, tout le catalogue
  (tris et pages aléatoires, `lastPage` appris), anti-répétition sur 12 tirages, 24 titres par catégorie, cache disque
  affiché tout de suite, préparées au lancement. Recharger tout ou une catégorie (coups d’encre).
- Recherche = catalogue AniList (filtres statut, catégories, public, note, publication, origine, format, tri) ;
  la source se choisit seulement dans la fiche.
- Fiche : correspondance source stricte (≥ 0,75, identifiant AniList prioritaire) ; sources groupées par langue ;
  chapitres lus barrés d’un trait de pinceau ; bouton Effacer ; « Marquer comme terminé ».
- Lecteur : double page + « Remplir l'écran » = plein écran sans défilement (étirement ≤ 12 % puis rognage haut/bas).
- Sources écartées : CrunchyScan, Epsilon/Astral/MangaKawaii (Cloudflare), MangaHub, Raw1001, comix.to (API à jeton
  anti-robots), sites hors ligne.

## À faire
- Tester la traduction Gemini avec une vraie clé.
- Version web en ligne (GitHub Pages possible, dépôt public) : 2e client AniList + relais pour les sources.
- Mode jour restant : écran Paramètres au style encre, états vides, finitions portrait. Mode nuit plus tard.
- Accélérer le build (cache Gradle, APK arm64 seul) si l’attente gêne.
