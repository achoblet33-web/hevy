# Hevy pour Garmin Fenix 8

Application Connect IQ autonome de musculation pour `fenix847mm`, conçue pour le SDK 9.2.0 et le typage Monkey C niveau 2.

## Fonctions

- charge les 10 premières routines Hevy et conserve un cache hors ligne compact ;
- enregistre une activité Garmin de type entraînement de force ;
- active le capteur cardiaque afin que les données physiologiques natives alimentent le FIT ;
- écrit le poids (`Float`) et les répétitions (`UInt16`) comme champs FIT par tour ;
- prend en charge boutons physiques et zones tactiles relatives à l'écran ;
- sauvegarde chaque série dans un brouillon local ;
- met les séances terminées en file locale avant l'envoi à Hevy ;
- réessaie une séance en attente au lancement suivant ;
- produit des dates ISO 8601 UTC pour l'API Hevy.

## Configuration

1. Ouvrir les paramètres de l'application dans Garmin Connect, Connect IQ Store ou Garmin Express.
2. Renseigner **Clé API Hevy**. La clé n'est pas inscrite dans le code source.
3. Garder le téléphone connecté pour les échanges HTTP. Une routine déjà mise en cache reste lançable hors ligne.

## Commandes

Pendant une série :

- `START/ENTER` : pause ou reprise uniquement ;
- `LAP/BACK` : valider la série ;
- toucher en haut/bas à gauche : répétitions `+1/-1` ;
- toucher en haut/bas à droite : poids `+2,5/-2,5 kg` ;
- bouton tactile gauche : `LOG SET` ; bouton tactile droit : `FINISH`.

Pendant le repos :

- `LAP/BACK` ou bouton gauche : passer le repos ;
- toucher la moitié haute/basse : `+15/-15 s` ;
- `START/ENTER` : pause ou reprise.

Dans la préparation, `UP/DOWN` ou la zone centrale choisit une routine, `START` tactile la lance et `LAP/BACK` quitte l'application. Le bouton physique `START/ENTER` n'est jamais utilisé pour lancer une séance.

## Compiler

Le SDK Garmin Connect IQ et une clé développeur sont requis :

```sh
monkeyc -d fenix847mm -f monkey.jungle -o bin/Hevy.prg -y /chemin/developer_key.der -l 2 -O 2
```

Après stabilisation sur le simulateur, essayer `-l 3`. Le niveau 2 est conservé dans `monkey.jungle` afin que les réponses JSON hétérogènes de Hevy restent explicitement contrôlées et converties.

## Test conseillé

Chaque push sur `main` déclenche également `.github/workflows/garmin-ci.yml`. Le workflow effectue les contrôles statiques, génère une clé développeur éphémère et compile un fichier `Hevy.prg` pour `fenix847mm` avec le typage niveau 2.

1. Simuler une réponse `GET /v1/routines` puis couper la connexion et relancer l'app.
2. Valider plusieurs séries, mettre en pause, reprendre et terminer.
3. Vérifier dans le fichier FIT un tour par série avec les deux champs développeur.
4. Forcer un échec HTTP au résumé, relancer l'app, puis vérifier que la file d'attente se vide.

Le dépôt ne contient ni clé API Hevy ni clé de signature Garmin. La permission `Sensor` complète les trois permissions demandées afin d'activer explicitement la fréquence cardiaque avant le démarrage du FIT.
