# Intégrations et benchmark concurrentiel

Recherche mise à jour le 11 juillet 2026. Les notes personnelles de `TODO.md`
n'ont pas été consultées.

## Décision courte

Jibiki ne doit pas essayer de synchroniser deux planificateurs SRS carte par
carte. Il doit devenir le compagnon qui sait importer ce que la personne connaît,
enrichir son étude avec les mnémotechniques visuelles et l'écriture, puis exporter
des données portables. Une synchronisation bidirectionnelle des notes ou des
révisions n'est acceptable que si le service tiers expose une identité stable et
la sémantique complète de ses révisions.

Priorités proposées :

1. WaniKani en lecture seule : importer sujets, niveaux et états de maîtrise via
   son API v2 officielle. Proposer un seuil configurable, sans recopier ses
   intervalles dans FSRS.
2. Anki portable d'abord : conserver le TSV, ajouter `.apkg` et import avec GUID
   stable. AnkiConnect vient ensuite comme pont optionnel sur ordinateur.
3. jpdb en import/export : importer son historique JSON et les decks Anki; tester
   son API publique derrière un connecteur expérimental. Ne pas promettre un vrai
   miroir tant que les opérations d'état connues/inconnues ne sont pas complètes.
4. Yomitan : fournir un modèle de note et un bouton de création rapide vers Anki.
   C'est un flux à haute valeur car il relie lecture réelle, dictionnaire et SRS.
5. Bunpro, Renshuu, Migaku et Ringotan : proposer import de fichier ou lien profond
   avant une API non officielle. Ne jamais stocker les mots de passe ni scraper
   une session utilisateur.

## Premier lot livré

Le premier lot applique les trois garde-fous les plus immédiats :

- l'onboarding propose un placement neuf, kana connus ou caractères connus saisis
  manuellement, sans imposer un redémarrage à zéro;
- le connecteur WaniKani est en lecture seule, chiffre le jeton, produit un aperçu
  avec reconnus, ambigus, ignorés, cartes nouvelles et charge estimée, puis attend
  une action d'import explicite ou une annulation;
- les cartes acceptent maintenant une phrase source, une URL, un titre et un média,
  afin que les futures captures Yomitan, presse-papiers et jpdb restent
  contextuelles jusque dans les révisions hors ligne.

Le bouton WaniKani se trouve dans Réglages > Intégrations. Le rafraîchissement
automatique prépare un nouvel aperçu; il n'applique jamais silencieusement des
cartes. La capture presse-papiers est disponible depuis une fiche mot, et
`GET /api/v1/study/export/apkg` produit un paquet Anki portable. Le pont Yomitan
connecteurs, branchés sur ce même contrat de contexte.

## Faisabilité des connecteurs

| Outil | Surface disponible | Ce que Jibiki devrait faire | Risque |
| --- | --- | --- | --- |
| WaniKani | API REST v2 officielle avec jetons et ressources subjects, assignments, reviews et statistiques | Import incrémental en lecture seule, seuil Apprentice/Guru/Master/Burned, date et écart visibles | Faible si le jeton est chiffré et limité à la lecture |
| Anki | TSV, `.apkg`, `.colpkg`; AnkiConnect expose une API REST locale sur le poste | Import/export à identifiants stables; pont AnkiConnect facultatif sur desktop | Moyen : schémas de notes libres et SRS différent |
| jpdb | Import de base Anki, export JSON des révisions, API publique encore évolutive | Importer historique et vocabulaire; connecteur API marqué beta; journaliser les correspondances ambiguës | Moyen à élevé : couverture d'écriture incomplète |
| Yomitan | Création de notes via AnkiConnect et formats de dictionnaire configurables | Modèle Jibiki officiel, champs japonais/lecture/sens/source/mnémo/image | Faible, flux unidirectionnel explicite |
| Bunpro | Intégration WaniKani documentée, pas de contrat public général repéré | Import manuel si export disponible; ne pas scraper | Élevé pour une synchro directe |
| Ringotan | Synchronisation WaniKani, pas d'API générale | Se positionner comme source de progression, ou échanger une liste de kanji | Élevé sans accord produit |
| Renshuu / Migaku | Imports et exports propres au produit, API publique stable non confirmée | Adaptateurs fichier et demande de partenariat | Élevé sans contrat |

Références techniques : [API WaniKani](https://docs.api.wanikani.com/20170710/),
[AnkiConnect](https://github.com/amikey/anki-connect),
[formats d'import Anki](https://docs.ankiweb.net/importing/intro.html),
[formats d'export Anki](https://docs.ankiweb.net/exporting.html),
[changelog jpdb](https://jpdb.io/changelog),
[intégration WaniKani de Bunpro](https://bunpro.jp/support/account/wanikani-integration-explained),
[intégration Ringotan](https://community.wanikani.com/t/ringotan-now-supports-wanikani-api/64584).

## Ce que les utilisateurs paient réellement

Les produits gagnants ne vendent pas seulement du contenu. Ils vendent la
réduction de friction et une routine crédible.

| Produit | Moteur d'achat ou de fidélité | Frustration dominante | Leçon pour Jibiki |
| --- | --- | --- | --- |
| WaniKani | Parcours radical, kanji, vocabulaire prêt à l'emploi; mnémotechniques; sentiment de progression; aucune configuration | Rythme verrouillé, démarrage imposé à zéro, faible personnalisation, coût, vocabulaire parfois peu utile et manque de contexte | Garder un parcours guidé mais autoriser placement, saut, remise à niveau et rythme libre |
| jpdb | Decks issus de médias, couverture lexicale, cartes prêtes, phrases i+1, planification plus légère qu'Anki | Analyses erronées, variantes/redondances, grammaire prise pour du vocabulaire, portabilité et API encore partielles | Relier chaque carte à une source réelle et rendre toute analyse corrigeable |
| Anki | Puissance, gratuité sur desktop, énorme écosystème, contrôle total et pérennité des données | Interface et configuration intimidantes, création de cartes, dette de révisions, qualité variable des decks | Offrir les bons réglages par défaut et exporter sans enfermer l'utilisateur |
| Bunpro | Explications profondes, parcours JLPT/textbooks, pratique grammaticale structurée, vie entière appréciée | Réponses parfois trop strictes, mémorisation du trou plutôt que compréhension, intégration WaniKani pouvant créer des centaines de révisions | Prévisualiser tout import, accepter les synonymes et toujours montrer le contexte |
| Renshuu | Couverture très large, personnalisation, communauté et valeur d'abonnement | Densité de l'interface, nombreux réglages, parcours moins lisible et qualité inégale selon le module | Ne pas exposer toute la puissance dès le premier écran |
| Migaku | Gain de temps lors du mining depuis YouTube/Netflix, cours débutant, création de cartes sans casser l'immersion | Prix élevé, alternatives gratuites, sous-titres automatiques fragiles, export et finition parfois décevants | La capture en un geste vaut de l'argent, mais doit rester portable et fiable |
| Ringotan | Écriture réellement reconnue, SRS, ordre WaniKani/textbooks, usage stylet et réglages pratiques | Écart de vocabulaire avec WaniKani, intégrations limitées et quelques problèmes de plateforme | Le dessin doit compléter un parcours existant sans imposer un second backlog |
| Memrise historique  | Mnémotechniques communautaires personnelles, contenu humain et rappel social | Suppression des mems et perte de confiance lorsque le produit a retiré la fonction centrale | Les contributions doivent être exportables, versionnées et jamais supprimées sans solution de sortie |

Les retours qui étayent cette synthèse incluent les discussions récentes sur
[WaniKani](https://www.reddit.com/r/LearnJapanese/comments/1nl3otc/for_those_living_in_japan_is_wanikani_worth_it/),
[jpdb](https://www.reddit.com/r/LearnJapanese/comments/1biyipl/switching_from_anki_to_jpdbio_has_drastically/),
[Anki](https://www.reddit.com/r/LearnJapanese/comments/17r84yr/am_i_using_anki_wrong_i_always_get_frustrated_so/),
[Bunpro](https://www.reddit.com/r/LearnJapanese/comments/1oa2g9l/any_tips_for_improving_what_ive_learned_on_bunpro/)
et [Migaku](https://www.reddit.com/r/LearnJapanese/comments/1imwsgn/is_migaku_worth_the_money/).
Ce sont des témoignages, pas une mesure représentative; les motifs récurrents
sont plus utiles que les notes individuelles.

## Contrat de synchronisation recommandé

Chaque connecteur partage le même modèle : `provider`, `external_account_id`,
jeton chiffré, capacités déclarées, curseur de dernière lecture, dernière réussite,
dernier écart et erreur non secrète. Une table de correspondance conserve
`external_item_id`, `jibiki_subject_id`, la confiance et la décision manuelle.

Avant le premier import, afficher un aperçu : éléments reconnus, ambigus, ignorés,
nouvelles cartes et impact estimé sur la file. Un import ne crée jamais de
révisions échues par surprise. En conflit, le choix porte sur des champs précis,
pas sur un bouton global qui remplace silencieusement tout le compte.

Les jetons doivent être révocables, chiffrés au repos, absents des journaux et
restreints aux permissions nécessaires. Le connecteur affiche toujours sa dernière
synchronisation, son retard et la prochaine action possible.
