# wf-ont-qc

Pipeline Nextflow (DSL2) : fusionne les FASTQ Nanopore par barcode, filtre
qualité/longueur avec [fastplong](https://github.com/OpenGene/fastplong), et
produit un rapport de run à partir du `sequencing_summary` MinKNOW/Dorado.
Workflow perso importé dans EPI2ME Desktop (pas dans l'organisation officielle
`epi2me-labs`). Dépôt : https://github.com/jodjo86/wf-ont-qc

## Structure

```
main.nf                        workflow principal (résolution input/MinKNOW, orchestration)
modules/local/merge_fastq.nf   MERGE_FASTQ   — concatène les FASTQ d'un barcode
modules/local/fastplong.nf     FASTPLONG     — filtre qualité/longueur + rapport HTML par barcode
modules/local/fastplong_summary.nf  FASTPLONG_SUMMARY — rapport HTML de run (depuis sequencing_summary)
nextflow.config                manifest + params + docker + resources par label
nextflow_schema.json           généré à la main (pas nf-core), doit rester synchro avec params{} et l'aide de main.nf
```

Sortie sous `--out_dir` (rien d'autre) :
`1_fastq_merge/`, `2_fastq_filtered/`, `QC/`, `<run_name>-report.html`.

## Entrée attendue (structure MinKNOW/Dorado)

```
<run_dir>/
├── sequencing_summary_*.txt
├── final_summary_*.txt          ← écrit par MinKNOW seulement à la FIN du run
└── fastq_pass/                  ← c'est ce dossier qu'on passe à --input
    ├── barcode01/*.fastq.gz
    ├── barcode02/*.fastq.gz
    └── unclassified/            ← ignoré (ne matche pas "barcode*")
```

`--input` doit être le dossier `fastq_pass` (ou équivalent), pas `run_dir`.
`run_dir` = `file(params.input).getParent()` — c'est là que `main.nf` va
chercher `final_summary*.txt` (→ `run_name` via `protocol_group_id`) et
`sequencing_summary*.txt`, sauf si `--run_name`/`--sequencing_summary` sont
donnés explicitement.

## Mode temps réel (`--watch_path`)

Ajouté pour permettre de lancer le pipeline **pendant** qu'une run MinKNOW est
encore en cours (voir doc dans `main.nf`/`README.md`). Points clés à
respecter si on retouche cette logique :

- Le vrai signal de "run terminé" est l'apparition de `final_summary*.txt`
  dans `run_dir` — c'est MinKNOW qui l'écrit en dernier, une fois tous les
  fastq_pass finalisés. `main.nf` s'en sert à la fois pour arrêter le watcher
  de FASTQ (`.until{...}`) et pour déclencher la résolution de `run_name`.
- `resolveSequencingSummary()` / `resolveRunName()` renvoient des **Channels**
  (pas des valeurs synchrones) car en mode watch, ces fichiers n'existent pas
  encore au lancement — il faut donc que leur résolution soit paresseuse
  (`Channel.watchPath(...).first()`), sinon ça casse le mode watch.
- `Channel.watchPath("${params.input}/**")` ne peut pas voir `final_summary*.txt`
  (il est dans le dossier parent, pas dans `--input`) : c'est pourquoi il y a
  un `.mix()` avec un watcher séparé sur `run_dir`. Ne pas fusionner les deux
  glob en un seul sans repenser ce point.
- Si `final_summary*.txt` existe déjà au lancement (run déjà fini), le mode
  watch bascule automatiquement en scan classique (pas d'attente infinie).
- Pattern copié/adapté de l'idiome officiel EPI2ME
  (`epi2me-labs/wf-basecalling`, `lib/signal/ingress.nf`) : fichiers déjà
  présents + `Channel.watchPath(...).until{...}`, avec un fichier sentinelle
  `STOP.<session id>.fastq` pour arrêter tôt.

## Environnement de dev

`nextflow` et `java` ne sont **pas installés** dans cet environnement — pas
moyen de faire `nextflow run . -help` ou `nextflow config` en local pour
valider la syntaxe. Après une modif de `main.nf` :
1. Vérifier `nextflow_schema.json` avec `python3 -m json.tool` (JSON valide).
2. Vérifier que les accolades/parenthèses sont équilibrées.
3. Relire à la main — pas de linter Groovy/Nextflow disponible ici.
Le vrai test se fait via EPI2ME Desktop, installé sur cette machine
(`/home/minion/epi2melabs/`), qui embarque son propre Nextflow.

## EPI2ME Desktop — installation locale

- Dépôt source : `/home/minion/Documents/wf-ont-qc` (ce dépôt, avec remote
  `origin` = GitHub).
- Copie installée par EPI2ME Desktop (séparée du dépôt de dev) :
  `/home/minion/epi2melabs/workflows/jodjo86/wf-ont-qc/`
- Cache/metadata EPI2ME : `/home/minion/epi2melabs/workflows/.cache/jodjo86/wf-ont-qc/meta.json`
- Logs de l'appli : `/home/minion/epi2melabs/main.log`
- **EPI2ME Desktop ne relit pas automatiquement le dépôt de dev.** Pour tester
  une modif dans l'appli : push sur GitHub (`origin/main`), puis dans EPI2ME
  Desktop faire **Delete workflow** puis **Download workflow** à nouveau
  (voir section suivante — "check for update" ne suffit pas).

## IMPORTANT — versionner à chaque changement notable

Le bouton "check for update" d'EPI2ME Desktop pour un workflow importé depuis
GitHub (hors organisation `epi2me-labs`) fonctionne en comparant les **tags
git** du dépôt distant à la version installée. **Il ne détecte rien s'il n'y
a pas de tag.**

Preuve : `jodjo86/wf-ont-qc` n'a aucun tag (`git tag -l` vide, confirmé aussi
côté remote). Résultat observé dans `main.log` : pour passer de la version
1.0.1 à 1.1.0 dans EPI2ME, il a fallu un **Delete workflow + Download
workflow manuel** — jamais de vraie mise à jour détectée automatiquement. Les
workflows officiels (ex. `epi2me-labs/wf-aav-qc`), eux, sont installés avec
une référence versionnée type `epi2me-labs/wf-aav-qc/v1.3.1`, résolue depuis
un tag.

**Donc, à chaque changement mergé sur `main` qui doit être visible comme
nouvelle version dans EPI2ME Desktop :**
1. Bumper `manifest.version` dans `nextflow.config` (actuellement `1.1.0`).
2. Créer un tag git correspondant, préfixé `v` (convention ONT) :
   `git tag v<version> && git push origin v<version>`.
3. Idéalement, créer aussi une release GitHub sur ce tag.

Sans ça, l'utilisateur devra continuer à faire Delete+Download à la main dans
EPI2ME Desktop à chaque changement.
