# wf-ont-qc

Fusionne les FASTQ Nanopore par barcode, filtre la qualité/longueur avec
[fastplong](https://github.com/OpenGene/fastplong), et produit un rapport de run
avec [toulligQC](https://github.com/GenomiqueENS/toulligqc).

1. **Fusion** — tous les `.fastq`/`.fastq.gz` d'un même dossier `barcodeXX/` sont
   concaténés en un seul fichier.
2. **QC / filtrage** — fastplong filtre par qualité et longueur, puis produit un
   rapport JSON par barcode.
3. **Rapport de run** — toulligQC génère un rapport HTML unique à partir du
   `sequencing_summary.txt` du run, couvrant tous les barcodes détectés.

## Entrée

Un dossier avec un sous-dossier par barcode, comme produit par MinKNOW/Dorado,
avec le `sequencing_summary*.txt` du run dans le dossier parent :

```
20260826_.../
├── sequencing_summary_FBG66482_91a28fca.txt
└── fastq_pass/            ← c'est ce dossier qu'on passe à --input
    ├── barcode01/
    │   ├── xxx_0.fastq.gz
    │   └── xxx_1.fastq.gz
    ├── barcode02/
    │   └── xxx_0.fastq.gz
    └── unclassified/        ← ignoré (ne matche pas "barcode*")
```

## Paramètres principaux

| Paramètre              | Défaut      | Description                                              |
|-------------------------|-------------|-----------------------------------------------------------|
| `input`                 | *(requis)*  | Dossier contenant les sous-dossiers `barcodeXX/`           |
| `out_dir`               | `output`    | Dossier de sortie                                          |
| `fastplong_args`        | voir schéma | Arguments passés tels quels à `fastplong`                  |
| `sequencing_summary`    | auto-détecté | Fichier `sequencing_summary*.txt` (sinon cherché à côté de `input`) |
| `run_name`              | auto-détecté | Nom du run utilisé dans le rapport toulligQC (sinon le nom du dossier parent de `input`) |

La plage de barcodes passée à toulligQC (`--barcodes barcodeXX:barcodeYY`) est
calculée automatiquement à partir des dossiers `barcodeXX/` réellement présents
dans `input` — rien à ajuster manuellement.

## Sortie

```
output/
├── 1_fastq_merge/                     barcodeXX.fastq.gz   (FASTQ fusionné, 1 par barcode)
├── 2_fastq_filtered/                  barcodeXX.fastq.gz   (FASTQ filtré par fastplong, 1 par barcode)
├── QC/                                barcodeXX.json        (rapport fastplong, 1 par barcode)
└── wf-ont-qc-<run_name>-report.html   rapport toulligQC du run (tous barcodes)
```

Le rapport HTML de fastplong n'est pas copié dans `out_dir` (seul le JSON l'est).
