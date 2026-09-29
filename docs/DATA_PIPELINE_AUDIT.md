# Audit des sources et de la chaîne de données

Audit du 6 au 9 septembre 2026. Les artefacts volumineux restent dans `var/audit`,
hors Git. Les importeurs, contrôles et régressions sont versionnables avec le code.

## Conclusion sur la structure

Le découpage entre mots, formes, sens, traductions et contenus pédagogiques est
adapté. Le défaut principal était la perte de contexte lors des transformations,
puis des associations implicites présentées comme certaines. Remplacer toutes
les tables n'aurait pas résolu ce problème et aurait fragilisé les références
d'apprentissage. L'audit renforce les relations explicites et les preuves source.

- `Word.seq` identifie l'entrée JMdict ; `Word.id` reste l'identifiant local stable
  référencé par les cartes. Les variantes graphiques et lectures restent des formes.
- Un sens conserve ses restrictions, catégories, domaines et notes. Ses traductions
  sont séparées et conservent leur langue. La couverture française peut être plus
  faible sans être complétée par une traduction inventée.
- `ExampleSenseLink` relie une phrase à un sens précis. Un numéro de sens provenant
  d'un autre fichier ou la présence d'une sous-chaîne ne constitue plus un lien.
- `KanaWordExample` illustre un kana par une lecture exacte d'un mot canonique.
  Les exemples lexicaux sont distincts des exemples de grammaire et des histoires.
- Une mnémotechnique conserve sa langue, sa provenance et son état de relecture.
  La visibilité dans la communauté ne constitue pas une validation linguistique.
- La décomposition visuelle KRADFILE, le radical classique KANJIDIC2 et la
  classification pédagogique Kanji alive restent trois assertions différentes.

## Sources de référence réimportées

| Source | Usage | Preuve locale |
| --- | --- | --- |
| JMdict multilingue | Entrées, formes, sens, traductions et restrictions | XML complet et SHA-256 du téléchargement |
| JMdict_e_examp | Phrases avec liens explicites vers les sens | Source, citation, occurrence, position et SHA-256 |
| KANJIDIC2 | Caractères, lectures, sens, références et variantes | XML complet et SHA-256 |
| JMnedict | Noms propres et variantes | XML complet et SHA-256 |
| KanjiVG r20250816 | Tracés SVG ordonnés | Archive de version, journal et SHA-256 par SVG |
| KRADFILE et KRADFILE2 | Composants visuels de recherche | Archive officielle, fichier et SHA-256 |
| Kanjium déjà récolté | Accents des lectures exactement correspondantes | SHA-256 de la base source, extraction corrigée et correspondances |
| Kanji alive déjà récolté | Radicaux et relations pédagogiques documentées | Manifest de récolte, SHA-256 et identifiants source distincts |

Les formats EDRDG sont décrits dans le [wiki de l'éditeur](https://www.edrdg.org/wiki/Main_Page.html).
Les composants KRADFILE ne correspondent pas exactement aux 214 radicaux
classiques : l'[éditeur explique cette distinction](https://www.edrdg.org/krad/kradinf.html).
Les tracés proviennent de la [version KanjiVG r20250816](https://github.com/KanjiVG/kanjivg/releases/tag/r20250816).

La base contient désormais 6 416 kanji avec tracés, contre 2 211 dans le bundle
restauré, et des composants KRADFILE pour 12 156 kanji. Un nombre de chemins SVG
différent du nombre de traits d'une autre source reste une différence de sources,
pas une raison de remplacer silencieusement le comptage canonique.

## Miroir Web conservé et réextrait

Le catalogue initial contient 180 161 enregistrements issus de cinq sites :
WaniKani, Kanshudo, KanjiDraw, The Kanji Map et Tanoshii Japanese. Le contrôle
parcourt chaque enregistrement, ses champs, sa provenance et les annotations
de texte. La représentation d'origine reste récupérable sans perte dans SQLite.

Le premier catalogue relève 643 groupes de désaccords de niveau JLPT et 128
de nombre de traits. Ces groupes regroupent les assertions et leurs URL ; ils
ne sont pas un vote permettant de choisir une vérité par majorité. Les niveaux
anciens de KANJIDIC2 ne deviennent pas automatiquement des niveaux JLPT modernes.

Les corrections du parseur préservent le texte suivant les annotations ruby,
commentaires et scripts, excluent le texte situé hors du champ demandé et
préservent les espaces japonais explicitement présents. Les positions des
annotations continuent de pointer vers le texte extrait. Un calcul cumulatif
remplace le recalcul quadratique de la longueur des fragments HTML. Sur la page
profilée, le temps est passé de 3,439 s à 0,122 s ; ce chiffre concerne cette
page, pas un gain garanti identique pour chaque site.

Les champs marqués `reference-only` ne sont pas publiés par un import global.
Ils restent consultables dans le catalogue d'audit. Les pages vides nécessitant
une nouvelle récupération restent comptées séparément des erreurs de parsing.

La réextraction finale conserve exactement les 180 161 identités initiales.
Elle modifie 1 883 enregistrements : 1 chez Kanshudo, 1 834 chez Tanoshii Japanese,
2 chez The Kanji Map et 46 chez WaniKani. Aucun enregistrement ajouté ou perdu.
Les 19 817 coquilles sans contenu récupérable sont listées à part. Les contrôles
du catalogue final ne trouvent aucune annotation invalide ni provenance de champ
manquante ; l'intégrité SQLite est `ok`.

## Incertitudes et génération antérieure

Le dossier `var/llm_prototype` contient un prototype de 30 fiches, avec le champ
`llm_pass_language`. Ses scripts servent à la comparaison ; aucun chemin de
chargement dans l'application ou le serveur ne consomme ces fichiers. Ces fiches
ne sont pas une source du dictionnaire reconstruit.

Les 184 histoires kana déjà visibles, en anglais et en français, n'enregistrent
pas de preuve suffisante d'auteur ou de relecture. Leur origine humaine ou IA
n'est pas déductible du fichier. Les milliers de brouillons de mnémotechniques
kanji restent distincts du catalogue publié. Aucune histoire n'a été inventée
ou traduite automatiquement pour compléter la couverture pendant cet audit.

Les notes étymologiques restaurées depuis l'ancien pack gardent leur contenu,
mais ne reçoivent pas une attribution Wiktionary certaine sans URL documentée.
Les anciens identifiants de démonstration peuvent devenir des alias exacts.
Les entrées anciennes sans correspondance unique restent consultables par leur
identifiant personnel avec leur statut historique, hors nouvelles recherches.

## Reproduire les contrôles

Depuis la racine du dépôt, avec les dépendances Python du serveur :

```powershell
server/.venv/Scripts/python.exe scripts/extract_mirrored_content.py --out var/audit/site_extract_20260909 --jobs 8
server/.venv/Scripts/python.exe scripts/audit_source_corpus.py --extract-root var/audit/site_extract_20260909 --out var/audit/source-corpus-after
server/.venv/Scripts/python.exe -m pytest scripts/site_parsers/tests -q
```

Depuis `server`, après configuration de `DATABASE_URL` :

```powershell
./.venv/Scripts/python.exe manage.py audit_dictionary --out ../var/audit/dictionary-coverage.json
./.venv/Scripts/python.exe manage.py check
./.venv/Scripts/python.exe manage.py makemigrations --check --dry-run
./.venv/Scripts/python.exe -m pytest -q
```

Les commandes d'import et leurs garanties sont détaillées dans
`DATA_SERVER_AUDIT.md`, `DATA_KANA_MNEMONICS_AUDIT.md` et `DATA_CLIENT_PACK_AUDIT.md`.
Le rapport général `QUALITY_AUDIT.md` donne les résultats finaux mesurés.
