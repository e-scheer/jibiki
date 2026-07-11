class ReferenceText {
  const ReferenceText(this.en, this.fr);

  final String en;
  final String fr;

  String resolve(String language) => language == 'fr' ? fr : en;
}

class ReferenceSection {
  const ReferenceSection({
    required this.title,
    required this.body,
    this.examples = const [],
  });

  final ReferenceText title;
  final ReferenceText body;
  final List<ReferenceText> examples;
}

class ReferenceCard {
  const ReferenceCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.summary,
    required this.sections,
  });

  final String id;
  final String icon;
  final ReferenceText title;
  final ReferenceText summary;
  final List<ReferenceSection> sections;
}

const japaneseReferenceCards = <ReferenceCard>[
  ReferenceCard(
    id: 'particles',
    icon: '文',
    title: ReferenceText('Particles', 'Particules'),
    summary: ReferenceText(
      'Small words that mark the role of each phrase.',
      'Petits mots qui indiquent le rôle de chaque groupe.',
    ),
    sections: [
      ReferenceSection(
        title: ReferenceText('Core particles', 'Particules essentielles'),
        body: ReferenceText(
          'は marks the topic, が the subject or new information, を the direct object, に a destination, time or recipient, and で the place or means of an action.',
          'は marque le thème, が le sujet ou une information nouvelle, を le complément direct, に la destination, le moment ou le destinataire, et で le lieu ou le moyen de l’action.',
        ),
        examples: [
          ReferenceText('私は学生です。 I am a student.', '私は学生です。 Je suis étudiant.'),
          ReferenceText('駅で本を読む。 Read a book at the station.',
              '駅で本を読む。 Lire un livre à la gare.'),
        ],
      ),
      ReferenceSection(
        title:
            ReferenceText('Relations and direction', 'Relations et direction'),
        body: ReferenceText(
          'の means possession or connection, と means with or quotation, も means also, へ points toward a direction, and から / まで mean from / until.',
          'の exprime la possession ou le lien, と signifie avec ou une citation, も signifie aussi, へ indique une direction, et から / まで signifient de / jusqu’à.',
        ),
        examples: [
          ReferenceText(
              '日本の文化。 Japanese culture.', '日本の文化。 La culture japonaise.'),
          ReferenceText(
              '東京から大阪まで。 From Tokyo to Osaka.', '東京から大阪まで。 De Tokyo à Osaka.'),
        ],
      ),
      ReferenceSection(
        title: ReferenceText('Nuance particles', 'Particules de nuance'),
        body: ReferenceText(
          'だけ means only, しか must be paired with a negative, ほど means to the extent of, and より introduces a comparison.',
          'だけ signifie seulement, しか s’emploie avec une négation, ほど signifie dans la mesure de, et より introduit une comparaison.',
        ),
        examples: [
          ReferenceText(
              '水だけ飲む。 I drink only water.', '水だけ飲む。 Je ne bois que de l’eau.'),
          ReferenceText(
              'これしかない。 There is nothing but this.', 'これしかない。 Il n’y a que ça.'),
        ],
      ),
    ],
  ),
  ReferenceCard(
    id: 'verb-conjugation',
    icon: '活',
    title: ReferenceText('Verb conjugation', 'Conjugaison des verbes'),
    summary: ReferenceText(
      'Build polite, negative, past, て, potential and passive forms.',
      'Construire les formes polie, négative, passée, en て, potentielle et passive.',
    ),
    sections: [
      ReferenceSection(
        title: ReferenceText('The three groups', 'Les trois groupes'),
        body: ReferenceText(
          'Group 1 verbs change their final kana: 書く becomes 書きます. Group 2 verbs drop る: 食べる becomes 食べます. Irregular verbs are する and 来る.',
          'Les verbes du groupe 1 changent leur dernière kana : 書く devient 書きます. Au groupe 2, on retire る : 食べる devient 食べます. Les irréguliers sont する et 来る.',
        ),
        examples: [
          ReferenceText('書く → 書きます → 書かない', '書く → 書きます → 書かない'),
          ReferenceText('食べる → 食べます → 食べない', '食べる → 食べます → 食べない'),
        ],
      ),
      ReferenceSection(
        title: ReferenceText('Past and て forms', 'Formes passée et en て'),
        body: ReferenceText(
          'The て form links actions, makes requests and combines with いる. For う verbs, う/つ/る become って, む/ぶ/ぬ become んで, and く becomes いて. 行く is the exception: 行って.',
          'La forme en て relie les actions, sert aux demandes et se combine avec いる. Pour les verbes en う, う/つ/る deviennent って, む/ぶ/ぬ deviennent んで et く devient いて. 行く est l’exception : 行って.',
        ),
        examples: [
          ReferenceText(
              '読んで、寝る。 Read, then sleep.', '読んで、寝る。 Je lis puis je dors.'),
          ReferenceText(
              '見てください。 Please look.', '見てください。 Regardez, s’il vous plaît.'),
        ],
      ),
      ReferenceSection(
        title: ReferenceText(
            'Potential, passive, causative', 'Potentiel, passif, causatif'),
        body: ReferenceText(
          'Potential means can: 読む → 読める. Passive means be acted on: 褒める → 褒められる. Causative means make or let someone do: 読む → 読ませる.',
          'Le potentiel signifie pouvoir : 読む → 読める. Le passif signifie subir une action : 褒める → 褒められる. Le causatif signifie faire ou laisser faire : 読む → 読ませる.',
        ),
      ),
    ],
  ),
  ReferenceCard(
    id: 'adjectives',
    icon: '形',
    title: ReferenceText('Adjectives', 'Adjectifs'),
    summary: ReferenceText(
      'い and な adjectives follow different rules.',
      'Les adjectifs en い et en な suivent des règles différentes.',
    ),
    sections: [
      ReferenceSection(
        title: ReferenceText('い adjectives', 'Adjectifs en い'),
        body: ReferenceText(
          'The final い changes: 高い, 高くない, 高かった, 高くなかった. Do not attach な before a noun.',
          'Le い final change : 高い, 高くない, 高かった, 高くなかった. On ne met pas な devant un nom.',
        ),
        examples: [
          ReferenceText('高い山。 A tall mountain.', '高い山。 Une haute montagne.'),
        ],
      ),
      ReferenceSection(
        title: ReferenceText('な adjectives', 'Adjectifs en な'),
        body: ReferenceText(
          'な adjectives use だ / です as a predicate and add な before a noun: 静かな町. Their negative is ではない or じゃない.',
          'Les adjectifs en な utilisent だ / です comme prédicat et prennent な devant un nom : 静かな町. La négation est ではない ou じゃない.',
        ),
        examples: [
          ReferenceText(
              '町は静かです。 The town is quiet.', '町は静かです。 La ville est calme.'),
        ],
      ),
    ],
  ),
  ReferenceCard(
    id: 'readings',
    icon: '読',
    title: ReferenceText('Onyomi and kunyomi', 'On’yomi et kun’yomi'),
    summary: ReferenceText(
      'Choose the reading from the word shape and context.',
      'Choisir la lecture selon la forme du mot et le contexte.',
    ),
    sections: [
      ReferenceSection(
        title: ReferenceText('On’yomi', 'On’yomi'),
        body: ReferenceText(
          'On’yomi are Sino-Japanese readings. They are common in compounds of two or more kanji: 学校, 電話, 新聞.',
          'Les lectures on’yomi sont sino-japonaises. Elles sont fréquentes dans les composés de deux kanji ou plus : 学校, 電話, 新聞.',
        ),
      ),
      ReferenceSection(
        title: ReferenceText('Kun’yomi', 'Kun’yomi'),
        body: ReferenceText(
          'Kun’yomi are native Japanese readings. They often appear with okurigana: 食べる, 飲む, 新しい. A kanji can have several readings, so learn them in words.',
          'Les lectures kun’yomi sont japonaises. Elles apparaissent souvent avec des okurigana : 食べる, 飲む, 新しい. Un kanji peut avoir plusieurs lectures : apprenez-les dans des mots.',
        ),
      ),
      ReferenceSection(
        title: ReferenceText('A practical rule', 'Règle pratique'),
        body: ReferenceText(
          'Do not guess from the kanji alone. Check the word, its okurigana and the surrounding grammar. The dictionary entry is the source of truth.',
          'Ne devinez pas à partir du kanji seul. Regardez le mot, ses okurigana et la grammaire autour. La fiche du dictionnaire fait foi.',
        ),
      ),
    ],
  ),
  ReferenceCard(
    id: 'counters',
    icon: '数',
    title: ReferenceText('Counters', 'Compteurs'),
    summary: ReferenceText(
      'The counter changes the reading of the number.',
      'Le compteur change la lecture du nombre.',
    ),
    sections: [
      ReferenceSection(
        title: ReferenceText('People and objects', 'Personnes et objets'),
        body: ReferenceText(
          '人 counts people, 本 long cylindrical objects, 枚 flat objects, 匹 small animals, 台 machines, 冊 books and 個 small general objects.',
          '人 compte les personnes, 本 les objets longs, 枚 les objets plats, 匹 les petits animaux, 台 les machines, 冊 les livres et 個 les objets génériques.',
        ),
        examples: [
          ReferenceText('三人、一本、二枚、五匹', '三人、一本、二枚、五匹'),
          ReferenceText('一冊の本。 One book.', '一冊の本。 Un livre.'),
        ],
      ),
      ReferenceSection(
        title: ReferenceText('Irregular sounds', 'Lectures irrégulières'),
        body: ReferenceText(
          'Watch for sound changes: 一人 ひとり, 二人 ふたり, 一匹 いっぴき, 三匹 さんびき, 六本 ろっぽん, 八本 はっぽん.',
          'Attention aux changements sonores : 一人 ひとり, 二人 ふたり, 一匹 いっぴき, 三匹 さんびき, 六本 ろっぽん, 八本 はっぽん.',
        ),
      ),
    ],
  ),
  ReferenceCard(
    id: 'sentence-patterns',
    icon: '文',
    title: ReferenceText('Sentence patterns', 'Structures de phrase'),
    summary: ReferenceText(
      'Japanese is head-final: the verb usually closes the sentence.',
      'Le japonais est tête-finale : le verbe ferme généralement la phrase.',
    ),
    sections: [
      ReferenceSection(
        title: ReferenceText('Basic order', 'Ordre de base'),
        body: ReferenceText(
          'The common order is topic, time, place, object, verb. Subjects are often omitted when the context is clear.',
          'L’ordre courant est thème, moment, lieu, objet, verbe. Le sujet est souvent omis quand le contexte est clair.',
        ),
        examples: [
          ReferenceText('私は毎日学校で日本語を勉強します。', '私は毎日学校で日本語を勉強します。'),
        ],
      ),
      ReferenceSection(
        title: ReferenceText('Relative clauses', 'Propositions relatives'),
        body: ReferenceText(
          'A clause comes before the noun it describes. There is no relative pronoun like “which” or “that”.',
          'La proposition vient avant le nom qu’elle décrit. Il n’y a pas de pronom relatif équivalent à « qui » ou « que ».',
        ),
        examples: [
          ReferenceText('昨日買った本。 The book I bought yesterday.',
              '昨日買った本。 Le livre que j’ai acheté hier.'),
        ],
      ),
    ],
  ),
  ReferenceCard(
    id: 'register',
    icon: '敬',
    title: ReferenceText('Register and politeness', 'Registre et politesse'),
    summary: ReferenceText(
      'Match the ending to the relationship and situation.',
      'Adapter la terminaison à la relation et à la situation.',
    ),
    sections: [
      ReferenceSection(
        title: ReferenceText('です / ます', 'です / ます'),
        body: ReferenceText(
          'です and ます are the safe polite style for classes, strangers and professional contexts. The plain style is normal with friends, notes and subordinate clauses.',
          'です et ます sont le registre poli sûr pour les cours, les inconnus et le travail. Le style neutre est normal entre amis, dans les notes et les propositions subordonnées.',
        ),
        examples: [
          ReferenceText(
              '行きます。 I will go. / 行く。 I go.', '行きます。 J’irai. / 行く。 Je vais.'),
        ],
      ),
      ReferenceSection(
        title: ReferenceText('Do not over-translate', 'Ne pas surtraduire'),
        body: ReferenceText(
          'Japanese often leaves the subject, tense context and level of certainty implicit. Read the whole sentence before choosing a French or English equivalent.',
          'Le japonais laisse souvent implicites le sujet, le contexte temporel et le degré de certitude. Lisez toute la phrase avant de choisir un équivalent.',
        ),
      ),
    ],
  ),
];
