export type Locale = 'fr' | 'en';

const fr = {
  localeName: 'Français',
  htmlLang: 'fr',
  ogLocale: 'fr_FR',
  routes: {
    home: '/fr/',
    privacy: '/fr/confidentialite/',
    terms: '/fr/conditions/',
    sources: '/fr/sources/',
  },
  meta: {
    homeTitle: 'jibiki | Dictionnaire japonais et mémoire durable',
    homeDescription:
      'Cherchez un mot japonais, comprenez ses kanji et retenez-le grâce à la répétition espacée et aux mnémotechniques dans votre langue.',
    privacyTitle: 'Confidentialité | jibiki',
    privacyDescription:
      'Comment jibiki protège les données locales, les comptes, les contributions et les mesures d’audience.',
    termsTitle: 'Conditions d’utilisation | jibiki',
    termsDescription:
      'Les règles d’utilisation de jibiki, du dictionnaire, de la mémorisation et des contributions communautaires.',
    sourcesTitle: 'Sources et licences | jibiki',
    sourcesDescription:
      'Les dictionnaires, tracés, algorithmes et fontes libres qui rendent jibiki possible.',
    notFoundTitle: 'Page introuvable | jibiki',
    notFoundDescription: 'La page demandée n’existe pas ou a changé d’adresse.',
    ogAlt: 'jibiki dans son univers NeoPop jaune, bleu, rose et vert',
  },
  common: {
    brandLabel: 'jibiki, accueil',
    skip: 'Aller au contenu',
    openApp: 'Ouvrir l’app',
    startWithoutAccount: 'Commencer sans compte',
    learnMore: 'Découvrir la méthode',
    backHome: 'Retour à l’accueil',
    language: 'Langue',
    navigation: 'Navigation principale',
    legalNavigation: 'Informations légales',
    externalLink: 'ouvre un nouveau site',
  },
  header: {
    features: 'Fonctionnalités',
    dictionary: 'Dictionnaire',
    method: 'Méthode',
    study: 'Étudier',
    tablet: 'Tablette',
    community: 'Communauté',
  },
  hero: {
    badge: 'Dictionnaire d’abord. Mémoire ensuite.',
    titleLead: 'Comprendre le japonais',
    titleAccent: 'maintenant.',
    titleTail: 'Le retenir pour de bon.',
    body:
      'Cherchez un mot, comprenez ses kanji, ajoutez-le à vos révisions. jibiki relie le dictionnaire et la mémorisation dans une seule app, à votre rythme.',
    note: 'Recherche immédiate. Mode hors ligne. Gratuit.',
    platformsLabel: 'Disponible sur',
    platforms: ['Android', 'iPhone', 'Web'],
    previewLabel: 'Aperçu du dictionnaire jibiki',
    due: 'à réviser',
    newCards: '+ 5 nouvelles',
    launch: 'Lancer la session',
    wordOfDay: 'Mot du jour',
    flowerViewing: 'Pique-nique sous les cerisiers en fleurs.',
  },
  dictionary: {
    kicker: 'Cherchez vraiment',
    title: 'Le dictionnaire est le point de départ.',
    body:
      'Écriture, lectures, sens, fréquence et exemples restent réunis. Chaque kanji mène à ses composants, chaque composant mène aux mots qui l’utilisent, et l’ordre des traits s’anime sous vos yeux. Une recherche peut rester une simple recherche ou devenir une carte à retenir.',
    searchLabel: 'Rechercher un mot, un kanji, un kana ou un sens',
    placeholder: 'Essayez 桜, さくら ou cerisier…',
    submit: 'Rechercher',
    examplesLabel: 'Exemples rapides',
    loading: 'Recherche en cours…',
    noResults: 'Aucun résultat. Essayez une autre écriture ou un autre sens.',
    unavailable:
      'La recherche en direct sera disponible au lancement. Les exemples restent interactifs.',
    error: 'La recherche n’a pas répondu. Les exemples restent disponibles.',
    resultCount: 'résultats',
    meaning: 'Sens',
    composition: 'Dans le kanji',
    openEntry: 'Voir dans l’app',
    addToStudy: 'Ajouter à ma mémoire',
    selectedResult: 'Résultat sélectionné',
    samples: [
      {
        key: 'sakura',
        query: '桜',
        glyph: '桜',
        reading: 'さくら',
        romaji: 'sakura',
        tags: ['Nom', 'JLPT N5', 'Fréquent'],
        meanings: ['cerisier', 'fleur de cerisier'],
        parts: [
          { glyph: '木', label: 'arbre' },
          { glyph: 'ツ', label: 'pétales' },
          { glyph: '女', label: 'femme' },
        ],
      },
      {
        key: 'nihongo',
        query: '日本語',
        glyph: '日本語',
        reading: 'にほんご',
        romaji: 'nihongo',
        tags: ['Nom', 'JLPT N5', 'Commun'],
        meanings: ['langue japonaise', 'japonais'],
        parts: [
          { glyph: '日', label: 'soleil' },
          { glyph: '本', label: 'origine' },
          { glyph: '語', label: 'langue' },
        ],
      },
      {
        key: 'kana-a',
        query: 'あ',
        glyph: 'あ',
        reading: 'a',
        romaji: 'hiragana',
        tags: ['Hiragana', 'Voyelle', 'Rangée A'],
        meanings: ['le son « a »', 'premier kana du gojūon'],
        parts: [
          { glyph: '1', label: 'trait haut' },
          { glyph: '2', label: 'vertical' },
          { glyph: '3', label: 'boucle' },
        ],
      },
    ],
  },
  memory: {
    kicker: 'Un seul flux',
    title: 'Du mot inconnu à la mémoire durable.',
    body:
      'jibiki relie la compréhension et la mémorisation dans le même geste, du premier contact avec un mot jusqu’à son dernier rappel.',
    steps: [
      {
        number: '1',
        title: 'Cherchez',
        body: 'Tapez du japonais, du rōmaji ou un sens dans votre langue.',
      },
      {
        number: '2',
        title: 'Comprenez',
        body: 'Explorez les lectures, composants, origines et mots en contexte.',
      },
      {
        number: '3',
        title: 'Retenez',
        body: 'Ajoutez seulement ce qui compte et laissez FSRS planifier le prochain rappel.',
      },
    ],
  },
  study: {
    kicker: 'Decks et modes de jeu',
    title: 'Une file de révision, quatre façons de la jouer.',
    body:
      'Prenez un deck prêt à l’emploi ou construisez le vôtre au fil des recherches. La même session se joue en cartes, en quiz, en paires ou à l’oreille, et vous changez de mode quand vous voulez.',
    decksLabel: 'Decks prêts à réviser',
    decks: ['Hiragana', 'Katakana', 'Kanji N5', 'Mots courants', 'Favoris', 'À retravailler'],
    modes: [
      {
        key: 'swipe',
        title: 'Cartes',
        body: 'Retournez la carte, puis balayez pour dire si vous la connaissiez.',
      },
      {
        key: 'quiz',
        title: 'Quiz',
        body: 'Choisissez le bon sens parmi quatre propositions.',
      },
      {
        key: 'match',
        title: 'Paires',
        body: 'Associez chaque caractère à son sens, deux tuiles à la fois.',
      },
      {
        key: 'listen',
        title: 'Écoute',
        body: 'Écoutez, puis reconstruisez la lecture avec les tuiles kana.',
      },
    ],
    directions:
      'Chaque mode se joue dans les deux sens : reconnaître le japonais, ou le retrouver depuis le sens.',
    demo: {
      cardGlyph: '勉強',
      cardReading: 'べんきょう',
      cardGloss: 'étude, travail',
      quizPrompt: '桜',
      quizOptions: ['cerisier', 'montagne', 'rivière', 'voiture'],
      pairs: [
        { glyph: '犬', label: 'chien', matched: true },
        { glyph: '山', label: 'montagne', matched: false },
      ],
      listenTiles: ['べ', 'ん', 'き', 'ょ', 'う'],
      listenPlaced: 3,
    },
  },
  mnemonic: {
    kicker: 'Mnémotechniques',
    title: 'Des histoires écrites pour votre langue.',
    body:
      'Le sens d’un kanji se retient avec une image, et une bonne image parle à toutes les langues. Sa lecture se retient avec un jeu de mots, et un jeu de mots appartient à sa langue. Prenez 本 : l’image raconte l’origine, puis chaque langue invente son propre calembour pour la lecture ホン.',
    glyph: '本',
    glyphReading: 'ホン',
    glyphMeaning: 'livre, origine',
    meaningCard: {
      label: 'Le sens, en image',
      scope: 'La même image pour toutes les langues',
      quote:
        'Un arbre (木) dont un trait (一) marque les racines : la racine, l’origine, le livre.',
      parts: [
        { glyph: '木', label: 'arbre' },
        { glyph: '一', label: 'trait' },
      ],
    },
    readingLabel: 'La lecture ホン, un jeu de mots par langue',
    readingCards: [
      {
        locale: 'fr',
        language: 'Français',
        quote: 'Quelle honte (ホン) de corner les pages d’un si beau livre.',
      },
      {
        locale: 'en',
        language: 'English',
        quote: 'Hone (ホン) your mind by reading a good book from cover to cover.',
      },
    ],
    community:
      'La communauté écrit, dessine et vote les meilleures versions dans chaque langue. Gardez vos favorites ou dessinez la vôtre. Et quand une langue attend encore sa bonne version, jibiki le dit clairement.',
  },
  review: {
    kicker: 'Répétition espacée',
    title: 'Le bon rappel, juste avant l’oubli.',
    body:
      'jibiki planifie chaque rappel avec FSRS, un algorithme moderne de répétition espacée : votre difficulté réelle décide de la prochaine date. Vous réglez votre rétention cible et le nombre de nouvelles cartes par session, et avec assez d’historique l’algorithme se cale sur votre propre mémoire.',
    progress: '7 sur 20',
    remaining: 'Encore 13. Vous gardez le rythme.',
    retained: 'RETENU',
    seen: 'Vu il y a 3 jours.',
    question: 'Vous l’aviez ?',
    reading: 'べんきょう',
    gloss: 'étude, travail',
    ratings: [
      { key: 'again', label: 'Encore', interval: '2 min' },
      { key: 'hard', label: 'Difficile', interval: '1 j' },
      { key: 'good', label: 'Bien', interval: '3 j' },
      { key: 'easy', label: 'Facile', interval: '7 j' },
    ],
  },
  tablet: {
    kicker: 'Téléphone et tablette',
    title: 'Sur tablette, un vrai espace de travail.',
    body:
      'Navigation en rail vertical, liste et détail côte à côte, matrices kana en pleine largeur. Sur téléphone, la même app reste compacte et utilisable d’une main.',
    mnemonicLabel: 'Mnémotechnique de la communauté',
    mnemonicQuote:
      'Pour 桜, imagine un cerisier qui sort son plus beau kimono rose dès que le printemps sonne à la porte.',
    search: 'Rechercher sakura',
    results: '7 résultats',
    listLabel: 'Résultats du dictionnaire',
    detailLabel: 'Détail de 桜',
    navItems: ['Dico', 'Kana', 'Réviser', 'Communauté', 'Profil'],
    resultItems: [
      { glyph: '桜', reading: 'さくら', gloss: 'cerisier' },
      { glyph: '咲く', reading: 'さく', gloss: 'fleurir' },
      { glyph: '桜色', reading: 'さくらいろ', gloss: 'rose sakura' },
      { glyph: '花見', reading: 'はなみ', gloss: 'pique-nique fleuri' },
    ],
    senses: 'Sens',
    example: '桜の花が咲いています。',
    translation: 'Les cerisiers sont en fleurs.',
  },
  trust: {
    kicker: 'Utile dès la première seconde',
    title: 'Ouvert, hors ligne, synchronisé.',
    body:
      'Le dictionnaire se consulte gratuitement, dès l’arrivée. Un compte gratuit synchronise votre progression entre appareils, et les packs de contenu gardent l’essentiel disponible hors connexion.',
    items: [
      {
        icon: '字',
        title: 'Données de référence solides',
        body: 'JMdict, KANJIDIC2, KanjiVG, Tatoeba : des sources ouvertes, créditées dans l’app.',
      },
      {
        icon: '⇣',
        title: 'Hors ligne',
        body: 'Téléchargez des packs de contenu et gardez dictionnaire et révisions sous la main, même sans réseau.',
      },
      {
        icon: '↺',
        title: 'Synchronisé par compte',
        body: 'Votre progression vous suit d’un appareil à l’autre, et vous validez la réconciliation avant toute fusion.',
      },
      {
        icon: '文',
        title: 'Pensé pour plusieurs langues',
        body: 'Interface, sens et mnémotechniques respectent leur langue d’origine.',
      },
    ],
    sourcesLink: 'Voir toutes les sources et licences',
  },
  finalCta: {
    title: 'Un mot à chercher ?',
    body: 'Téléchargez jibiki sur Android ou iPhone, ou ouvrez-le directement dans le navigateur.',
    platforms: ['Android', 'iPhone', 'Web'],
  },
  footer: {
    tagline: 'dictionnaire libre, mémoire durable',
    product: 'Produit',
    information: 'Informations',
    privacy: 'Confidentialité',
    terms: 'Conditions',
    sources: 'Sources et licences',
    consentSettings: 'Préférences analytics',
    copyright: 'jibiki. Construit pour comprendre et retenir le japonais.',
  },
  consent: {
    title: 'Vous décidez de ce qui est mesuré.',
    body:
      'Vous choisissez séparément les mesures d’audience et les diagnostics techniques. Le texte de vos recherches reste privé.',
    accept: 'Tout accepter',
    decline: 'Tout refuser',
    customize: 'Personnaliser',
    save: 'Enregistrer mes choix',
    analyticsTitle: 'Mesures d’audience',
    analyticsBody:
      'Autorise Google Analytics à mesurer les pages utiles et les passages vers l’app.',
    diagnosticsTitle: 'Diagnostics techniques',
    diagnosticsBody:
      'Autorise l’app à envoyer les erreurs, crashs et performances nécessaires aux corrections.',
    privacy: 'Lire la politique de confidentialité',
    label: 'Choix des mesures d’audience',
  },
  legal: {
    updatedLabel: 'Dernière mise à jour',
    updatedDate: '13 juillet 2026',
    privacy: {
      title: 'Confidentialité',
      intro:
        'jibiki est conçu pour fonctionner utilement sans compte. Cette page distingue les données nécessaires au service des mesures facultatives.',
      sections: [
        {
          title: 'Mode local et compte',
          paragraphs: [
            'En mode local, la progression, les préférences et l’historique nécessaires au produit restent sur l’appareil. La suppression des données du navigateur ou de l’application peut les effacer.',
            'Si vous créez un compte, jibiki traite les informations de connexion, les réglages de profil et les données de progression nécessaires à la synchronisation entre appareils.',
          ],
        },
        {
          title: 'Contributions communautaires',
          paragraphs: [
            'Une mnémotechnique, une image, un vote ou un signalement envoyé à la communauté est conservé avec les informations nécessaires à son affichage, sa modération et son attribution.',
            'Ne publiez pas de données personnelles dans une contribution destinée à être visible par d’autres utilisateurs.',
          ],
        },
        {
          title: 'Mesures d’audience facultatives',
          paragraphs: [
            'Le site ne charge Google Analytics qu’après un consentement explicite. Sans identifiant GA4 configuré, aucun composant Google Analytics n’est chargé.',
            'Les événements servent à mesurer les pages vues, les interactions avec les démonstrations et les passages vers l’app. Le contenu saisi dans une recherche n’est pas transmis comme paramètre analytics. Le cookie first-party jibiki_consent_v1 partage vos choix analytics et diagnostics entre jibiki.app et my.jibiki.app.',
          ],
        },
        {
          title: 'Vos choix',
          paragraphs: [
            'Vous pouvez refuser les mesures, modifier votre choix depuis le pied de page et utiliser le produit sans accepter les analytics.',
            'Pour une demande liée à vos données de compte, utilisez le formulaire de retour intégré à jibiki afin que la demande soit reliée au bon compte sans publier d’adresse personnelle sur ce site.',
          ],
        },
        {
          title: 'Sécurité et conservation',
          paragraphs: [
            'jibiki limite les données collectées à celles utiles au service, protège les échanges réseau en production et sépare les données publiques des données de compte.',
            'Les durées exactes dépendent de la catégorie de données, des obligations de sécurité et des demandes valides de suppression. Cette politique sera précisée avant l’ouverture publique des comptes.',
          ],
        },
      ],
    },
    terms: {
      title: 'Conditions d’utilisation',
      intro:
        'Ces conditions encadrent l’utilisation du dictionnaire, des fonctions de mémorisation et des espaces communautaires de jibiki.',
      sections: [
        {
          title: 'Utilisation du service',
          paragraphs: [
            'Vous pouvez utiliser les fonctions publiques du dictionnaire sans compte. Certaines fonctions de synchronisation et de contribution nécessitent un compte valide.',
            'Vous restez responsable de votre appareil, de vos identifiants et des contenus que vous choisissez de publier.',
          ],
        },
        {
          title: 'Contenu pédagogique',
          paragraphs: [
            'Les définitions, lectures, exemples et calendriers de révision sont des aides à l’apprentissage. Ils peuvent comporter des erreurs ou évoluer lorsque les sources sont mises à jour.',
            'jibiki ne garantit pas un résultat d’examen, un niveau JLPT ou une maîtrise particulière du japonais.',
          ],
        },
        {
          title: 'Contributions',
          paragraphs: [
            'Vous ne devez publier que du contenu que vous avez le droit de partager. Les contenus illégaux, trompeurs, offensants ou portant atteinte aux droits d’autrui peuvent être masqués ou modérés.',
            'En publiant, vous autorisez jibiki à afficher, adapter techniquement et distribuer la contribution dans les surfaces du produit. Les modalités définitives de licence seront présentées au moment de la contribution avant l’ouverture publique.',
          ],
        },
        {
          title: 'Disponibilité et évolution',
          paragraphs: [
            'Le service peut être interrompu pour maintenance, sécurité ou évolution. Les fonctions expérimentales peuvent changer avant leur publication stable.',
            'Les règles applicables à une fonction payante seront affichées avant tout achat. Cette page n’annonce aucun prix ni abonnement qui ne serait pas disponible dans le produit.',
          ],
        },
        {
          title: 'Respect des licences',
          paragraphs: [
            'Les données et tracés provenant de projets tiers restent soumis à leurs propres licences. La page Sources et licences en fournit la liste et les attributions.',
          ],
        },
      ],
    },
    sources: {
      title: 'Sources et licences',
      intro:
        'jibiki assemble des données linguistiques et des outils ouverts. Les attributions font partie du produit, pas d’une note cachée.',
      entries: [
        {
          name: 'EDRDG : JMdict, KANJIDIC2, KRADFILE et RADKFILE',
          license: 'Licence EDRDG',
          body: 'Mots, lectures, sens multilingues, kanji et décomposition en composants.',
          href: 'https://www.edrdg.org/edrdg/licence.html',
        },
        {
          name: 'KanjiVG',
          license: 'CC BY-SA 3.0',
          body: 'Tracés vectoriels utilisés pour montrer et animer l’ordre des traits.',
          href: 'https://kanjivg.tagaini.net/',
        },
        {
          name: 'Tatoeba',
          license: 'CC BY 2.0 FR lorsque les exemples sont utilisés',
          body: 'Phrases d’exemple et traductions liées à leurs auteurs et licences.',
          href: 'https://tatoeba.org/',
        },
        {
          name: 'FSRS',
          license: 'Algorithme ouvert',
          body: 'Planification de la répétition espacée selon la mémoire observée.',
          href: 'https://github.com/open-spaced-repetition/free-spaced-repetition-scheduler',
        },
        {
          name: 'Space Grotesk et Zen Kaku Gothic New',
          license: 'SIL Open Font License',
          body: 'Familles typographiques utilisées pour le latin et le japonais de la marque.',
          href: 'https://openfontlicense.org/',
        },
      ],
      notice:
        'Les contributions communautaires restent attribuées à leurs auteurs et suivent les droits présentés lors de leur publication.',
    },
  },
  notFound: {
    code: '404',
    title: 'Cette page s’est éclipsée.',
    body: 'Le lien a peut-être changé, mais le dictionnaire vous attend toujours.',
  },
} as const;

type DeepWiden<T> = T extends string
  ? string
  : T extends readonly (infer Item)[]
    ? readonly DeepWiden<Item>[]
    : T extends object
      ? { [Key in keyof T]: DeepWiden<T[Key]> }
      : T;

export type Messages = DeepWiden<typeof fr>;

const en: Messages = {
  localeName: 'English',
  htmlLang: 'en',
  ogLocale: 'en_US',
  routes: {
    home: '/en/',
    privacy: '/en/privacy/',
    terms: '/en/terms/',
    sources: '/en/sources/',
  },
  meta: {
    homeTitle: 'jibiki | Japanese dictionary and durable memory',
    homeDescription:
      'Look up a Japanese word, understand its kanji, and remember it with spaced repetition and mnemonics written for your language.',
    privacyTitle: 'Privacy | jibiki',
    privacyDescription:
      'How jibiki handles local data, accounts, contributions, and optional audience measurement.',
    termsTitle: 'Terms of use | jibiki',
    termsDescription:
      'The rules for using the jibiki dictionary, memory tools, and community contributions.',
    sourcesTitle: 'Sources and licenses | jibiki',
    sourcesDescription:
      'The open dictionaries, stroke data, algorithms, and fonts that make jibiki possible.',
    notFoundTitle: 'Page not found | jibiki',
    notFoundDescription: 'The requested page does not exist or has moved.',
    ogAlt: 'jibiki in its yellow, blue, pink, and green NeoPop world',
  },
  common: {
    brandLabel: 'jibiki, home',
    skip: 'Skip to content',
    openApp: 'Open the app',
    startWithoutAccount: 'Start without an account',
    learnMore: 'See how it works',
    backHome: 'Back to home',
    language: 'Language',
    navigation: 'Main navigation',
    legalNavigation: 'Legal information',
    externalLink: 'opens another website',
  },
  header: {
    features: 'Features',
    dictionary: 'Dictionary',
    method: 'Method',
    study: 'Study',
    tablet: 'Tablet',
    community: 'Community',
  },
  hero: {
    badge: 'Dictionary first. Memory next.',
    titleLead: 'Understand Japanese',
    titleAccent: 'now.',
    titleTail: 'Remember it for good.',
    body:
      'Look a word up, understand its kanji, add it to your reviews. jibiki connects the dictionary and memorization in one app, at your own pace.',
    note: 'Instant lookup. Offline mode. Free.',
    platformsLabel: 'Available on',
    platforms: ['Android', 'iPhone', 'Web'],
    previewLabel: 'Preview of the jibiki dictionary',
    due: 'due for review',
    newCards: '+ 5 new',
    launch: 'Start the session',
    wordOfDay: 'Word of the day',
    flowerViewing: 'A picnic under cherry blossoms. Right on season.',
  },
  dictionary: {
    kicker: 'Try a real lookup',
    title: 'The dictionary is the starting point.',
    body:
      'Writing, readings, meanings, frequency, and examples stay together. Every kanji leads to its components, every component leads to the words that use it, and stroke order animates right on the page. A lookup can remain a quick answer or become a card worth remembering.',
    searchLabel: 'Search for a word, kanji, kana, or meaning',
    placeholder: 'Try 桜, さくら, or cherry tree…',
    submit: 'Search',
    examplesLabel: 'Quick examples',
    loading: 'Searching…',
    noResults: 'No result. Try another spelling or meaning.',
    unavailable: 'Live search will be available at launch. The examples still work.',
    error: 'Search did not respond. The examples are still available.',
    resultCount: 'results',
    meaning: 'Meanings',
    composition: 'Inside the kanji',
    openEntry: 'View in the app',
    addToStudy: 'Add to my memory',
    selectedResult: 'Selected result',
    samples: [
      {
        key: 'sakura',
        query: '桜',
        glyph: '桜',
        reading: 'さくら',
        romaji: 'sakura',
        tags: ['Noun', 'JLPT N5', 'Frequent'],
        meanings: ['cherry tree', 'cherry blossom'],
        parts: [
          { glyph: '木', label: 'tree' },
          { glyph: 'ツ', label: 'petals' },
          { glyph: '女', label: 'woman' },
        ],
      },
      {
        key: 'nihongo',
        query: '日本語',
        glyph: '日本語',
        reading: 'にほんご',
        romaji: 'nihongo',
        tags: ['Noun', 'JLPT N5', 'Common'],
        meanings: ['Japanese language', 'Japanese'],
        parts: [
          { glyph: '日', label: 'sun' },
          { glyph: '本', label: 'origin' },
          { glyph: '語', label: 'language' },
        ],
      },
      {
        key: 'kana-a',
        query: 'あ',
        glyph: 'あ',
        reading: 'a',
        romaji: 'hiragana',
        tags: ['Hiragana', 'Vowel', 'A row'],
        meanings: ['the “a” sound', 'first kana in the gojūon'],
        parts: [
          { glyph: '1', label: 'top stroke' },
          { glyph: '2', label: 'vertical' },
          { glyph: '3', label: 'loop' },
        ],
      },
    ],
  },
  memory: {
    kicker: 'One connected flow',
    title: 'From unknown word to durable memory.',
    body:
      'jibiki connects understanding and memorization in a single motion, from the first encounter with a word to its last recall.',
    steps: [
      {
        number: '1',
        title: 'Look it up',
        body: 'Type Japanese, rōmaji, or a meaning in your language.',
      },
      {
        number: '2',
        title: 'Understand it',
        body: 'Explore readings, components, origins, and words in context.',
      },
      {
        number: '3',
        title: 'Remember it',
        body: 'Add only what matters and let FSRS schedule the next recall.',
      },
    ],
  },
  study: {
    kicker: 'Decks and game modes',
    title: 'One review queue, four ways to play it.',
    body:
      'Pick a ready-made deck or build your own as you look words up. The same session plays as cards, quiz, pairs, or by ear, and you can switch modes whenever you like.',
    decksLabel: 'Decks ready to review',
    decks: ['Hiragana', 'Katakana', 'JLPT N5 kanji', 'Common words', 'Favorites', 'Struggling'],
    modes: [
      {
        key: 'swipe',
        title: 'Cards',
        body: 'Flip the card, then swipe to say how well you knew it.',
      },
      {
        key: 'quiz',
        title: 'Quiz',
        body: 'Pick the right meaning from four choices.',
      },
      {
        key: 'match',
        title: 'Pairs',
        body: 'Match each character with its meaning, two tiles at a time.',
      },
      {
        key: 'listen',
        title: 'Listen',
        body: 'Hear it, then rebuild the reading from the kana tiles.',
      },
    ],
    directions:
      'Every mode plays in both directions: recognize the Japanese, or recall it from the meaning.',
    demo: {
      cardGlyph: '勉強',
      cardReading: 'べんきょう',
      cardGloss: 'study, work',
      quizPrompt: '桜',
      quizOptions: ['cherry tree', 'mountain', 'river', 'car'],
      pairs: [
        { glyph: '犬', label: 'dog', matched: true },
        { glyph: '山', label: 'mountain', matched: false },
      ],
      listenTiles: ['べ', 'ん', 'き', 'ょ', 'う'],
      listenPlaced: 3,
    },
  },
  mnemonic: {
    kicker: 'Mnemonics',
    title: 'Stories written for your language.',
    body:
      'A kanji’s meaning sticks with an image, and a good image speaks every language. Its reading sticks with wordplay, and wordplay belongs to its language. Take 本: the image tells the origin, then each language invents its own pun for the reading ホン.',
    glyph: '本',
    glyphReading: 'ホン',
    glyphMeaning: 'book, origin',
    meaningCard: {
      label: 'The meaning, as an image',
      scope: 'The same image for every language',
      quote:
        'A tree (木) with its roots marked by a stroke (一): the root, the origin, a book.',
      parts: [
        { glyph: '木', label: 'tree' },
        { glyph: '一', label: 'stroke' },
      ],
    },
    readingLabel: 'The reading ホン, one pun per language',
    readingCards: [
      {
        locale: 'en',
        language: 'English',
        quote: 'Hone (ホン) your mind by reading a good book from cover to cover.',
      },
      {
        locale: 'fr',
        language: 'Français',
        quote: 'Quelle honte (ホン) de corner les pages d’un si beau livre.',
      },
    ],
    community:
      'The community writes, draws, and votes the best versions in each language. Keep your favorites or draw your own. And when a language is still waiting for its good version, jibiki says so clearly.',
  },
  review: {
    kicker: 'Spaced repetition',
    title: 'The right recall, right before you forget.',
    body:
      'jibiki schedules every recall with FSRS, a modern spaced repetition algorithm: your real difficulty decides the next date. You set your target retention and how many new cards each session brings, and with enough history the algorithm tunes itself to your own memory.',
    progress: '7 of 20',
    remaining: '13 left. Keep the rhythm.',
    retained: 'GOT IT',
    seen: 'Seen 3 days ago.',
    question: 'How did it feel?',
    reading: 'べんきょう',
    gloss: 'study, work',
    ratings: [
      { key: 'again', label: 'Again', interval: '2 min' },
      { key: 'hard', label: 'Hard', interval: '1 d' },
      { key: 'good', label: 'Good', interval: '3 d' },
      { key: 'easy', label: 'Easy', interval: '7 d' },
    ],
  },
  tablet: {
    kicker: 'Phone and tablet',
    title: 'On tablet, a real workspace.',
    body:
      'A vertical navigation rail, list and detail side by side, kana matrices at full width. On the phone, the same app stays compact and easy to use with one hand.',
    mnemonicLabel: 'Community mnemonic',
    mnemonicQuote:
      'A cherry tree wears a pink crown, then showers the ground when spring says start.',
    search: 'Search for sakura',
    results: '7 results',
    listLabel: 'Dictionary results',
    detailLabel: 'Details for 桜',
    navItems: ['Dict.', 'Kana', 'Review', 'Community', 'Profile'],
    resultItems: [
      { glyph: '桜', reading: 'さくら', gloss: 'cherry tree' },
      { glyph: '咲く', reading: 'さく', gloss: 'to bloom' },
      { glyph: '桜色', reading: 'さくらいろ', gloss: 'cherry pink' },
      { glyph: '花見', reading: 'はなみ', gloss: 'flower viewing' },
    ],
    senses: 'Meanings',
    example: '桜の花が咲いています。',
    translation: 'The cherry trees are in bloom.',
  },
  trust: {
    kicker: 'Useful from the first second',
    title: 'Open, offline, in sync.',
    body:
      'The dictionary is free to browse the moment you arrive. A free account syncs your progress across devices, and content packs keep the essentials available offline.',
    items: [
      {
        icon: '字',
        title: 'Solid reference data',
        body: 'JMdict, KANJIDIC2, KanjiVG, Tatoeba: open sources, credited inside the app.',
      },
      {
        icon: '⇣',
        title: 'Offline',
        body: 'Download content packs and keep the dictionary and your reviews at hand, even without a network.',
      },
      {
        icon: '↺',
        title: 'Synced by account',
        body: 'Your progress follows you from device to device, and you approve the reconciliation before anything merges.',
      },
      {
        icon: '文',
        title: 'Designed for many languages',
        body: 'Interface, meanings, and mnemonics respect their source language.',
      },
    ],
    sourcesLink: 'See every source and license',
  },
  finalCta: {
    title: 'Got a word to look up?',
    body: 'Download jibiki on Android or iPhone, or open it right in the browser.',
    platforms: ['Android', 'iPhone', 'Web'],
  },
  footer: {
    tagline: 'open dictionary, durable memory',
    product: 'Product',
    information: 'Information',
    privacy: 'Privacy',
    terms: 'Terms',
    sources: 'Sources and licenses',
    consentSettings: 'Analytics preferences',
    copyright: 'jibiki. Built to understand and remember Japanese.',
  },
  consent: {
    title: 'You decide what gets measured.',
    body:
      'You choose audience measurement and technical diagnostics separately. The text of your searches stays private.',
    accept: 'Accept all',
    decline: 'Reject all',
    customize: 'Customize',
    save: 'Save my choices',
    analyticsTitle: 'Audience measurement',
    analyticsBody:
      'Allows Google Analytics to measure useful pages and journeys into the app.',
    diagnosticsTitle: 'Technical diagnostics',
    diagnosticsBody:
      'Allows the app to send errors, crashes, and performance data needed for fixes.',
    privacy: 'Read the privacy policy',
    label: 'Audience measurement choice',
  },
  legal: {
    updatedLabel: 'Last updated',
    updatedDate: 'July 13, 2026',
    privacy: {
      title: 'Privacy',
      intro:
        'jibiki is designed to remain useful without an account. This page separates data required for the service from optional measurement.',
      sections: [
        {
          title: 'Local mode and accounts',
          paragraphs: [
            'In local mode, progress, preferences, and product history stay on the device. Clearing browser or application data may remove them.',
            'If you create an account, jibiki processes sign-in information, profile settings, and progress data required to sync between devices.',
          ],
        },
        {
          title: 'Community contributions',
          paragraphs: [
            'A mnemonic, image, vote, or report sent to the community is stored with the information required to display, moderate, and attribute it.',
            'Do not publish personal data inside a contribution intended to be visible to other users.',
          ],
        },
        {
          title: 'Optional audience measurement',
          paragraphs: [
            'The site loads Google Analytics only after explicit consent. When no GA4 identifier is configured, no Google Analytics component is loaded.',
            'Events measure page views, interactions with demonstrations, and journeys into the app. Text entered into search is never sent as an analytics parameter. The first-party jibiki_consent_v1 cookie shares analytics and diagnostics choices between jibiki.app and my.jibiki.app.',
          ],
        },
        {
          title: 'Your choices',
          paragraphs: [
            'You can decline measurement, change your choice from the footer, and use the product without accepting analytics.',
            'For a request related to account data, use the feedback form inside jibiki so the request can be connected to the right account without publishing a personal address here.',
          ],
        },
        {
          title: 'Security and retention',
          paragraphs: [
            'jibiki limits collection to data useful for the service, protects network traffic in production, and separates public content from account data.',
            'Exact retention periods depend on the data category, security obligations, and valid deletion requests. This policy will be made more specific before public account launch.',
          ],
        },
      ],
    },
    terms: {
      title: 'Terms of use',
      intro:
        'These terms cover use of the dictionary, memory tools, and community areas in jibiki.',
      sections: [
        {
          title: 'Using the service',
          paragraphs: [
            'You may use the public dictionary without an account. Some synchronization and contribution features require a valid account.',
            'You remain responsible for your device, credentials, and content you choose to publish.',
          ],
        },
        {
          title: 'Learning content',
          paragraphs: [
            'Definitions, readings, examples, and review schedules are learning aids. They may contain errors or change when sources are updated.',
            'jibiki does not guarantee an exam result, JLPT level, or particular command of Japanese.',
          ],
        },
        {
          title: 'Contributions',
          paragraphs: [
            'Only publish content you have the right to share. Illegal, misleading, offensive, or rights-infringing content may be hidden or moderated.',
            'By publishing, you allow jibiki to display, technically adapt, and distribute the contribution across product surfaces. Final license terms will be shown when contributing before public launch.',
          ],
        },
        {
          title: 'Availability and change',
          paragraphs: [
            'The service may be interrupted for maintenance, security, or product changes. Experimental features may change before stable release.',
            'Rules for a paid feature will be shown before purchase. This page does not announce a price or subscription that is not available in the product.',
          ],
        },
        {
          title: 'Respecting licenses',
          paragraphs: [
            'Data and stroke assets from third-party projects remain subject to their own licenses. The Sources and licenses page lists them and provides attribution.',
          ],
        },
      ],
    },
    sources: {
      title: 'Sources and licenses',
      intro:
        'jibiki brings together open language data and tools. Attribution is part of the product, not a hidden footnote.',
      entries: [
        {
          name: 'EDRDG: JMdict, KANJIDIC2, KRADFILE, and RADKFILE',
          license: 'EDRDG License',
          body: 'Words, readings, multilingual meanings, kanji, and component decomposition.',
          href: 'https://www.edrdg.org/edrdg/licence.html',
        },
        {
          name: 'KanjiVG',
          license: 'CC BY-SA 3.0',
          body: 'Vector strokes used to display and animate stroke order.',
          href: 'https://kanjivg.tagaini.net/',
        },
        {
          name: 'Tatoeba',
          license: 'CC BY 2.0 FR when examples are used',
          body: 'Example sentences and translations linked to their authors and licenses.',
          href: 'https://tatoeba.org/',
        },
        {
          name: 'FSRS',
          license: 'Open algorithm',
          body: 'Spaced repetition scheduling based on observed memory.',
          href: 'https://github.com/open-spaced-repetition/free-spaced-repetition-scheduler',
        },
        {
          name: 'Space Grotesk and Zen Kaku Gothic New',
          license: 'SIL Open Font License',
          body: 'Typeface families used for the Latin and Japanese brand system.',
          href: 'https://openfontlicense.org/',
        },
      ],
      notice:
        'Community contributions remain attributed to their authors and follow the rights presented when they are published.',
    },
  },
  notFound: {
    code: '404',
    title: 'This page slipped away.',
    body: 'The link may have changed, but the dictionary is still waiting for you.',
  },
};

export const messages: Record<Locale, Messages> = { fr, en };

export const getMessages = (locale: Locale): Messages => messages[locale];

export const alternateLocale = (locale: Locale): Locale =>
  locale === 'fr' ? 'en' : 'fr';
