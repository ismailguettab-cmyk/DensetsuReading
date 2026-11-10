# Sauvegarde du projet Densetsu Reading (au 2026-11-10)

Synthèse de toutes les sessions, à lire en premier pour reprendre. Détails techniques : `CLAUDE.md`.

## Ce qu'est l'app
Lecteur de mangas Flutter, tablette Android en paysage d'abord (portrait fonctionnel), FR par défaut (EN possible).
Connexion AniList OAuth **fonctionnelle** (client 55950) ou pseudo public en lecture seule.
Dépôt public : github.com/ismailguettab-cmyk/DensetsuReading, branche `main`. APK à jour à chaque push (release `apk-latest`),
installable par-dessus grâce à une clé de signature fixe ; mise à jour possible depuis Paramètres → Application.

## Historique (dans l'ordre)
1. **V1** : Flutter sans admin, aperçu web via `tool/dev_server.mjs` (relais CORS/Referer, port 5173).
2. **Lecteur** : droite→gauche / gauche→droite / vertical, simple / double / auto, pages larges seules, décalage/inversion,
   nouvel essai auto + adresse de secours des pages.
3. **Recommandations** (v1 par notes, remplacée le 10/11, voir 8).
4. **Sources FR/EN/JA** : moteurs `Madara` et `MangaThemesia` + classes par site (liste dans `lib/sources/`).
5. **Traduction des bulles** : Gemini gratuit, jamais testée avec une vraie clé.
6. **Design « mode jour »** (Claude Design) : Accueil, Bibliothèque, Recommandations, Recherche, fiche, Sources.
7. **10/11 – passage sur tablette** (nouveau PC sans Flutter) : APK construit par GitHub Actions ; permission Internet,
   nom « Densetsu Reading », plein écran bord à bord (plus de bande noire), lecteur en immersif.
8. **10/11 – liste de bugs tablette corrigée** :
   - Entrée : « La weeberie sans limite », trois planches (Vegito, Ichigo, Naruto dans `assets/login/`) en page de manga,
     un seul bouton AniList + pseudo.
   - Accueil : animations rejouées à chaque visite, en-tête avec la couverture AniList du manga, rangée « Lus récemment »
     = 5 derniers mangas **terminés** avec tampon 読了, bibliothèque fluide (couvertures décodées à la bonne taille).
   - Pour toi : seulement les rayons (étagères tracées au pinceau, livres qui tombent et se stabilisent, silhouettes de la
     maquette au lieu des jaquettes), livre à 4 doubles pages par catégorie, cases cliquables (détection par forme),
     étiquettes titre + note, Recharger avec coups d'encre. Nouvel algorithme fondé sur les goûts (voir CLAUDE.md).
   - Recherche : tout le catalogue AniList, barre + filtres dès l'ouverture, chargement au défilement, tache d'encre
     « DANS MA LISTE » ; parcourir une source reste possible depuis l'onglet Sources.
   - Fiche : personnage qui défile avec l'en-tête, vérification des sources réparée (point vert / croix), sources par
     langue, chapitres lus barrés d'un trait de pinceau fin + « Reprendre · p. X », bouton Effacer les marques,
     bouton « Marquer comme terminé » (AniList), correspondance source plus stricte.
   - Lecteur : double page + Remplir l'écran couvre tout l'écran (étirement ≤ 12 %, puis rognage haut/bas).
   - Toutes les animations rejouées en revenant sur un onglet (la Recherche garde sa requête).
9. **10/11 – infrastructure** : mise à jour intégrée (GitHub, Android), dépôt passé en public, clé de signature fixe
   (`C:\Users\ismai\DensetsuReading-signature\`, à sauvegarder ; secrets GitHub), comix.to étudié et écarté.

## Préférences de l'utilisateur
- Débutant : expliquer simplement ; répondre en français.
- **Pousser directement sur `main`**, puis lui dire quand l'APK est à jour (~7 min).
- Commits **sans** ligne Co-Authored-By.
- Économiser les tokens : peu de captures, lire les maquettes en sautant les tracés SVG.
- Kanji uniquement dans les onglets et sur les tampons. Respecter la DA encre / crème / rouge.
- Pas d'option payante (Gemini gratuit uniquement).

## Pièges connus
- Pas de Flutter local : on ne voit les erreurs qu'au build GitHub (`gh run view <id> --log-failed`).
  `flutter analyze` bloque aussi sur les avertissements (variables / fonctions inutilisées).
- Fichiers en CRLF : éditer avec l'outil Edit ; les heredocs bash mangent les `\\`.
- Clé de signature perdue = désinstallation obligatoire pour les mises à jour suivantes.
- `google_fonts` figé en 8.0.0. Anime-Sama change souvent de domaine. Réseau du travail : bloque plusieurs sources.

## À faire (prochaine session)
1. Tester la traduction Gemini avec une clé.
2. Version web en ligne (GitHub Pages) : créer un 2e client AniList (redirection = adresse du site) et un relais pour les sources.
3. Mode jour restant : Paramètres au style encre, états vides, finitions portrait. Mode nuit ensuite.
4. Accélérer le build (cache Gradle + APK arm64 seul), nouvelles sources anglaises (everythingmoe.com).

## Design (Claude Design)
Canevas : https://claude.ai/artifact/HRHK6btamwDs8rjdf9hFck — planches : StyleGuide, Animations, Main (Accueil),
Library, Reco, Search, Manga, Reader, Sources, Settings, Login, Filters, States, Fonts, MainPortrait, MangaPortrait,
ReaderPortrait. Lire une planche : outil Artifact, action `read`, `path: "project/<Nom>.dc.html"`.
Animations clés : coups de pinceau (arrivée), éclaboussure (ouvrir), traits de vitesse (fin de chapitre), tampon (lu),
trait de pinceau qui barre un chapitre lu (.18 s, cubic-bezier(.95,0,.2,1)).
