# Audit de qualité Jibiki

Audit commencé le 6 septembre 2026 sur la révision `ab5d235`.

## Périmètre et méthode

1. Corriger les défauts démontrables d'utilisation, navigation, sauvegarde,
   synchronisation, accès aux contenus et validation des API.
2. Auditer les sources, extractions, imports, bases et packs, puis corriger
   les transformations et intégrer les données vérifiables avec leur provenance.
3. Vérifier les corrections avec des régressions, les suites existantes,
   les builds et les contrôles de cohérence des données.

Les tests s'exécutent sur des bases temporaires. Les données personnelles
ne servent pas de fixtures de test. La présence d'un champ dans un modèle
ne prouve ni sa couverture réelle ni la justesse de son contenu.

## Limites de l'observation

L'application Windows se lance. La capture native par l'outil Computer Use
échoue avec `SetIsBorderRequired / 0x80004002`, après deux tentatives.
Les vérifications de rendu doivent donc utiliser le Web et les widget tests.
Une compilation réussie ne remplace pas une validation visuelle native.

## Résultat au 9 septembre 2026

Les corrections applicatives et les importations sont intégrées dans le dépôt
et la base de développement. Les packs `2026.09.09`, révision 2, sont reconstruits.
Le bundle de l'application a été remplacé après sauvegarde. Le dictionnaire
complet, les définitions EN/FR, les noms et les exemples sont installés sur le
desktop. Les compilations Windows et Web en mode release réussissent.

### Usabilité et navigation

La structure à cinq destinations reste cohérente : dictionnaire, kana,
révisions, communauté et profil. Le problème principal était le comportement
à l'intérieur de ces destinations. Une refonte des noms ou des icônes seule
n'aurait pas corrigé les informations manquantes et les erreurs silencieuses.

- L'accueil donne la priorité à la recherche en mode dictionnaire et pour un
  invité Web. Les compteurs de révision, récompenses et séries ne simulent plus
  une progression indisponible. Sur tablette, l'espace sert à une composition
  adaptée avec navigation latérale ; le mobile conserve la barre inférieure.
- La recherche accepte les saisies successives sans laisser une ancienne réponse
  remplacer la nouvelle. Une saisie effacée ne reçoit plus de résultat tardif.
  Les mots rares des extensions Unicode sont reconnus. Les recherches romaji
  sont compatibles avec les recherches de définitions, notamment en français.
- Les listes proposent une pagination exploitable et conservent leur contenu
  après une erreur récupérable. Les liens de détail ont une issue de retour
  même après une ouverture directe.
- Les fiches mobiles et tablettes donnent accès à tous les sens et exemples
  reçus, aux notes, domaines et restrictions. Les phrases ne sont plus coupées
  arbitrairement. La langue réellement affichée et les contenus historiques
  sont identifiables. Un accent d'une lecture ne s'applique plus à une autre.
- Les aides mémoire suggérées ne prétendent plus être une citation du dictionnaire.
  Les origines sans URL documentée ne reçoivent plus automatiquement une
  attribution Wiktionary. Les contenus non relus restent identifiables.
- L'étude locale est accessible à l'invité sur desktop. Le Web explique son
  besoin de compte pour les fonctions de progression qui ne sont pas disponibles
  localement dans cette version.

### Fiabilité de l'apprentissage

Une réponse n'avance plus avant sa sauvegarde. Les reprises conservent leur UUID,
les ajouts répétés ne réinitialisent plus l'apprentissage, et les changements
locaux et leur file de synchronisation sont atomiques. Les modifications encore
en attente résistent aux réponses serveur concurrentes. Les réponses d'un ancien
compte sont ignorées après déconnexion. Les migrations locales et le remplacement
cloud supportent l'échec et la reprise. Les statistiques et séries utilisent le
fuseau IANA du compte, y compris les jours de changement d'heure.

Les corrections serveur couvrent aussi les validations de synchronisation, les
votes concurrents, les contenus communautaires non publics, les imports WaniKani
et l'export Anki. Voir `STUDY_RELIABILITY_AUDIT.md` et `DATA_SERVER_AUDIT.md`.

### Données effectivement présentes

| Ensemble | Résultat mesuré |
| --- | ---: |
| Entrées JMdict publiques | 218 726 |
| Identifiants de mots conservés, historiques compris | 218 758 |
| Kanji KANJIDIC2 | 13 108 |
| Noms propres JMnedict | 743 631 |
| Sens normalisés, historiques compris | 678 102 |
| Définitions avec langue, historiques compris | 1 458 166 |
| Phrases japonaises avec traduction EN | 26 198 |
| Liens explicites phrase/sens | 32 227 |
| Kana du catalogue pédagogique | 208 |
| Liens lexicaux kana/mot | 214 sur 145 kana |
| Radicaux portables du catalogue | 260 |
| Relations pédagogiques Kanji alive | 1 234 |
| Kanji avec tracés SVG | 6 416 |
| Kanji avec composants KRADFILE | 12 156 |

Les huit contrôles structurels du rapport `var/audit/dictionary-coverage.json`
sont à zéro : mots sans forme ou sans sens, sens sans définition, définition
vide, niveaux JLPT hors plage et doublons d'identité de forme ou d'ordre de sens.
Les anomalies du fichier officiel sont archivées avec leur preuve, pas inventées
pour remplir les champs. Les 29 alias et trois entrées historiques conservent
les identifiants personnels.

Le miroir entier a été réextrait : 180 161 enregistrements, aucun ajouté ou perdu
par rapport au catalogue initial, et 1 883 enregistrements dont les champs ont
été corrigés. Les cinq sites n'ont aucune erreur de parsing. Les 19 817 pages
coquilles sont recensées pour récupération ultérieure ; leur contenu absent
du miroir n'a pas été fabriqué. Le catalogue final est intègre et les contrôles
de provenance des champs, caractères de remplacement et positions de texte ne
détectent pas d'anomalie. Les 643 désaccords JLPT et 128 désaccords de traits
restent des assertions distinctes avec leurs sources.

### Vérification

- Flutter : 299 tests réussis sur les nouveaux assets, analyse globale sans
  anomalie. Un smoke opt-in supplémentaire a installé et ouvert les six packs
  réels via `PackManager`, puis vérifié définitions françaises, kana, radicaux,
  noms, exemples et anciens identifiants. Le test est ignoré par défaut en CI
  car il dépend des gros artefacts locaux.
- Serveur : la suite complète a passé 262 tests ; trois fixtures de restauration
  ont révélé une liste de colonnes obsolète. Après correction, ces trois tests
  passent. Les 69 régressions finales couvrant dictionnaire, nouveaux romaji,
  importeurs et fiabilité serveur passent aussi. Après les optimisations de
  recherche, 54 tests ciblés passent, puis quatre tests de limitation des requêtes
  et de secours anglais passent après le dernier ajustement. La collection finale
  compte 284 cas ; elle n'a pas fait l'objet d'une nouvelle exécution complète.
- Parseurs et catalogue : 209 tests réussis. Réextraction et contrôles exhaustifs
  sur les 180 161 lignes, comparaison des identités et des empreintes avant/après.
- Django : `check` et `makemigrations --check --dry-run` passent. Ruff et le
  contrôle de formatage passent sur tous les fichiers Python du serveur.
- Builds Windows et Web release réussis. Contrôle visuel Web et widget tests
  aux formats mobile et tablette. La limite de capture native mentionnée plus
  haut reste applicable.

Les journaux, manifests, empreintes, rapports de quarantaine et comparaisons
sont regroupés dans `var/audit`. Aucun test n'utilise la progression personnelle
comme fixture. L'installation des packs a conservé à l'identique les empreintes
des fichiers `user.db`, WAL et SHM avant le lancement de l'application.

La migration `0015_search_upper_indexes` est appliquée. Les index correspondent
désormais aux expressions SQL de recherche ; la recherche de noms évite une
jointure du catalogue entier. Sur cette machine, après réchauffement du cache,
la requête française « eau » passe de 3 869 à 129 ms, « mizu » de 635 à 92 ms
et « water » de 590 à 98 ms. Ce sont des mesures locales, pas une garantie de
latence. Les recherches de sous-chaîne à un caractère restent moins favorables
aux index trigrammes. Les plans et mesures sont conservés dans `var/audit`.

### Limites honnêtes

La couverture d'une source ne constitue pas une validation humaine exhaustive.
Les définitions françaises sont moins nombreuses que les anglaises. Les exemples
de phrases importés sont anglais. Les kana additionnels hors du catalogue de
208 cibles nécessitent un contrat pédagogique complet avant publication.
Les histoires anciennes et les brouillons de mnémotechniques ont encore besoin
d'une relecture traçable dans chaque langue. Les variantes secondaires de noms
sont conservées mais leur recherche n'a pas encore d'index relationnel dédié.
Les 18 893 lectures avec accent incluent des accents conservés de l'ancien
bundle : 2 294 ont une nouvelle chaîne de preuve Kanjium vérifiée pendant cet
audit. La conservation des autres ne constitue pas leur recertification.

Le prototype LLM de 30 fiches est identifié dans les archives et n'alimente pas
le dictionnaire reconstruit. Le texte des sources Web conservées pour référence
n'est pas publié en bloc. Aucun remplissage par IA n'a été utilisé pour masquer
un manque de données.

## Rapports détaillés

- `DATA_PIPELINE_AUDIT.md` : structure, sources, miroir, preuves et commandes.
- `DATA_SERVER_AUDIT.md` : importeurs, anomalies, provenance, alias et exemples.
- `DATA_CLIENT_PACK_AUDIT.md` : packs, langue, cache et consultation hors ligne.
- `DATA_KANA_MNEMONICS_AUDIT.md` : kana, exemples et politique de mnémotechniques.
- `DATA_KANJIALIVE_AUDIT.md` : radicaux, jointures et parité avec les CSV sources.
- `STUDY_RELIABILITY_AUDIT.md` : sauvegarde, synchronisation et calendrier.

Sauvegardes locales : `var/audit/backups/jibiki-pre-quality-20260906.dump`,
`var/audit/backups/bundled-packs-pre-20260909` et
`var/audit/backups/native-pre-open-20260909`. Aucune modification n'a été commitée.
