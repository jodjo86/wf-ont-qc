# wf-ont-qc

Fusionne les FASTQ Nanopore par barcode et filtre la qualité/longueur avec
[fastplong](https://github.com/OpenGene/fastplong).

1. **Fusion** — tous les `.fastq`/`.fastq.gz` d'un même dossier `barcodeXX/` sont
   concaténés en un seul fichier.
2. **QC / filtrage** — fastplong filtre par qualité et longueur, puis produit un
   rapport JSON par barcode.

## Entrée

Un dossier avec un sous-dossier par barcode, comme produit par MinKNOW/Dorado :

```
fastq_pass/
├── barcode01/
│   ├── xxx_0.fastq.gz
│   └── xxx_1.fastq.gz
├── barcode02/
│   └── xxx_0.fastq.gz
└── unclassified/        ← ignoré (ne matche pas "barcode*")
```

## Paramètres principaux

| Paramètre          | Défaut   | Description                                      |
|---------------------|----------|---------------------------------------------------|
| `input`             | *(requis)* | Dossier contenant les sous-dossiers `barcodeXX/` |
| `out_dir`           | `output` | Dossier de sortie                                  |
| `fastplong_args`    | voir schéma | Arguments passés tels quels à `fastplong`       |

## Sortie

```
output/
├── 1_fastq_merge/       barcodeXX.fastq.gz   (FASTQ fusionné, 1 par barcode)
├── 2_fastq_filtered/    barcodeXX.fastq.gz   (FASTQ filtré par fastplong, 1 par barcode)
└── QC/                  barcodeXX.json       (rapport fastplong, 1 par barcode)
```

Le rapport HTML de fastplong n'est pas copié dans `out_dir` (seul le JSON l'est).
