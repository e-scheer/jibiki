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
    tablet: 'Tablette',
    community: 'Communauté',
  },
  hero: {
    badge: 'Dictionnaire d’abord. Mémoire ensuite.',
    titleLead: 'Comprendre le japonais',
    titleAccent: 'maintenant.',
    titleTail: 'Le retenir pour de bon.',
    body:
      'Un dictionnaire japonais qui transforme chaque recherche en souvenir durable, sans vous imposer un compte ni un rythme artificiel.',
    note: 'Recherche immédiate. Mode local. Apprentissage à votre rythme.',
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
      'Écriture, lecture, sens, fréquence, composants et exemples restent réunis. Une recherche peut rester une simple recherche ou devenir une carte à retenir.',
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
      'jibiki relie la compréhension et la mémorisation au lieu de vous faire changer d’outil.',
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
  mnemonic: {
    kicker: 'Votre langue compte',
    title: 'Une mnémotechnique ne se traduit pas au kilomètre.',
    body:
      'Les jeux de sons et les images mentales sont écrits ou adaptés pour leur langue. Quand une bonne version n’existe pas, jibiki préfère le dire plutôt que servir une traduction bancale.',
    languageLabel: 'Mnémotechnique en',
    communityLabel: 'Exemple écrit pour cette langue',
    cards: [
      {
        locale: 'fr',
        language: 'Français',
        quote:
          'Pour 桜, imagine un cerisier qui sort son plus beau kimono rose dès que le printemps sonne à la porte.',
        author: 'Exemple éditorial français',
      },
      {
        locale: 'en',
        language: 'English',
        quote:
          'A cherry tree wears a pink crown, then showers the ground when spring says start.',
        author: 'English editorial example',
      },
    ],
  },
  review: {
    kicker: 'Répétition espacée',
    title: 'Réviser sans bruit, avancer sans culpabilité.',
    body:
      'La difficulté réelle décide du prochain rappel. Pas de mur quotidien, pas de mascotte qui vous gronde, seulement une file claire et un rythme que vous contrôlez.',
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
    kicker: 'Tablette premium',
    title: 'Un espace de travail, pas un téléphone étiré.',
    body:
      'La navigation reste compacte, la liste et le détail cohabitent, et les matrices utilisent réellement la largeur disponible.',
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
    title: 'Le dictionnaire ne se cache pas derrière un compte.',
    body:
      'Consultez, explorez et pratiquez localement. Le compte sert à synchroniser et contribuer, jamais à bloquer la référence.',
    items: [
      {
        icon: '字',
        title: 'Données de référence solides',
        body: 'JMdict, KANJIDIC2, KanjiVG et des attributions visibles.',
      },
      {
        icon: '↺',
        title: 'Mémoire locale et durable',
        body: 'Vos recherches et votre apprentissage restent utiles sans connexion permanente.',
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
    body: 'Ouvrez jibiki et transformez cette recherche en quelque chose que vous retiendrez.',
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
    title: 'Mesurer sans vous suivre à votre insu.',
    body:
      'Vous choisissez séparément les mesures d’audience et les diagnostics techniques. Aucun texte recherché n’est envoyé.',
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
    tablet: 'Tablet',
    community: 'Community',
  },
  hero: {
    badge: 'Dictionary first. Memory next.',
    titleLead: 'Understand Japanese',
    titleAccent: 'now.',
    titleTail: 'Remember it for good.',
    body:
      'A Japanese dictionary that turns any lookup into durable memory, without forcing an account or an artificial pace on you.',
    note: 'Instant lookup. Local mode. Learning at your pace.',
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
      'Writing, reading, meanings, frequency, components, and examples stay together. A lookup can remain a quick answer or become a card worth remembering.',
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
      'jibiki connects understanding and memorization instead of making you switch tools.',
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
  mnemonic: {
    kicker: 'Your language matters',
    title: 'A mnemonic should not be translated by the yard.',
    body:
      'Sound play and mental images are written or adapted for their language. When a good version does not exist, jibiki would rather say so than serve a broken translation.',
    languageLabel: 'Mnemonic in',
    communityLabel: 'Example written for this language',
    cards: [
      {
        locale: 'en',
        language: 'English',
        quote:
          'A cherry tree wears a pink crown, then showers the ground when spring says start.',
        author: 'English editorial example',
      },
      {
        locale: 'fr',
        language: 'Français',
        quote:
          'Pour 桜, imagine un cerisier qui sort son plus beau kimono rose dès que le printemps sonne à la porte.',
        author: 'Exemple éditorial français',
      },
    ],
  },
  review: {
    kicker: 'Spaced repetition',
    title: 'Review without noise. Move forward without guilt.',
    body:
      'Real difficulty decides the next recall. No daily wall and no mascot scolding you, only a clear queue at a pace you control.',
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
    kicker: 'Premium tablet experience',
    title: 'A workspace, not a stretched phone.',
    body:
      'Navigation stays compact, list and detail live side by side, and dense matrices make real use of the available width.',
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
    title: 'The dictionary does not hide behind an account.',
    body:
      'Look up, explore, and practice locally. An account helps you sync and contribute, never blocks the reference.',
    items: [
      {
        icon: '字',
        title: 'Solid reference data',
        body: 'JMdict, KANJIDIC2, KanjiVG, and visible attribution.',
      },
      {
        icon: '↺',
        title: 'Local, durable memory',
        body: 'Your lookups and learning stay useful without a permanent connection.',
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
    body: 'Open jibiki and turn that lookup into something you will remember.',
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
    title: 'Measure without watching you behind your back.',
    body:
      'You choose audience measurement and technical diagnostics separately. Search text is never sent.',
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
