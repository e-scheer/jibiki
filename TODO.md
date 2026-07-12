DESIGN=
c'est parti pour refaire tout le design de l'app, on va intégrer 10-neopop.html dans design-explorations:
- le design actuel ne doit pas t'influencer dans ta vision UI/UX (le but est aussi de repenser le UI UX au besoin)
- mobile and tablet friendly
- extrememnt optimisé (pas de lag, dois fonctionner sur telephone plus modeste, s'il faut attendre alors avec loader/skeleton/...)
- les fonctionalités et le contenu est la, à toi de voir si avec le design il faut ou pas les reordonnées etc, le visuel n'est pas CONDITIONNé par ce qui existe mtn
- après le design update le PRODUCT.md s'il ne correspond plus 
- version tablette premium
- utiliser à fond les animations/transition pour transitions de page, les boutons, les composants, les chargements, les visuels/hapetics, les retours/indicateurs visuel, etc (bref )
- prévoir le fait que les couleurs peuvent etre changés dynamiquement sous forme de palettes (un peu comme vscode tu peux changer le "theme"); par ex le design 12-neopop-harmonie.html est presque équivalent si ce n'est la palette de couleur)

DEPLOY:
- build ios android
- deployment sur hetnzer (redonance, sockage S3 pas cher, ...)
- faire un frontpage meme design que l'app (proposer un subset des fonctionalités pour le moment) (inclure SEO et analytics google hyper poussé)
- obfuscation, proper security around sensitive calls and to protect the product
- fetch apple et google guidline pour la publication pour qu'on soit compliant et qu'on ne loupe rien
- je veux des backups, de la redondance et possibilité de scale si jamais besoin
- optimise par rapport au prix (je veux payer max 20-50 euros par mois)
- si besoin et/ou mieux utilise cloudinit, terraform, etc pour la postérité

MARKETING:
- choisir fremium ou one shot payment
- modifie le code de sorte que demain je puisse facilement décider de quelle fonctionalité est gratuite ou payante (je ne sais pas encore si c'est un pay one shot ou un abonnement) (avec sécurité)
- ajouter log pro (firebase) et analytics complet

FEATURES:
- streak ou autre créé un reward (booster) qui donne acces à : des palettes de couleur, ... ???
- appliquer le plan youtube sur les streak/burn, les boosters, etc

FEATURE FINDINGS:
-
