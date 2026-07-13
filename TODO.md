DEPLOY:
- build ios android (pipeline gratuite pour déployer sur store direct ?)
- deployment sur hetnzer (redonance, sockage S3  pas cher (penser egress etc)), ...; bitwarden pour secret; interfacage et tunnel cloudflare donc on peut envisager du R2 si c'est plus smart; comme ça pas de gateway etc sur hetzner (sauf si c'est gratuit); a voir si IAC ou overkill (cloudinit, terraform, etc pour la postérité)

- je veux des backups, de la redondance et possibilité de scale si jamais besoin
- optimise par rapport au prix (je veux payer max 25 euros par mois)

- obfuscation, proper security around sensitive calls and to protect the product
- fetch apple et google guidline pour la publication pour qu'on soit compliant et qu'on ne loupe rien

- est-ce qu'un centre observability style grafana est partinent ?; j'imagine pour stockage sur call api, usage cpu ram etc, le nombre de mail envoyé, nombre de connexion, de fetch de package, bref absoluement tout ce qui est pertinant;

- le seo est bien complet et bien poussé ? tu as fait une image pour l'url preview, des titres etc bref la total (tu es expert SEO et analytics); fais aussi un email template dans le design neopop 

MARKETING:
- choisir fremium ou one shot payment
- modifie le code de sorte que demain je puisse facilement décider de quelle fonctionalité est gratuite ou payante (je ne sais pas encore si c'est un pay one shot ou un abonnement) (avec sécurité)
- ajouter log pro (firebase) et analytics complet (my.jibiki.app vs jibiki.app)

FEATURES:
- streak ou autre créé un reward (booster) qui donne acces à des cartes (mais certaines cartes sont des consomables genre une nouvelle palette de couleur, ...)
- appliquer le plan youtube sur les streak/burn, les boosters, etc
- scrap jisho site (et autre) et comparer le dataset kanji et mot pour être sur que c'est juste et complet (bien mettre dans wrapper de traduction comme explicité dans readme
- vérifier que les cartes et algo est solide sur les propositions (un truc qui monte, ou tu revois ce que tu as déjà étudié etc)
- setup une url django admin avec un espace admin poussé (dalf et autre package hyper utile) pour avoir une vue sur le contenu actuellement en db etc

IMAGE GENERATION:
- générer les images hiragana et katakana (et les intégrés dans le visuel, dans les palettes dynamiques, ...). je veux des images simples qui sont unicolore (en noir d'ailleurs genre png, comme ça on pourra mettre la couleur qu'on veut). l'idée est qu'il se grefe au kana associé par superposition (ou sousperposition); il y a des exemples hyperr complet ici : jibiki\misc\mnemonic-samples\references

FEATURE FINDINGS:
- le seo est bien complet et bien poussé ? tu as fait une image pour l'url preview, des titres etc bref la total (tu es expert SEO et analytics); fais aussi un email template dans le design neopop; 


SITE WEB (a faire quand ui est fini):
- parler télécharger l'app android ou iphone (sinon il y a le web)
- pas de phrase à la négative qui n'apporte rien (ça donne un ton je sais tout et autaint)
- la charte textuelle : comme une personne qui est contente de son app et qui explique les fonctionalités coeurs avec détail et orienté marketing (donc ce que les gens aiment et ne trouvent pas ailleurs); les interconnections, le mode offline, le responsive, le sync via compte, la gratuite (mais sans bullshit). montre le systeme de deck d'étude et la version memo et la version audio etc. parle des fonctionalités qui ont une valeur
- il y a des endroits ou tu vends le fait que c'est mnemotechniques et scopé sur la langue mais fait attention que parfois la langue marche pour les deux, genre les kanji techniquement la langue marche pour chaque (vu que c'est un JEU sur l'image). par contre oui tu as raison sur le kanji composé vu que la c'est un jeru de mot sur des sous kanji dont la traduction fait qu'en francais ça passerait pas (genre les dictons, proverbes, "blague", ...). bref je me trompe probablement dans le wording mais tu captes l'exemple ou ce que" je veux dire. donc quand tu expliques assures toi d'avoir un exemple vraiment parlant.