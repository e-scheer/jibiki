# Audit des données client et des packs

Audit repris le 9 septembre 2026. Ce document décrit les garanties techniques vérifiées, pas une validation linguistique humaine de chaque entrée. Les volumes du corpus reconstruit et sa provenance sont consignés dans le rapport global.

## Problèmes corrigés

* Plusieurs appels simultanés à `ensureReady` pouvaient installer et ouvrir le même pack plusieurs fois. L'initialisation est désormais partagée. Les téléchargements et suppressions sont sérialisés, les demandes identiques de téléchargement sont regroupées.
* Les fichiers de packs utilisent désormais leur empreinte comme nom immuable. Un ancien lecteur Windows conserve son fichier ouvert pendant une mise à jour. La topologie SQLite et le registre retrouvent les packs précédents si une installation ou une suppression échoue.
* Le registre conserve les dépendances de version. Une suppression de core encore requis est refusée même après redémarrage sans manifeste réseau. Les packs incompatibles ne sont pas attachés. Le bundle peut servir de secours de traduction uniquement quand sa version et son schéma correspondent au core.
* Le cache du dictionnaire dépend maintenant de la révision des packs et des langues choisies. Une réponse ancienne ne remplit pas le cache d'une nouvelle révision. La langue d'interface pilote les explications, celle d'apprentissage les définitions.
* Une chaîne latine reconnue comme romaji reste recherchée dans les définitions. Les caractères `%`, `_` et `\` sont échappés au lieu d'élargir involontairement la recherche SQL. Les résultats de packs superposés sont dédoublonnés.
* Les listes paginées ont un ordre stable avec identifiant comme départage. Un kanji absent du petit bundle ne fait plus échouer toute la fiche d'un mot. Les mots liés à un kanji transportent leurs définitions.
* Les explications, particules et exemples de kana sélectionnent une langue explicitement. Le secours anglais conserve son étiquette de langue. Les sens spécifiques au français de JMdict restent visibles même si le nombre de sens anglais diffère. Une différence de segmentation ne prouve pas qu'une traduction soit incomplète.
* Les anciennes entrées de démonstration réconciliées deviennent des alias de consultation. Les recherches et listes ne les dupliquent plus, mais leurs identifiants restent utilisables par les cartes et historiques existants. La fiche rend le contenu canonique en conservant l'identifiant demandé et un `canonical_id` explicite. Le bundle inclut aussi les cibles canoniques nécessaires, même si elles ne satisfont pas directement son filtre de fréquence.
* Les entrées historiques absentes de la source courante et les anciennes fusions de démonstration restent consultables pour les cartes sauvegardées, avec une notice. Elles sont exclues de la découverte de nouvelles entrées. Les filtres JSON conservent bien les lignes sans statut particulier.
* La recherche par radical accepte la décomposition KRAD et le radical explicitement déclaré par Kanji alive, sans substituer une source à l'autre. Les métadonnées et crédits du nouveau catalogue sont transportés dans les packs.
* Les fiches mobiles et tablettes affichent tous les sens et exemples reçus. La tablette ne coupe plus une phrase japonaise à vingt caractères. Les notes, domaines et restrictions d'écriture ou de lecture restent accessibles. Les traductions sont sélectionnées selon leur langue et les secours sont étiquetés. Un accent de hauteur trouvé sur une autre lecture n'est plus attribué à la lecture principale.
* Les explications d'origine d'un kanji ne revendiquent plus systématiquement Wiktionary : une URL documentée de cette source est requise pour cette attribution. Sinon, l'interface indique que la source n'est pas documentée. La langue, les badges de formation et l'explication du composant phonétique sont correctement exposés en français et en anglais.

## Conservation des sources

Le format reste le schéma SQLite 2 avec des ajouts de colonnes et tables. Les lecteurs existants continuent de lire les colonnes historiques. Le nouveau client accepte les anciens packs sans les ajouts.

Les objets XML bruts `metadata.raw` restent conservés intégralement dans PostgreSQL. Ils sont exclus des packs et du transport des fiches : le core ne doit pas embarquer indirectement toutes les traductions de toutes les langues à travers cette copie brute. Les restrictions, catégories et autres métadonnées structurées nécessaires à la consultation restent exportées.

| Entité | Informations préservées dans les nouveaux packs |
| --- | --- |
| Mot | Provenance et identifiants canoniques inchangés |
| Forme | Métadonnées de restrictions, priorités et informations source |
| Sens | Ordre, catégories, domaines, remarques, notes localisées et métadonnées source |
| Définition | Langue, texte sans réduction et métadonnées |
| Kanji et radical | Métadonnées et provenance, en plus des lectures et tracés existants |
| Nom propre | Métadonnées, provenance et traductions étiquetées par langue |
| Phrase | Identifiant source, provenance et traductions séparées |
| Association phrase/sens | Mot, sens, position du sens dans la source, occurrence et provenance |
| Exemple lexical de kana | Référence vers le mot canonique, lecture, ordre et provenance |
| Mnémonique | Provenance éditoriale, langue et état de publication conservés |

Les phrases sont rattachées à un mot par une assertion explicite de la source. La simple présence de caractères du mot dans une phrase ne suffit plus. Les anciens packs dépourvus de liens restent lisibles mais ne proposent plus de phrases arbitrairement associées. Les exemples EN et FR explicitement liés aux mots du bundle sont inclus dans celui-ci. Les packs de phrases complets conservent aussi leurs phrases sans lien, sans les attribuer artificiellement à une fiche.

Les exemples lexicaux de kana référencent les mots du dictionnaire canonique. Les définitions sont relues depuis ces mots, avec leur langue. Les liens dont le mot ne figure pas dans le petit bundle sont réservés au core complet.

La provenance ne devient jamais une preuve automatique de validation éditoriale. Le statut public d'un mnémonique n'est pas assimilé à une certification linguistique.

## Vérifications

* Tests Flutter ciblés : dictionnaire local, langues, modèles et gestion des packs. Ils couvrent notamment concurrence d'initialisation, ancien lecteur pendant une mise à jour, dépendances après redémarrage, cache après changement de langue ou de packs, données source additives, rapprochement des traductions d'une phrase, exclusion d'une phrase partageant seulement une sous-chaîne, résolution des anciens identifiants sans doublons et recherche selon les deux sources de radicaux.
* Tests de fiches à 390 et 1024 pixels : sixième sens, note française, restrictions, traduction française, secours anglais étiqueté, notice historique et deuxième exemple accessibles. La stratégie mnémotechnique suggérée ne porte plus une attribution documentaire ; une origine disponible garde sa langue et son texte complet. Les tests d'origine couvrent les deux tailles avec et sans provenance Wiktionary documentée.
* Analyse statique ciblée des fichiers client : aucune anomalie.
* 7 tests serveur d'export de packs : export canonique, intégrité SHA-256, manifeste, chemins et téléchargements, langues des mnémoniques, préservation de métadonnées structurées, exclusion du XML brut, liens explicites et inclusion des cibles d'alias dans le bundle. Les fixtures textuelles artificielles restent uniquement dans les tests.

La vérification finale a été répétée après reconstruction des assets du 9 septembre : **299 tests Flutter réussis**, analyse globale sans anomalie. Le test d'intégration des packs est ignoré par défaut dans cette suite et a été exécuté séparément avec succès sur les fichiers réels.

Le test opt-in `app/test/packs/production_pack_smoke_test.dart`, activé par `JIBIKI_PACK_SMOKE_DIR`, installe le bundle, le core, les locales EN/FR, les noms et les exemples EN dans un répertoire temporaire, sans ouvrir la base utilisateur. Il vérifie les empreintes et dépendances via le vrai PackManager, puis interroge le dictionnaire : 水 rend « eau » en français ; 東京 renvoie des noms ; les phrases liées, les exemples lexicaux de kana et les radicaux sont accessibles ; l'ancien identifiant 1 résout la cible 54698 sans perdre son identité.

La topologie réelle vérifiée contient 218 758 lignes de mots, 678 102 sens, 13 108 kanji, 208 kana, 260 radicaux et 214 liens lexicaux de kana. Les nombres de lignes comprennent les alias et enregistrements historiques préservés ; ils ne doivent pas être présentés comme autant d'entrées canoniques proposées à l'apprentissage.

Un ancien core déjà installé continue de définir la version active tant que ses mises à jour et celles de ses langues ne sont pas installées. Le 9 septembre, les six packs vérifiés ont été installés dans le profil desktop après sauvegarde. Les empreintes des fichiers de progression personnelle sont restées identiques pendant cette installation. La compilation Windows release a ensuite été lancée avec succès.
