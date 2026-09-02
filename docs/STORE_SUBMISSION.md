# Publication Connect IQ Store

## Positionnement recommandé

**Nom public :** Strength Sync for Hevy

**Mention obligatoire dans la description :** Application indépendante, non affiliée à Hevy ni à Garmin. Hevy Pro et une clé API personnelle sont requis. L’API publique Hevy est susceptible d’évoluer.

L’icône actuelle est originale et ne reprend pas le logo Hevy. Avant publication, demander l’autorisation de Hevy si leur nom ou toute autre marque doit être utilisé autrement que pour décrire la compatibilité du produit.

## Description française proposée

Strength Sync for Hevy permet de lancer vos routines Hevy depuis une Garmin Fenix 8 47 mm, de suivre chaque série avec commandes tactiles et boutons, puis d’envoyer la séance terminée, privée par défaut, vers votre compte Hevy. L’activité Garmin enregistre les données physiologiques natives et ajoute dans Garmin Connect des champs par tour pour l’exercice, le numéro de série, la charge et les répétitions, ainsi qu’un résumé du volume.

Fonctions principales : cache hors ligne des routines, préchargement des objectifs Hevy, roulette tactile pour poids et répétitions, repos ajustable, pause, annulation confirmée et file d’envoi hors ligne.

Prérequis : abonnement Hevy Pro, clé API personnelle, téléphone appairé pour les synchronisations. Application indépendante, non affiliée à Hevy ni à Garmin. Les exercices apparaissent dans Garmin Connect comme données Connect IQ par tour ; ils ne remplacent pas l’éditeur d’exercices natif Garmin.

Politique de confidentialité : `https://github.com/achoblet33-web/hevy/blob/main/PRIVACY.md`

## Checklist avant envoi

- [ ] Tester une séance complète sur la vraie Fenix 8 et vérifier l’activité dans Garmin Connect mobile et web.
- [ ] Vérifier les quatre colonnes Connect IQ par tour : exercice, série, poids et répétitions.
- [ ] Vérifier les trois valeurs de résumé : séries, répétitions et volume.
- [ ] Tester sans téléphone, puis reconnecter et confirmer l’envoi différé vers Hevy.
- [ ] Tester une clé invalide ou révoquée sans exposer sa valeur dans un message.
- [ ] Tester annulation, pause, fin anticipée et sortie inattendue.
- [ ] Produire des captures nettes du sélecteur de routine, d’une série active, de la roulette et du résumé.
- [ ] Conserver l’UUID de production `a142c73f384a4c9cb5f2d8e963bd3a8f` et la même clé de signature pour toutes les mises à jour.
- [ ] Faire une sauvegarde chiffrée de la clé développeur permanente.
- [ ] Vérifier que `git status` n’inclut aucun `.der`, `.pem`, `.key`, `.iq`, `.prg`, `.fit` ou `.env`.
- [ ] Exporter le projet avec le SDK stable ciblé et la clé permanente.
- [ ] Relire la politique de confidentialité et la description au moment de soumettre.

## Export Windows

Dans VS Code : `Ctrl+Shift+P` → `Monkey C: Export Project` → choisir la destination `.iq`.

Vérifier auparavant dans les paramètres VS Code que `Monkey C: Developer Key Path` pointe vers la clé permanente. Ne pas utiliser la clé éphémère du workflow CI pour une publication.

En ligne de commande, adapter les chemins puis exécuter :

```powershell
java -Xms1g -Dfile.encoding=UTF-8 -jar "C:\chemin\ConnectIQ\Sdks\9.2.0\bin\monkeybrains.jar" `
  -o "C:\chemin\Hevy.iq" `
  -f "C:\Users\votre-utilisateur\hevy\monkey.jungle" `
  -y "C:\chemin-prive\hevy-developer-key" `
  -e -r -w
```

## Envoi

1. Se connecter au compte développeur Garmin et ouvrir la page **Submit an App**.
2. Importer le fichier `.iq` exporté.
3. Renseigner le nom, la catégorie, la description, les captures, l’URL d’assistance et l’URL de confidentialité.
4. Déclarer exactement les fonctionnalités réseau et les données traitées.
5. Prévisualiser et installer la version soumise sur la montre avant de demander la publication.
6. Envoyer en révision Garmin et corriger toute remarque avant publication publique.

## Mise à jour ultérieure

Toujours repartir du même UUID d’application et signer avec la même clé développeur. Tester d’abord sur une application bêta à UUID séparé si une modification touche le format FIT, le stockage ou les échanges Hevy.
