# Politique de confidentialité — Strength Sync for Hevy

Date d’entrée en vigueur : 2 septembre 2026

Strength Sync for Hevy est une application Connect IQ indépendante. Elle n’est ni éditée, ni sponsorisée, ni approuvée par Hevy ou Garmin.

## Données traitées

L’application traite uniquement les données nécessaires à son fonctionnement :

- la clé API Hevy fournie par l’utilisateur dans les paramètres Garmin ;
- les routines Hevy, notamment leurs titres, identifiants d’exercices, séries, charges, répétitions et temps de repos ;
- les séances réalisées, notamment les exercices, séries, charges, répétitions et horaires ;
- les données physiologiques que la montre Garmin enregistre nativement dans le fichier FIT de l’activité, comme la fréquence cardiaque lorsqu’elle est disponible.

## Utilisation et transmission

La montre communique directement avec l’API publique Hevy sur `https://api.hevyapp.com`. La clé API sert à télécharger les routines du compte de l’utilisateur et à y créer les séances terminées.

Les séances envoyées sont créées privées par défaut. L’utilisateur peut ensuite modifier leur visibilité depuis Hevy.

La montre crée également un fichier d’activité FIT. Garmin peut synchroniser ce fichier vers Garmin Connect conformément aux choix et au compte Garmin de l’utilisateur.

L’éditeur de cette application n’exploite aucun serveur intermédiaire et ne reçoit aucune clé API, routine, séance, donnée physiologique, donnée analytique ou donnée publicitaire.

## Stockage local et durée de conservation

Sur la montre, l’application conserve :

- la clé API tant que l’utilisateur ne la remplace pas, ne la révoque pas ou ne désinstalle pas l’application ;
- un cache compact de routines jusqu’à sa prochaine actualisation ou la désinstallation ;
- au maximum trois séances terminées en attente, jusqu’à leur synchronisation avec Hevy ou la désinstallation ;
- un brouillon de séance uniquement pendant l’exécution de l’application ; il est supprimé à la fin, à l’annulation ou au prochain démarrage.

L’application n’utilise aucun traceur, service d’analyse, publicité ou profilage.

## Contrôle et suppression

L’utilisateur peut :

- révoquer ou remplacer sa clé depuis les paramètres développeur Hevy ;
- supprimer les données locales en désinstallant l’application de la montre ;
- supprimer une séance envoyée depuis son compte Hevy ;
- supprimer une activité FIT depuis Garmin Connect.

Les données déjà transmises à Hevy ou Garmin sont régies par les politiques et outils de ces services. Pour toute question concernant cette application, ouvrir une demande sur [le dépôt GitHub](https://github.com/achoblet33-web/hevy/issues) sans y joindre de clé API ni de données personnelles.

## Services tiers

- [Politique de confidentialité Hevy](https://www.hevyapp.com/legal/privacy-policy/)
- [Politique de confidentialité Garmin](https://www.garmin.com/privacy/)

Cette politique sera mise à jour si le traitement des données change. Son URL devra rester stable ou rediriger vers sa nouvelle version.
