# Connaissances utiles pour jibiki

> Cette note contient la première synthèse opérationnelle. L'analyse élargie aux
> vidéos onboarding et streak, les arbitrages éthiques sur le booster et le plan
> de priorités se trouvent dans
> [`ANALYSIS_AND_PLAN.md`](ANALYSIS_AND_PLAN.md).

## Décision en bref

Les deux vidéos convergent sur une idée utile : la qualité perçue vient moins de
l'accumulation de fonctionnalités que de la clarté de chaque étape, du feedback
immédiat et de la confiance créée par les détails. Pour jibiki, cela justifie de
polir la boucle **chercher → comprendre → ajouter → réviser → constater son
progrès**, sans copier la gamification bruyante de Duolingo.

La vidéo sur les paywalls ne justifie pas à elle seule de passer à l'abonnement.
Le projet est actuellement conçu comme un achat unique et le choix du modèle
économique reste ouvert. Ses conseils doivent rester conditionnels à une future
décision freemium.

## Priorités recommandées

| Priorité | Application dans jibiki | Pourquoi |
|---|---|---|
| P0 | Rendre l'ajout d'un mot à l'étude immédiatement perceptible : changement d'état local, légère haptique, confirmation courte et réversible. | C'est la transition centrale entre dictionnaire et mémorisation. Le feedback doit confirmer l'action sans interrompre la lecture. |
| P0 | Terminer une session par un bilan concret : cartes renforcées, nouvelles cartes vues, prochaine révision estimée et action « Continuer ». | Donne une sensation de progression réelle sans confettis, score arbitraire ni limite artificielle quotidienne. |
| P1 | Montrer la progression comme une compétence acquise, pas comme une simple série : caractères consolidés, lectures rappelées, rétention estimée. | Une série mesure l'assiduité ; elle ne prouve pas l'apprentissage. Le produit promet de retenir le japonais. |
| P1 | Faire vivre la valeur pendant l'onboarding avec un mini exemple chercher/décomposer/mémoriser, puis demander les préférences. | Une démonstration réduit l'abstraction des choix de mode et de langue et améliore la première impression. |
| P1 | Auditer les attentes et transitions lors des chargements, synchronisations, téléchargements de packs et animations de tracé. | Dans un produit complexe ou hors ligne, un état d'attente soigné est un signal de fiabilité. |
| P2 | Si un freemium est retenu, présenter Premium uniquement après un moment de valeur ou depuis une action premium explicite. | Le paywall devient l'étape naturelle d'un parcours au lieu d'un mur placé devant le dictionnaire. |

## Ce qui existe déjà et doit être conservé

Le code actuel applique déjà une bonne partie des conseils de la première vidéo :

- `study_feedback.dart` fournit un feedback succès/erreur bref, cohérent et non
  bloquant ;
- `swipe_card.dart`, les exercices et le studio utilisent des retours haptiques
  liés à une action précise ;
- `stroke_order_view.dart` transforme une donnée complexe en interaction
  compréhensible ;
- `app_theme.dart` centralise le mouvement et respecte la réduction des
  animations ;
- l'identité reste chaleureuse et sobre, conformément à `PRODUCT.md`, sans
  mascotte envahissante ni récompenses enfantines.

Il faut étendre ce langage aux transitions encore purement fonctionnelles plutôt
que créer une nouvelle couche de gamification.

## Enseignements de la vidéo sur le design émotionnel

### 1. Le feedback doit être instantané et proportionné

La vidéo recommande des micro-interactions pour les comportements répétés
(vers 04:11), de petites célébrations et des animations de progression
(vers 04:55). Dans jibiki :

- un ajout à l'étude peut faire évoluer le bouton vers « Ajouté » et proposer
  « Annuler », avec une impulsion haptique légère ;
- une bonne réponse peut rester un signal bref ; la vraie récompense est le
  progrès expliqué en fin de session ;
- une erreur doit montrer la correction et la prochaine action, pas punir ;
- toute animation décorative doit disparaître sous `reduce motion`.

### 2. Le polish construit la confiance

Le principe « polish builds trust » apparaît vers 07:54. Il est particulièrement
pertinent pour les fonctionnalités qui peuvent sembler opaques : FSRS, synchro,
téléchargement hors ligne, contenu communautaire et modération. Afficher ce qui
se passe, ce qui a été enregistré et la date de dernière synchronisation aura
plus de valeur qu'une animation spectaculaire.

### 3. La première impression doit démontrer la promesse

L'onboarding actuel configure d'abord le mode et la langue. Une variante à tester
pourrait commencer par un exemple concret : rechercher `休む`, voir sa lecture et
sa décomposition, puis l'ajouter à une première mini-session. Les préférences
deviennent alors compréhensibles parce que l'utilisateur a déjà vu le produit.

### 4. Prudence sur les conclusions de la vidéo

Les exemples Duolingo, Phantom et Revolut associent croissance et investissement
design, mais la vidéo reconnaît elle-même d'autres causes possibles. Il faut les
traiter comme des études d'inspiration, pas comme une preuve qu'une animation
augmente mécaniquement la rétention.

## Enseignements conditionnels sur les paywalls

Ces éléments ne sont pertinents que si jibiki devient freemium ou propose un
abonnement. Le dictionnaire public sans compte doit rester hors de tout mur.

### Placement et parcours

- Penser le paywall comme un parcours, pas comme un écran isolé.
- Le placer après une valeur réellement vécue : première session terminée,
  demande de pack hors ligne avancé ou fonctionnalité communautaire premium.
- Adapter le message au contexte. Après une session, parler de continuité et de
  progression ; sur un pack, parler d'accès hors ligne. Éviter un paywall
  générique répété partout.
- Déplier l'information progressivement si elle est complexe, sans ajouter des
  écrans uniquement pour créer de la friction.

### Réduction du risque et transparence

- Si un essai existe, afficher une frise explicite : début, rappel, date et prix
  du premier débit, méthode d'annulation.
- Écrire clairement « sans engagement » ou « annulation à tout moment » seulement
  si le fonctionnement réel le garantit.
- Envoyer un rappel avant facturation avec consentement explicite.
- Rendre l'annulation aussi compréhensible que l'inscription.

### Offre et prix

- Limiter l'écran principal à deux choix maximum pour réduire la charge mentale ;
  mettre les options secondaires derrière « Voir tous les plans ».
- Ne pas supposer que l'annuel est toujours meilleur. Tester annuel, mensuel et
  achat à vie selon la rétention et les coûts réels de synchro, stockage et
  communauté.
- Une table de comparaison peut aider si les différences de droits sont nettes.
  Elle devient nuisible si elle invente une longue liste de limitations.
- Expliquer la valeur avec le résultat attendu — retenir davantage, apprendre
  hors ligne, synchroniser ses progrès — et non avec une liste de composants
  techniques.

### Mesure et expérimentation

La vidéo conclut qu'il n'existe pas de paywall universel et recommande des tests
radicalement différents. Pour jibiki, l'ordre de mesure devrait être :

1. activation : recherche → ajout d'une carte → première révision terminée ;
2. rétention : utilisateurs actifs d'apprentissage à J7 et J30 ;
3. apprentissage : cartes consolidées et rétention FSRS observée ;
4. monétisation : essai → paiement, rétention payante, remboursements et LTV ;
5. confiance : plaintes, annulations, suppressions de compte et retours sur la
   facturation.

Optimiser la conversion sans surveiller la rétention et la confiance peut faire
gagner un écran tout en abîmant le produit.

## Tactiques à ne pas importer

- fausse urgence, roue de réduction prédéterminée ou remise « gagnée » ;
- essai gratuit ambigu, option présélectionnée ou prix principal masqué ;
- paywall avant la recherche ou l'explication d'un mot ;
- parcours d'annulation volontairement plus long que l'abonnement ;
- streak guilt, limites quotidiennes artificielles, mascotte culpabilisante ;
- animations décoratives longues, non annulables ou incompatibles avec les
  réglages d'accessibilité ;
- copie aveugle d'un paywall concurrent sans hypothèse ni mesure.

## Points d'ancrage techniques

- Étendre `app/lib/views/widgets/add_to_study_bar.dart` pour le feedback P0.
- Utiliser `app/lib/views/study/session_view.dart` et
  `app/lib/views/study/study_feedback.dart` pour le bilan de session.
- Tester une démonstration guidée dans
  `app/lib/views/onboarding/onboarding_view.dart`.
- Conserver `app/lib/theme/app_theme.dart` comme source unique des durées,
  courbes, haptics et règles de réduction du mouvement.
- Si le modèle économique change, partir de
  `app/lib/core/entitlements.dart` et de l'équivalent serveur ; ne jamais faire
  reposer un droit d'accès uniquement sur l'état visuel du client.

## Sources primaires de cette note

- Sous-titres de *The Secret Behind Weirdly Addictive Apps* :
  [`Du2lkZ_cux8.en-orig.srt`](Du2lkZ_cux8.en-orig.srt)
- Sous-titres de *We Studied 2,995 Paywalls. Here's What Actually Converts.* :
  [`9ypqs_2fAl8.en-orig.srt`](9ypqs_2fAl8.en-orig.srt)
