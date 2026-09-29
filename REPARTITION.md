# Répartition des commits pour le nouveau dépôt

Fichier temporaire : on le supprime une fois la migration terminée. Il n'est pas à copier dans le nouveau dépôt.

## Le principe

Tout le projet est terminé dans ce dépôt-ci (l'ancien). On le recrée dans un **nouveau dépôt**, en trois parties, une par personne. Chacun copie ses fichiers depuis l'ancien dépôt et les pousse en plusieurs commits, sous son propre nom.

| Partie | Qui | Contenu | Commits |
|---|---|---|---|
| 1 | Pierre | Données, enrichissement Census, exploration | 5 |
| 2 | Lilou | Préparation de l'échantillon, modèles, robustesse | 3 |
| 3 | Fanny | Application Shiny et README | 5 |

Les rôles peuvent être échangés, mais **l'ordre des parties, lui, compte** :

- la partie 2 utilise les données de la partie 1 ;
- l'application de la partie 3 lit les résultats de la partie 2.

On pousse donc dans l'ordre 1 → 2 → 3. Les parties ne partagent aucun fichier : pousser en parallèle marche aussi, à condition de faire `git pull --rebase` juste avant chaque `git push`.

## Avant de commencer

**Pierre** crée le nouveau dépôt sur GitHub **vide** : sans README, sans .gitignore, sans licence. Il ajoute Lilou et Fanny comme collaboratrices (Settings → Collaborators).

**Chacun**, sur sa machine, dans Git Bash :

```bash
# 1. Récupérer l'ancien dépôt (la source des fichiers), s'il n'est pas déjà cloné
git clone https://github.com/pierridotite/mate-choice-social-reproduction.git ancien

# 2. Cloner le nouveau dépôt (remplacer l'adresse)
git clone https://github.com/<compte>/<nouveau-depot>.git nouveau

# 3. Signer ses commits à son nom, dans le nouveau dépôt seulement
cd nouveau
git config user.name "Prénom Nom"
git config user.email "adresse@utilisee-sur-github"

# 4. Deux raccourcis pour la suite : les chemins des deux dossiers et une fonction de copie
ANCIEN="$(cd ../ancien && pwd)"
NOUVEAU="$(pwd)"
copier() { (cd "$ANCIEN" && cp -r --parents "$@" "$NOUVEAU"); }
```

`copier` recopie des fichiers ou des dossiers de l'ancien dépôt vers le nouveau, au même emplacement. Exemple : `copier R/commun.R` crée `R/commun.R` dans le nouveau dépôt.

À chaque commit, la démarche est la même :

1. copier les fichiers ;
2. vérifier avec `git status` que ce sont les bons ;
3. faire `git add` et `git commit`.

On ne pousse qu'à la fin de sa partie.

## Partie 1 — Pierre : données et exploration

Les données brutes, leur enrichissement avec le Census, la fiche Kaggle, la charte graphique commune et l'analyse exploratoire.

```bash
# Commit 1 : structure du projet
copier .gitignore mate-choice-social-reproduction.Rproj slides/.gitkeep data-raw/README.md data-raw/speed_dating.csv
git add -A && git commit -m "Set up project structure"

# Commit 2 : jointure avec le Census et jeu de données enrichi
copier R/01_jointure_census.R data
git add -A && git commit -m "Add Census enrichment of the dataset"

# Commit 3 : fiche du jeu de données publiée sur Kaggle
copier kaggle
git add -A && git commit -m "Add Kaggle dataset description"

# Commit 4 : charte graphique, formats et libellés partagés par tous les scripts
copier R/commun.R
git add -A && git commit -m "Add shared chart theme, formats and labels"

# Commit 5 : analyse exploratoire, ses figures et son compte rendu
copier R/02_exploration.R exploration.md outputs/exploration
git add -A && git commit -m "Add exploratory data analysis"

git push
```

**Vérification** : `Rscript R/02_exploration.R` doit tourner sans erreur et régénérer les 8 figures de `outputs/exploration/`.

## Partie 2 — Lilou : préparation, modèles, robustesse

L'échantillon d'analyse, les régressions logistiques mixtes M1 à M4 (réponse à la problématique) et les tests de robustesse. Les fichiers `.rds` sont les résultats précalculés que l'application charge.

```bash
git pull   # récupérer la partie 1

# Commit 1 : variables dérivées (écart de revenu, terciles...) et échantillon d'analyse
copier R/03_preparation.R outputs/dates.rds outputs/participants.rds
git add -A && git commit -m "Add analysis dataset preparation"

# Commit 2 : modèles M1 à M4, figures et compte rendu
copier R/04_modeles.R modeles.md outputs/modeles outputs/modeles.rds
git add -A && git commit -m "Add mixed logistic models of the yes decision"

# Commit 3 : robustesse (variantes de l'écart social, préférence pour le statut)
copier R/05_robustesse.R robustesse.md outputs/robustesse outputs/robustesse.rds
git add -A && git commit -m "Add robustness checks"

git pull --rebase && git push
```

**Vérification** : `Rscript R/03_preparation.R` puis `Rscript R/04_modeles.R` (environ 2 minutes) doivent tourner sans erreur.

## Partie 3 — Fanny : application Shiny et README

L'application, avec ses deux onglets : « Découvrir les données » (cinq graphiques interactifs) et « Prédire un match ». Puis le README, qui décrit tout le projet et vient donc en dernier.

```bash
git pull   # récupérer les parties 1 et 2

# Commit 1 : chargement des données et dictionnaire des variables
copier app/fonctions/donnees.R
git add -A && git commit -m "Add app data layer and variable dictionary"

# Commit 2 : les cinq graphiques de l'onglet « Découvrir les données »
copier app/fonctions/decouverte.R app/www/style.css
git add -A && git commit -m "Add data discovery charts"

# Commit 3 : modèles de l'onglet « Prédire un match »
copier app/fonctions/prediction.R
git add -A && git commit -m "Add match prediction models"

# Commit 4 : l'application elle-même (global, interface, serveur)
copier app/global.R app/ui.R app/server.R
git add -A && git commit -m "Add Shiny app"

# Commit 5 : README du projet
copier README.md
git add -A && git commit -m "Add project README"

git pull --rebase && git push
```

**Vérification** : depuis la racine du dépôt, `Rscript -e 'shiny::runApp("app")'` doit ouvrir l'application ; elle met environ 5 secondes à démarrer.

## À la fin

N'importe qui lance, depuis le nouveau dépôt, cette commande pour comparer les deux dépôts :

```bash
git pull
diff <(cd "$ANCIEN" && git ls-files | sort) <(git ls-files | sort)
```

La seule différence attendue est `REPARTITION.md`, présent uniquement dans l'ancien dépôt. Ensuite, on supprime ce fichier de l'ancien dépôt (ou l'ancien dépôt entier, s'il ne sert plus).

Un dernier point : une fois le dépôt définitif connu, penser à mettre à jour l'adresse GitHub écrite dans l'onglet « À propos » de l'application (`app/ui.R`) et dans `kaggle/`.
