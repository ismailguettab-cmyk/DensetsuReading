# Sauvegarde du projet Densetsu Reading (au 2026-11-05)

Synthèse de toutes les sessions, à lire en premier pour reprendre. Détails techniques : `CLAUDE.md`.

## Ce qu'est l'app
Lecteur de mangas Flutter, tablette en paysage d'abord (portrait fonctionnel), FR par défaut (EN possible).
Connexion AniList (OAuth prêt mais non configuré ; mode « pseudo » en lecture seule utilisé pour tester).
Dépôt : github.com/ismailguettab-cmyk/DensetsuReading, branche `main`. Dernier commit : `4c8068a`.

## Historique (dans l'ordre)
1. **V1** : Flutter installé sans admin, aperçu web via `tool/dev_server.mjs` (relais CORS/Referer, port 5173).
   Onglets Accueil (profil AniList), Recommandations, Recherche, Sources, Paramètres ; fiche manga ; lecteur.
2. **Lecteur** : droite→gauche / gauche→droite / vertical, simple / double / auto, « Remplir l'écran » sans bordure
   ni déformation (le surplus défile), pages larges seules, décalage/inversion des doubles, zones de toucher.
   Pages qui échouent : nouvel essai auto + adresse de secours (MangaDex → uploads.mangadex.org) + bouton Recharger.
3. **Recommandations** : profil de goûts (genres/tags, statut, note, récence, recherches) + recos AniList ;
   basées sur les **notes** (pas la popularité), moitié « pépites » peu connues ; tirage gardé 5 min.
4. **Sources (FR/EN/JA uniquement)** : moteurs `Madara` et `MangaThemesia` + classes par site.
   FR : Sushi-Scan, Anime-Sama, LelManga, Harmony Scan, Pantheon Scan, Scan-VF, LelscanFR, Scantrad Union, FMTeam,
   DassouScan, MangaDex. EN : Weeb Central, MangaPill, Atsumaru, MangaKatana, Toonily, ManhwaTop, MangaDex.
   JA : Rawdevart, MangaRW, MangaDex. Écartées : CrunchyScan (site douteux), Epsilon/Astral/MangaKawaii
   (Cloudflare), MangaHub (jeton), Raw1001 (trop lent), sites hors ligne. Fiche : point vert sur les sources qui ont le manga.
5. **Traduction des bulles** : Google **Gemini gratuit** (clé aistudio.google.com ; pas d'option payante, demande ferme).
   Garde noms, honorifiques, techniques en japonais ; efface seulement le texte d'origine, police Comic Neue.
   File d'attente espacée (quota gratuit). **Jamais testée avec une vraie clé.**
6. **Design « mode jour »** (validé sur Claude Design, voir plus bas) appliqué à : Accueil, Bibliothèque,
   Recommandations (omikuji, livres, double page manga), Recherche, fiche manga, Sources.

## Préférences de l'utilisateur
- Débutant : expliquer simplement, montrer l'aperçu ; répondre en français.
- Commits **sans** ligne Co-Authored-By. Commit/push seulement quand il le demande.
- Économiser les tokens : peu de captures, lire les maquettes en sautant les tracés SVG.
- Kanji uniquement dans les onglets et sur les tampons.

## Pièges connus
- **Réseau du travail** : bloque MangaDex, Weeb Central, Sushi-Scan, Anime-Sama (certificat intercepté). Scan-VF passe.
- `preview_start` par nom lance parfois le serveur de TrackVinti : lancer `node tool/dev_server.mjs` puis ouvrir l'URL.
- `google_fonts` figé en ^8 (la v9 casse avec Flutter 3.47). `python3` n'existe pas (stub Windows) : utiliser node.
- Anime-Sama change souvent de domaine.

## À faire (prochaine session)
1. **Bugs** signalés par l'utilisateur (« pas mal de bugs ») : lui demander la liste en premier.
2. Mode jour restant : Paramètres, connexion, états vides, finitions portrait (maquettes Settings, Login, States, *Portrait).
3. **APK via GitHub Actions** (pas d'installation locale).
4. Tester la traduction Gemini avec une clé. Configurer AniList OAuth (redirection à adapter pour l'APK).
5. Mode nuit (lune / cerisier / bleu nuit) seulement quand le jour sera parfait.

## Design (Claude Design)
Canevas : https://claude.ai/artifact/HRHK6btamwDs8rjdf9hFck — planches : StyleGuide, Animations, Main (Accueil),
Library, Reco, Search, Manga, Reader, Sources, Settings, Login, Filters, States, Fonts, MainPortrait, MangaPortrait,
ReaderPortrait. Lire une planche : outil Artifact, action `read`, `path: "project/<Nom>.dc.html"`.
Animations clés : coups de pinceau (arrivée), éclaboussure (ouvrir), traits de vitesse (fin de chapitre), tampon (lu).
