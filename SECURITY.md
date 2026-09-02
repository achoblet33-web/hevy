# Sécurité

## Modèle de sécurité

- Chaque utilisateur renseigne sa propre clé API Hevy. Aucune clé partagée n’est incluse dans le code ou le paquet Connect IQ.
- Les échanges réseau vont directement de Garmin Connect Mobile vers `https://api.hevyapp.com` en HTTPS. Le projet n’exploite aucun serveur intermédiaire.
- L’application ne journalise jamais la clé API ni le contenu des réponses Hevy.
- Les nouvelles séances Hevy sont créées privées par défaut.
- Les routines et séances en attente sont limitées et stockées uniquement dans l’espace privé de l’application.
- Les permissions `Communications`, `Fit`, `FitContributor` et `Sensor` sont nécessaires respectivement pour Hevy, l’activité Garmin, les champs FIT personnalisés et l’activation explicite de la fréquence cardiaque.

## Clé API Hevy

La clé API est un secret personnel donnant accès au compte Hevy de l’utilisateur. Elle ne doit jamais être copiée dans le dépôt, une capture d’écran, un rapport de bug ou un journal de compilation. En cas de fuite, la révoquer immédiatement dans Hevy et en générer une nouvelle.

La clé est saisie dans un champ Garmin de type `password`. Une application publiée et installée depuis le Connect IQ Store s’exécute au niveau de confiance Garmin « Trusted » et son espace de stockage est protégé par le modèle de sécurité Garmin. Cela ne remplace pas la révocation d’une clé compromise.

## Clé développeur Garmin

La clé privée utilisée pour signer l’application :

- reste hors du dépôt et des fichiers `.iq` distribués ;
- doit être sauvegardée dans au moins deux emplacements privés et chiffrés ;
- ne doit jamais être envoyée dans une issue ou une conversation ;
- doit rester la même pour toutes les mises à jour de l’application publiée.

Le workflow CI utilise volontairement une clé éphémère pour vérifier la compilation. L’export destiné au Store doit être signé localement avec la clé développeur permanente.

## Signaler un problème

Pour un bug sans donnée sensible, ouvrir une issue GitHub. Ne jamais publier une clé API, une clé Garmin, un fichier FIT personnel ou une réponse API complète. Pour une suspicion de fuite, révoquer d’abord la clé concernée, puis décrire uniquement les étapes minimales de reproduction.

Les dépendances GitHub Actions sont épinglées sur une révision précise et le workflow dispose seulement de l’autorisation `contents: read`.
