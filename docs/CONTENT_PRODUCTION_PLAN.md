# Consolidation ponctuelle des données Jibiki

Date : 29 septembre 2026. Ce plan remplace la proposition du 23 septembre. Le besoin est de traiter le corpus déjà extrait, maintenant. Le modèle est décrit dans [CONTENT_DATA_MODEL.md](CONTENT_DATA_MODEL.md).

## 1. Deux résultats distincts

**Dictionnaire Jibiki :** agréger les données existantes en fiches riches, cohérentes et rédigées dans le style de l'application, en anglais, français et néerlandais. Les agents participent à la synthèse sémantique des sources, pas seulement à la traduction.

**Banque mnémotechnique :** réunir les idées existantes et les propositions nouvelles, par cible et par langue. Les phrases et dessins forment des aides pédagogiques personnelles ou communautaires. L'utilisateur valide le set officiel avant la génération d'images.

Le dictionnaire peut avancer sans attendre la validation des mnémotechniques. Une traduction française correcte du sens ne prouve pas qu'une histoire française aide à le retenir.

## 2. Moyens proportionnés au chantier

Utiliser les extractions et parseurs existants, quelques scripts locaux, des fichiers JSONL et des lots confiés directement aux agents. Un simple dossier de travail contient les résultats acceptés, les cas à revoir et l'avancement. On peut interrompre et reprendre le traitement sans recommencer les lots terminés.

Il n'y a pas besoin d'ajouter un moteur de tâches à l'application, un service de traduction, une infrastructure de publication ou une hiérarchie de révisions éditoriales. Les fichiers sources sont conservés ; Git et une sauvegarde avant import suffisent pour suivre cette opération.

Les protections utiles restent simples : identités existantes préservées, références vers les sources, validation du format et import limité aux champs concernés.

### Inclure ce qui est déjà encodé dans l'application

Vérification du code le 29 septembre : le patrimoine à consolider ne se limite pas aux scrapes. Il comprend aussi :

| Emplacement actuel | Contenu à reprendre |
| --- | --- |
| `server/dictionary/seed_data.py` et `seed_strokes.py` | Données de démonstration, catalogue kana, origines, usages, exemples et tracés ; rapprocher des entrées du dictionnaire, sans recréer les doublons |
| `app/assets/packs/base.db.gz` | Contenu effectivement embarqué ; comparer aux sources et préserver les enrichissements propres avant de reconstruire le pack |
| `app/assets/data/kana_strokes.json` et `app/lib/data/kana_strokes.dart` | Tracés kana et règles de composition des yōon ; garder les relations entre formes et la géométrie utile |
| `app/lib/views/reference/reference_data.dart` | Fiches pédagogiques de grammaire et de référence encodées en EN/FR ; extraire leur contenu dans des fiches localisables EN/FR/NL |
| `app/assets/data/collection_sets.json` | Textes culturels, vocabulaire, lectures et références d'images ; relier le vocabulaire au dictionnaire, conserver les textes culturels comme tels |
| `server/content_sources/mnemonics/` | Histoires et briefs déjà présents, à normaliser avec les propositions issues des sources |

Les règles d'affichage, raretés de cartes et libellés de boutons restent dans leur domaine applicatif. Les textes qui enseignent une connaissance rejoignent le contenu consolidé. API et packs deviennent des représentations de ce même contenu ; les anciennes listes de définitions dans le code ne doivent pas rester des copies éditées indépendamment.

## 3. Travail sur le dictionnaire

### A. Réunir les données d'une même entrée

Le script rassemble, pour chaque kana, kanji, mot, composant ou autre entité :

- les données du dictionnaire actuel ;
- les enregistrements correspondants des extractions ;
- les sens, lectures, restrictions, exemples, usages, composants, prononciations, traits et autres informations disponibles ;
- les références des sources qui ont fourni ces informations.

Les identifiants source sont prioritaires. Pour les mots, l'écriture seule ne suffit pas : tenir compte de la lecture et des restrictions. Une correspondance incertaine va dans le fichier des cas à revoir.

Les extractions structurées sont privilégiées. Les PDF, images et notes utiles sont intégrés par extraction ou transcription ponctuelle avec leur page ou fichier d'origine. Les originaux restent conservés.

### B. Faire la synthèse avec les agents

L'agent reçoit toutes les informations pertinentes pour une entrée ou un petit groupe de sens. Il doit :

1. Identifier les doublons et les définitions équivalentes.
2. Regrouper les formulations qui décrivent réellement le même sens.
3. Garder séparés les sens, usages et restrictions différents.
4. Combiner les détails complémentaires en une fiche plus complète.
5. Rédiger les définitions et explications anglaises dans le style Jibiki.
6. Associer les exemples aux bons sens, sans changer leur japonais.
7. Signaler les contradictions et ce qu'il ne peut pas trancher.

La sortie suit le modèle commun. Les sources ne sont pas simplement concaténées. L'agent peut organiser et reformuler les connaissances, mais ne doit pas inventer une information pour remplir une case vide.

Chaque information utile de l'entrée source doit soit apparaître dans le résultat, soit être explicitement signalée comme doublon, incertaine ou non retenue. Ce petit bilan aide à détecter une synthèse trop simplificatrice.

Les données japonaises déjà fiables et structurées sont recopiées par code. Les passages nécessitant une comparaison de sens ou une réécriture passent par les agents. Les fiches très simples peuvent être produites directement à partir de leurs champs existants.

### C. Décliner en français et néerlandais

Une fois les sens regroupés, traduire leur formulation et les explications en FR/NL. Donner à l'agent le japonais, le contexte, les exemples et les traductions natives déjà disponibles, en plus de la synthèse anglaise.

L'identifiant du sens reste commun aux trois langues. Les traductions existantes utiles sont réemployées ou harmonisées. Si leur découpage diffère, l'agent propose le rattachement approprié au lieu de les associer selon leur rang dans une liste.

La voix commune est claire, compacte et précise. Les textes restent naturels dans chaque langue. Une définition, une explication et une note d'usage n'ont pas besoin du même ton ni de la même longueur.

### D. Contrôler les résultats

Le script vérifie les clés, références, langues, lectures, champs obligatoires et doublons. Une relecture agentique compare les synthèses aux données d'entrée, en priorité sur les fusions de sens, les mots polysémiques et les contradictions.

Au départ, examiner un petit lot représentatif EN/FR/NL pour ajuster le format et le ton. Puis traiter le reste du corpus par lots. Les exceptions restent à part : une entrée difficile ne doit pas empêcher les autres d'avancer.

Pas de comité de plusieurs agents sur chaque champ. On réserve la relecture coûteuse aux décisions sémantiques et aux alertes, avec un échantillonnage des cas simples.

### E. Importer dans Jibiki

Un script d'import ponctuel transforme les fichiers acceptés vers les modèles Django existants. Ajouter seulement les champs ou relations réellement nécessaires pour conserver les enrichissements utiles.

Faire d'abord un essai avec un bilan des changements, puis sauvegarder et importer. Ne pas supprimer globalement les gloses pour installer les nouveaux textes. Préserver les identifiants, les historiques d'apprentissage et les contributions.

L'import ciblé doit être relançable sans créer de doublons. Reconfigurer les commandes d'import existantes qui pourraient écraser ces contenus. Reconstruire ensuite les packs hors ligne déjà utilisés par l'application et contrôler quelques fiches dans les trois langues.

## 4. Travail sur les mnémotechniques

### A. Normaliser les idées déjà présentes

Réunir les seeds, les histoires extraites, les notes, les transcriptions et les références visuelles dans un format commun. Pour chacune, conserver :

- le caractère, le mot, le sens ou la lecture visés ;
- la langue dans laquelle le mécanisme fonctionne ;
- la phrase ou histoire disponible ;
- le mot d'ancrage et le son qu'il cherche à rappeler, lorsqu'ils existent ;
- le rapport à la forme ou au sens ;
- l'idée de dessin et les références visuelles disponibles ;
- l'origine et l'état de validation.

Une histoire peut avoir un bon mécanisme visuel sans ancre sonore. Une image peut exister sans phrase exploitable. Les champs absents restent vides. L'agent peut proposer leur interprétation, en la distinguant de ce qui était explicitement présent.

Garder plusieurs idées concurrentes pour la même cible. Deux scènes différentes ne doivent pas être fusionnées sous prétexte qu'elles concernent le même caractère.

Les références tierces restent attribuées et distinguées des textes destinés à la publication. Une reformulation n'efface pas leur origine ni les conditions de réutilisation.

### B. Préparer une sélection que l'utilisateur peut juger

Pour chaque cible et langue, présenter les bonnes idées existantes, puis des propositions nouvelles lorsque cela manque. Une présentation courte suffit :

| Cible | Langue | Phrase proposée | Pourquoi elle fonctionne | Idée de dessin | Origine | Décision |
| --- | --- | --- | --- | --- | --- | --- |
| か | FR | À concevoir | Début de « carapace » pour rappeler ka ; relation graphique à vérifier | Tortue et carapace intégrées à la forme | Idée de l'utilisateur | À valider |

Proposer une ou deux options pertinentes, plutôt qu'une longue liste peu travaillée. L'utilisateur peut accepter, rejeter ou demander une modification. Les agents aident à préparer et corriger ; ils ne remplacent pas cette décision pour le set officiel.

Commencer par les kana. Définir ensuite avec l'utilisateur le premier ensemble de kanji. Les mnémotechniques de mots utilisent le même format quand elles sont utiles.

### C. Générer les images plus tard

Pour une proposition acceptée, compléter sa description visuelle et ses contraintes de forme. Cet objet suffit comme passage de relais à l'agent chargé des images. Reprendre les expériences de verrouillage du glyphe déjà présentes dans le projet.

Ajouter ensuite l'image retenue à la même mnémotechnique. Conserver phrase, langue, ancre et dessin ensemble. Une image ne sert à plusieurs langues que si leurs associations fonctionnent avec elle.

Pas de génération avant validation de l'idée. Pas de remplacement périodique automatique du dessin appris.

## 5. Communauté, packs et présence dans le produit

Conserver le système communautaire existant : auteur, contributions, votes, choix personnels et packs. Un pack standard rassemble la sélection officielle de chaque langue. L'utilisateur doit bénéficier de cette sélection dès le départ, sans devoir chercher et installer un pack pour découvrir la fonctionnalité.

Une proposition communautaire et une mnémotechnique officielle partagent le même contenu de base. Elles se distinguent par leur auteur et leur appartenance à la sélection officielle, pas par deux modèles pédagogiques entièrement différents.

Sur les fiches kana, kanji et mots, placer le dessin et un indice court près de la forme, de la lecture et du sens. Permettre d'ouvrir l'histoire, de choisir une autre proposition ou de contribuer depuis ce bloc.

Pendant l'apprentissage initial, montrer l'association directement. Pendant une question de révision, laisser l'indice à la demande, puis montrer l'explication après la réponse. Respecter la langue choisie : une histoire anglaise ne remplit pas silencieusement une absence française.

Ce travail d'interface vient après la constitution d'un petit set exploitable. Mobile, tablette et hors ligne sont traités ensemble au moment de cette modification.

### Changements précis identifiés dans le code actuel

La fiche kana place `_FeaturedMnemonic` après les exemples et le guide d'écriture sur mobile ; sur tablette, elle arrive après plusieurs sections complémentaires. Surtout, ce composant affiche la phrase et l'auteur, mais **pas l'image**, même si elle est disponible. Il choisit `vm.items.first`, sans résolution explicite d'un choix personnel ou du défaut officiel.

La fiche kanji place `MnemonicPanel` après les lectures, les composants et l'origine. La fiche mot n'intègre pas ce panneau. Le carrousel d'apprentissage cherche déjà une proposition avec image, mais sa branche d'affichage utilise l'URL ; elle devra aussi prendre en charge les octets embarqués hors ligne.

Le changement visé est un bloc compact commun près du haut de la fiche : dessin disponible, phrase et accès direct à « Choisir une autre » et « Ajouter la mienne ». La galerie complète reste un écran secondaire. Sur tablette, le bloc peut accompagner le caractère dans une colonne voisine ; sur mobile, il le suit immédiatement. Les aides à une lecture précise restent associées à cette lecture.

La résolution doit être la même dans la fiche et dans l'apprentissage : choix personnel dans la langue demandée, puis sélection du pack adopté, puis défaut du pack standard de cette langue. Conserver les choix existants côté serveur et les raccorder au client ; enregistrer un favori n'est pas la même action que choisir la mnémotechnique utilisée pour apprendre. Les votes ne doivent pas changer implicitement une association déjà choisie.

Le pack standard doit être disponible sans détour, y compris hors ligne. Actuellement, le dépôt de mnémotechniques ne consulte le pack qu'après une erreur réseau. L'accès au défaut local doit pouvoir fonctionner directement ; la galerie communautaire peut ensuite compléter le contenu disponible. Une réponse réseau vide et un échec réseau sont deux cas à traiter explicitement.

## 6. Ordre concret

1. Arrêter les deux formats simples proposés dans [le modèle de données](CONTENT_DATA_MODEL.md).
2. Produire un petit lot réel à partir des extractions pour vérifier la richesse des fiches et le style EN/FR/NL.
3. Consolider et traduire les données statiques par lots, avec les agents.
4. En parallèle, normaliser les mnémotechniques existantes et préparer la sélection à valider.
5. Importer les fiches acceptées, puis les mnémotechniques validées dans le pack standard.
6. Générer les images dans le chantier dédié et rendre le bloc mnémotechnique directement visible.

La couverture finale du dictionnaire vise le corpus existant, pas seulement un mini-catalogue. Le premier lot sert à éviter de répéter une mauvaise décision sur tout le stock.

Les économies de tokens viennent du préregroupement par scripts, des petits contextes pertinents, de la réutilisation des traductions existantes et de modèles légers sur les opérations simples. Les synthèses ambiguës et les créations mnémotechniques reçoivent davantage d'attention.

## 7. Corrections après feedback, à la demande

Le seul besoin durable du dictionnaire est de pouvoir corriger une connaissance sans oublier ses formulations dans les autres langues. L'identifiant commun du sens ou de l'explication suffit à retrouver EN/FR/NL. L'anglais est une formulation de référence pratique, pas l'identité de la connaissance.

| Nature du retour | Intervention ponctuelle |
| --- | --- |
| Traduction, orthographe ou style incorrect dans une langue | Corriger cette formulation ; contrôler que son sens reste fidèle. Les autres langues ne sont pas retraduites sans raison |
| Définition, lecture, restriction ou autre fait incorrect | Corriger l'information commune, revoir toutes les formulations concernées et les exemples ou aides directement affectés |
| Découpage de sens incorrect | Corriger les sens et leurs rattachements, puis réaligner les formulations et exemples dans chaque langue |
| Association mnémotechnique peu utile | Proposer une correction ou une alternative dans sa langue ; obtenir la décision de l'utilisateur pour le set standard ; réexaminer le dessin seulement si son mécanisme change |

Un retour peut être traité ici, manuellement ou avec un agent sur les seules entrées concernées. Un petit fichier de travail peut noter la cible, la raison et les langues restant à vérifier pendant la correction. Aucun déclencheur ni traitement automatique permanent n'est requis.

Avant de diffuser une correction de fond, vérifier ensemble les langues concernées, appliquer la modification ciblée et reconstruire les packs correspondants avec les outils existants. Conserver le changement dans Git et la sauvegarde habituelle. L'enrichissement du pack mnémotechnique standard suit la même logique manuelle : sélection, validation, ajout des éléments retenus.

