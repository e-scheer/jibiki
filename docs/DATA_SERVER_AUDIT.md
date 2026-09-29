# Audit du dictionnaire serveur

Travail commencé le 6 septembre 2026, repris et vérifié le 9 septembre 2026.
Ce document décrit les importeurs et les contrats serveur. Le rapport général
`QUALITY_AUDIT.md` et les rapports de corpus contiennent la validation finale
de la base reconstruite et des packs distribués.

## Sources parcourues intégralement

Un parcours XML complet des fichiers de `var/audit/upstream` a produit
`parser-inventory.json`. Ces nombres décrivent les fichiers sources, pas une
estimation de couverture pédagogique et pas une validation humaine de chaque entrée.

| Source | Entrées | Langues de traduction | Plus longue forme écrite/lecture | Identifiants source dupliqués |
| --- | ---: | --- | ---: | ---: |
| JMdict | 218 726 | en, nl, de, ru, es, hu, sv, fr, sl | 37 caractères | 0 |
| JMnedict | 743 631 | en | 41 caractères | 0 |
| KANJIDIC2 | 13 108 | en, fr, es, pt | sans objet | 0 |

JMdict contient 443 023 glosses anglaises et 33 782 françaises. Les autres
langues sont conservées lorsque l'import est lancé avec `--langs all`.
L'écart de couverture entre langues est réel. Aucune traduction n'est inventée
pour le masquer. KANJIDIC2 contient 24 824 sens anglais et 7 643 français.

## Défauts corrigés

- Les anciens imports ne préservaient pas suffisamment le détail du XML :
  restrictions entre écritures et lectures, restrictions par sens, renvois,
  antonymes, dialectes, origines d'emprunts, attributs des glosses, variantes de
  noms et métadonnées des kanji. Les champs normalisés restent interrogeables,
  et une représentation structurée du XML conserve les informations non encore
  exploitées par l'interface.
- Les déclarations d'entités de la DTD sont transformées au niveau du flux XML
  pour conserver les codes, par exemple `n`, plutôt que leurs descriptions.
  Les parties du discours héritées d'un sens précédent sont rétablies.
- Les glosses et notes ne sont plus tronquées par des colonnes trop courtes.
  L'encodage invalide provoque une erreur, pas un remplacement silencieux.
- JMdict et JMnedict sont actualisés par `ent_seq`, KANJIDIC2 par caractère.
  Les identifiants des mots et kanji existants, cartes, historiques, favoris,
  composants, tracés et accents encore applicables sont conservés.
- Les langues explicitement rafraîchies remplacent leurs seules lignes de
  traduction. Les autres restent intactes. Avec `--langs all`, les enfants
  obsolètes des entrées présentes dans le nouveau snapshot sont retirés. Un
  import limité ne supprime pas le reste du catalogue.
- Le JLPT ancien de KANJIDIC2 est conservé sous `metadata.legacy_jlpt` et ne
  remplace pas automatiquement la classification moderne utilisée par l'app.
- L'import des niveaux JLPT de vocabulaire exige une concordance exacte de
  l'écriture et de la lecture. Une lecture contradictoire, absente ou une
  correspondance ambiguë n'entraîne plus d'attribution. La ligne source et
  l'empreinte sont conservées avec le niveau importé.
- Les variantes d'accent Kanjium d'une même écriture/lecture sont réunies au
  lieu de garder seulement la première. Les restrictions entre écritures et
  lectures sont respectées. Un accent de mot écrit seulement en kana n'est
  plus appliqué à tous les homographes écrits en kanji. La source locale
  d'accents a été parcourue : 2 411 lignes, aucune ligne syntaxiquement invalide.
  Cela vérifie son format, pas sa justesse linguistique.
- L'extracteur Kanjium utilisait aussi le mauvais champ d'écriture : `kanji`
  contient par exemple `上`, tandis que `okurigana` contient le mot complet
  `上げる`. Le nouvel export utilise cette forme complète. Le fichier brut
  correspond au SHA-256 du manifeste de collecte. Le corpus régénéré dans
  `var/audit/kanjium-normalized` conserve les empreintes du brut, de l'extracteur
  et des sorties. L'import final a relié 2 294 lectures à cette chaîne de preuve.
  Trois attributions résiduelles de l'ancien export ont été archivées puis
  retirées du champ d'accent actif, sans toucher aux cartes.
- L'import Tanaka n'efface plus toutes les phrases. Il est transactionnel,
  répétable et conserve la ligne d'indexation B comme preuve, sans lui attribuer
  un sens par supposition.

Chaque import est atomique : une erreur dans une entrée tardive annule aussi
les lots déjà écrits. Les lots bornent la mémoire de travail, pas la transaction.
Les fichiers `.xml` et `.gz` sont acceptés par les importeurs XML.

La réconciliation du fichier complet a identifié 45 entrées contenant une
anomalie source : 42 éléments `sense` vides, une glosse espagnole vide et deux
glosses composées uniquement d'un espace (espagnol et allemand). Les données
brutes et leurs positions sont archivées dans `jmdict_source_anomalies` et
`var/audit/snapshot-reconciliation.json`. Les 43 sens sans aucune définition
et les trois glosses vides ne sont pas publiés. Les sens valides conservent leur
position source, y compris lorsqu'il existe un trou dans la numérotation.

## Exemples explicitement reliés aux sens

La recherche d'une sous-chaîne dans une phrase n'établit pas que cette phrase
illustre un mot. Elle confond notamment les homographes et les frontières de mots.
Ce mécanisme a été retiré du détail dictionnaire.

La commande `import_jmdict_examples` traite `JMdict_e_examp` séparément du
dictionnaire multilingue. Elle utilise `ent_seq`, puis une correspondance exacte
entre contenu anglais du sens, parties du discours, domaines, restrictions,
notes et renvois. Le numéro de sens anglais ne remplace jamais celui du fichier
multilingue : leurs positions peuvent différer.

`ExampleSenseLink` conserve le sens canonique, la position dans la source,
`ex_text`, la citation `ex_srce`, le fichier et son empreinte. Une correspondance
absente ou ambiguë est inscrite au rapport, sans lien deviné. Les phrases
non attribuées restent conservées. Plusieurs phrases traduites distinctement
peuvent conserver la même phrase japonaise sans perdre une traduction.

L'API expose uniquement des exemples liés explicitement au mot demandé.
Elle conserve toutes les traductions taguées, la traduction sélectionnée et sa
langue réelle. Les libellés de langue réelle couvrent aussi les notes d'origine
et usages des kana, ainsi que les noms propres.

## Réconciliation des anciennes entrées de démonstration

`reconcile_demo_aliases` rapproche une entrée de démonstration à séquence
négative d'une entrée JMdict importée à séquence positive uniquement lorsque
toutes ses écritures et lectures correspondent exactement à une seule entrée.
Les restrictions de lecture sont vérifiées. Une ambiguïté reste au rapport.

Le lien `Word.canonical_word` rend ce rapprochement réversible et conserve les
anciens identifiants. Les recherches, listes et nouveaux ensembles de cartes
excluent ces alias. Le détail d'un ancien identifiant montre le contenu canonique
tout en renvoyant l'identifiant demandé et `canonical_id`. Les cartes et leurs
historiques ne changent pas de propriétaire et ne sont pas fusionnés. Si un
utilisateur possédait déjà les deux cartes, les deux historiques demeurent.

La réconciliation réelle a trouvé 29 alias et une ancienne entrée agrégée :
`何` avec les lectures `なに` et `なん`. Le fichier actuel sépare ces lectures
en deux entrées. L'ancien identifiant 30 garde son historique et les deux
références candidates, avec `source_status=legacy_merged_entry`, sans être
proposé comme un nouveau mot. Deux autres identifiants historiques, 57307
(`刻一刻と`) et 79795 (`就いて`), sont absents du snapshot actuel. Ils portent
`source_status=upstream_not_in_snapshot` et restent consultables par leur ancien
identifiant. Aucun remplacement approximatif n'a été imposé.

Les vérifications finales dans `server-data-final-checks.json` comptent
218 726 mots publics, aucun sens sans définition et aucune glosse vide.

## Provenance et limites des garanties

L'import ne déclare plus arbitrairement `generated_by_ai=false`. Une empreinte
ne démontre pas le mode de rédaction d'une source. La provenance indique
`authoring_method=upstream_unspecified` et une transformation déterministe.

`verified_download=true` signifie que les octets importés correspondent au
SHA-256 d'un journal local de téléchargement dont l'URL désigne le fichier EDRDG
attendu. La vérification est nommée `local_download_sidecar_sha256`, et l'URL
exacte et la date sont conservées. Ce journal ne constitue pas une signature
cryptographique de l'éditeur ni une relecture humaine du contenu.

`refresh_dictionary_provenance` corrige ces preuves en place pour les seules
lignes dont l'empreinte correspond au fichier fourni. Il n'est pas nécessaire
de réimporter le catalogue pour corriger ce champ.

Les métadonnées XML complètes restent dans la base canonique. L'API et les packs
retirent `metadata.raw` pour éviter d'envoyer plusieurs copies de toutes les
traductions avec chaque sens. Les restrictions et autres champs normalisés
restent transmis.

Les variantes de noms sont archivées dans `Name.metadata.kanji/readings`; la
recherche serveur indexe actuellement l'écriture et la lecture principales.
Les variantes secondaires n'ont pas encore un index relationnel de recherche.
Ajouter un filtre JSON non indexé à chaque recherche entraînerait un parcours
des 743 631 noms. Cette extension nécessite un index adapté ou une table de
formes, puis une migration vérifiée, plutôt qu'un ralentissement silencieux.
La couverture française, les exemples et les mnémotechniques restent partiels
lorsque les sources elles-mêmes le sont. Rien dans cet audit ne permet de
qualifier automatiquement chaque contenu ancien de correct, complet ou humain.

## Vérification

Les tests s'exécutent contre PostgreSQL dans `test_jibiki`. Les tests ciblés
des importeurs et de l'API couvrent :

- conservation des identifiants personnels et de l'accent ;
- codes DTD, héritage des parties du discours, glosses longues et restrictions ;
- rafraîchissement d'une seule langue et retrait des anciens enfants ;
- annulation complète en cas d'erreur après un premier lot ;
- variantes de noms et provenance complémentaire de kanji ;
- numéros de sens différents entre le fichier anglais et le multilingue ;
- rejet d'une correspondance d'exemple incertaine et exclusion des sous-chaînes ;
- répétition sans doublons des imports XML et Tanaka ;
- identification des langues de secours ;
- validation de l'empreinte et portée exacte de la correction de provenance ;
- alias de démonstration sans déplacement des cartes et refus d'homographes ambigus.
- conservation des accents multiples, respect des restrictions d'écriture,
  refus d'une attribution JLPT sur lecture contradictoire ou homographe ambigu.
- conservation des positions malgré les anomalies XML, statut des anciennes
  entrées et exclusions de recherche sans exclure les mots dont la clé JSON
  `source_status` est absente.

Vingt-deux tests ciblés couvrent ces corrections. Neuf tests dictionnaire
existants ont également passé lors de la vérification précédente. Le contrôle
`makemigrations --check --dry-run` ne détecte aucun écart de schéma.

Les migrations ajoutées pour ce lot sont `0010_source_metadata_and_lossless_text`,
`0011_explicit_example_sense_links` et `0013_word_canonical_alias`.
`0012_kana_word_examples` appartient au lot complémentaire consacré aux kana.

## Vérification des performances sur le catalogue complet

Le SQL PostgreSQL de Django utilise `UPPER(text)` pour les recherches sans
distinction de casse. Les anciens index trigrammes portaient uniquement sur
`text`, ce qui laissait des parcours du catalogue complet. La migration
`0015_search_upper_indexes` ajoute des index fonctionnels compatibles, créés
sans bloquer les écritures. Un `ANALYZE` a actualisé les statistiques.

La recherche s'arrête après un niveau de pertinence lorsqu'il fournit déjà
toute la page. L'ordre exact, infinitif anglais exact, préfixe, sous-chaîne
reste le même. La recherche de noms borne séparément les identifiants trouvés
par écriture/lecture et par traduction, puis charge leur union. Elle évite ainsi
la jointure des 743 631 noms et 754 141 traductions suivie d'un `DISTINCT` sur
leurs métadonnées. Le secours anglais reste disponible en français.

Mesures HTTP locales observées après réchauffement du cache :

| Requête | Avant | Après |
| --- | ---: | ---: |
| eau, français | 3 869 ms | 129 ms |
| mizu | 635 ms | 92 ms |
| water | 590 ms | 98 ms |
| 𠮷 | 1 160 ms | 868 ms |

Une recherche de sous-chaîne réduite à un seul caractère reste moins sélective
pour un index de trigrammes. Ses résultats n'ont pas été amputés pour masquer
ce coût. Les mesures et plans `EXPLAIN ANALYZE` figurent dans
`var/audit/search-performance-before.json` et `search-performance-after.json`.
Ce sont des observations sur cette machine, pas une garantie de latence.

Après ce lot, 54 tests ciblés du dictionnaire sont passés. Les quatre tests
de limitation des requêtes et de recherche des noms passent également après
le dernier ajout du secours anglais.
