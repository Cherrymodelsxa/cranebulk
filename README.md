# CraneBulk

Tweak jailbreak qui ajoute la **création et la suppression groupées de conteneurs
[Crane](https://havoc.app/package/crane)** au menu d'appui long des icônes.

Appui long sur Instagram → *Créer conteneurs Crane* → préfixe `Insta`, quantité `50`
→ 50 conteneurs `Insta 1` … `Insta 50` créés d'un coup. Et *Effacer conteneurs Crane*
supprime tout en une fois, en conservant toujours le conteneur par défaut.

---

## Prérequis

| | |
|---|---|
| iOS | 15.0 minimum. Testé comme cible : iPhone X, iOS 16.7.16, Dopamine |
| Jailbreak | Rootless (Dopamine, Fugu15 Max) ou rootful |
| Dépendance | **Crane, version complète** ([Havoc](https://havoc.app/package/crane), payant) |

> **Crane Lite ne fonctionne pas.** L'édition gratuite n'expose pas l'API `libCrane`,
> et c'est précisément cette API que CraneBulk utilise. Le tweak le détecte et
> affiche un message clair au lieu d'échouer en silence.

---

## Installation pour les utilisateurs

Ajouter le dépôt dans Sileo :

```
https://cherrymodelsxa.github.io/cranebulk/
```

Sources → **+** → coller l'URL → chercher **CraneBulk** → Installer.

---

## Publier ton propre dépôt

### 1. Créer le repo GitHub

```bash
gh repo create cranebulk --public --source=. --push
```

Sans la CLI `gh` : créer le repo sur github.com, puis

```bash
git remote add origin https://github.com/<TON_PSEUDO>/cranebulk.git && git push -u origin main
```

### 2. Remplacer le pseudo dans les URLs

Le projet est pré-rempli avec `blaxk`. Pour le changer partout d'un coup :

```bash
./scripts/configure.sh <TON_PSEUDO>
```

### 3. Activer GitHub Pages

Repo → **Settings** → **Pages** → Source : `Deploy from a branch`,
branche `main`, dossier **`/docs`** → Save.

L'URL du dépôt devient `https://<TON_PSEUDO>.github.io/cranebulk/`.

### 4. Autoriser le workflow à écrire

Repo → **Settings** → **Actions** → **General** → *Workflow permissions* →
**Read and write permissions** → Save.

Sans ça, le job qui met à jour l'index APT échouera au `git push`.

### 5. Lancer le build

Chaque push sur `main` déclenche la compilation, régénère l'index APT dans
`docs/` et le commit. Le `.deb` est aussi disponible en artefact du workflow.

Déclenchement manuel : onglet **Actions** → *Build et publication du dépôt* →
**Run workflow**.

---

## Compiler en local

Nécessite [Theos](https://theos.dev) avec le SDK iOS 16.5 et la toolchain.
Sur Windows, tout se passe dans WSL.

```bash
make package FINALPACKAGE=1
```

Le paquet sort dans `packages/`. Pour l'installer directement sur un appareil
accessible en SSH :

```bash
make package install FINALPACKAGE=1 THEOS_DEVICE_IP=192.168.1.42
```

Puis régénérer l'index du dépôt :

```bash
./scripts/build-repo.sh
```

---

## Structure

```
CraneBulk/
├── Tweak.x                     Hook SpringBoard, injection des entrées de menu
├── Sources/
│   ├── libCrane.h              API publique de Crane (opa334/Crane-Resources)
│   ├── CBCraneBridge.{h,m}     Accès sûr à Crane, détection du conteneur par défaut
│   ├── CBBulkOperations.{h,m}  Moteur des opérations groupées
│   ├── CBFlowController.{h,m}  Enchaînement formulaire → progression → résultat
│   ├── CBUI.{h,m}              Présentation d'alertes depuis SpringBoard
│   └── CBLocalization.{h,m}    Chaînes FR / EN
├── Makefile, control, CraneBulk.plist
├── scripts/build-repo.sh       Génération de l'index APT
├── docs/                       Racine GitHub Pages = racine du dépôt Sileo
└── .github/workflows/build.yml Compilation et publication automatiques
```

---

## Choix techniques

**Pas de liaison statique avec `libcrane`.** Un tweak lié en dur contre une
bibliothèque absente peut empêcher SpringBoard de démarrer. `CraneManager` est
donc résolue au runtime via `NSClassFromString`, avec `dlopen` en secours. Sans
Crane, le tweak reste inerte au lieu de casser l'appareil.

**Opérations sur le main thread, une par tour de runloop.** La thread-safety de
`CraneManager` n'est pas documentée, et Crane met à jour l'interface de
SpringBoard quand les conteneurs changent. Rendre la main entre chaque opération
garde SpringBoard réactif et permet l'annulation.

**Un seul rechargement de l'application, en fin de parcours.** Appeler
`reloadApplicationWithIdentifier:` à chaque itération relancerait l'application
cible des dizaines de fois.

**Refus de supprimer en cas de doute.** Le conteneur par défaut est identifié par
trois stratégies successives. Si aucune n'aboutit, **aucune suppression n'est
effectuée** et un diagnostic est écrit dans `/tmp/cranebulk-diagnostic.txt`.

---

## À valider sur appareil

Ce code n'a pas encore tourné sur un iPhone. Deux points demandent une
vérification au premier test, et le tweak est écrit pour échouer proprement
plutôt que dangereusement sur chacun.

1. **Le hook du menu.** `Tweak.x` intercepte
   `-[SBIconView contextMenuInteraction:configurationForMenuAtLocation:]`.
   Si SpringBoard 16.7 expose cette méthode ailleurs, les entrées n'apparaissent
   pas et le `%ctor` l'écrit dans les logs :
   ```bash
   # sur l'appareil, en SSH
   log stream --predicate 'eventMessage CONTAINS "CraneBulk"'
   ```

2. **La détection du conteneur par défaut.** Si la suppression groupée répond
   que le conteneur par défaut n'a pas pu être identifié, récupérer
   `/tmp/cranebulk-diagnostic.txt` : il contient les identifiants réels et les
   réglages Crane de l'application, de quoi corriger
   `defaultContainerIdentifierForApplication:` en une ligne.

---

## Crédits

- API `libCrane` et tweak Crane : [opa334](https://github.com/opa334) —
  [Crane-Resources](https://github.com/opa334/Crane-Resources)
- CraneBulk n'est pas affilié à Crane ni à son auteur.
