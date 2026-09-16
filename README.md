# QC_ONT

Workflow Nextflow (style EPI2ME, exécution via Docker) pour préparer et contrôler la qualité de
données Nanopore (ONT) démultiplexées par barcode.

Le workflow effectue deux étapes :

1. **Fusion des FASTQ par barcode** — tous les fichiers `.fastq`/`.fastq.gz` d'un même dossier
   `barcodeXX/` sont concaténés en un seul fichier `.fastq.gz`.
2. **Preprocessing / QC avec [fastplong](https://github.com/OpenGene/fastplong)** — filtrage
   qualité et longueur, puis génération d'un rapport JSON.

## Prérequis

- [Nextflow](https://www.nextflow.io/) (testé avec la 26.04.x)
- [Docker](https://www.docker.com/), avec l'utilisateur courant autorisé à l'utiliser
  (`docker ps` doit fonctionner sans `sudo`)

Aucune installation locale de fastplong n'est nécessaire : les deux étapes tournent chacune dans
leur propre conteneur (`bash:5.2` pour la fusion, `quay.io/biocontainers/fastplong` pour le
QC), téléchargés automatiquement par Nextflow au premier lancement.

## Structure d'entrée attendue

Un dossier avec un sous-dossier par barcode, comme produit par MinKNOW/Dorado :

```
fastq_pass/
├── barcode01/
│   ├── xxx_0.fastq.gz
│   └── xxx_1.fastq.gz
├── barcode02/
│   └── xxx_0.fastq.gz
└── unclassified/        ← ignoré automatiquement (ne matche pas "barcode*")
```

## Utilisation

```bash
cd QC_ONT
nextflow run . --input /chemin/vers/fastq_pass --outdir output
```

Aide :

```bash
nextflow run . --help
```

### Paramètres

| Paramètre          | Défaut                                                                                                                                     | Description                                    |
|---------------------|---------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------|
| `--input`           | *(requis)*                                                                                                                                   | Dossier contenant les sous-dossiers `barcodeXX/` |
| `--outdir`          | `output`                                                                                                                                     | Dossier de sortie                                |
| `--fastplong_args`  | `--trim_front 20 --trim_tail 20 --disable_adapter_trimming --discard_chimeric_reads --mean_qual 14 --length_required 300 --length_limit 10000` | Arguments passés tels quels à `fastplong`        |

Exemple avec des arguments QC différents :

```bash
nextflow run . --input fastq_pass --outdir output \
  --fastplong_args '--trim_front 10 --trim_tail 10 --mean_qual 12 --length_required 200'
```

## Sortie

Le dossier `--outdir` contient exactement trois éléments, rien d'autre :

```
output/
├── 1_fastq_merge/       barcodeXX.fastq.gz   (FASTQ fusionné, 1 par barcode)
├── 2_fastq_filtered/    barcodeXX.fastq.gz   (FASTQ après fastplong, 1 par barcode)
└── QC/                  barcodeXX.json       (rapport fastplong, 1 par barcode)
```

Le rapport HTML généré par fastplong est produit dans le répertoire de travail Nextflow
(`work/`) mais n'est jamais copié dans `--outdir` : il n'est pas demandé dans la sortie finale.

## Fichiers du projet

```
QC_ONT/
├── main.nf                       point d'entrée du workflow
├── nextflow.config                paramètres par défaut, Docker, ressources par process
├── modules/local/
│   ├── merge_fastq.nf              process de fusion des FASTQ (container bash:5.2)
│   └── fastplong.nf                process de QC/filtrage (container biocontainers/fastplong)
├── fastplong.py                   script Python autonome (non utilisé par le workflow ;
│                                    conservé comme référence des arguments QC d'origine)
└── README.md
```

## Nettoyage

Nextflow conserve les résultats intermédiaires dans `work/` (utile pour le `-resume`). Une fois
les résultats validés dans `--outdir`, ce dossier peut être supprimé sans risque :

```bash
rm -rf work .nextflow.log* .nextflow
```
