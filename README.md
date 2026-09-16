# wf-ont-qc

Fusionne les FASTQ Nanopore par barcode et filtre la qualité/longueur avec
[fastplong](https://github.com/OpenGene/fastplong), qui produit aussi le
rapport de run.

1. **Fusion** — tous les `.fastq`/`.fastq.gz` d'un même dossier `barcodeXX/` sont
   concaténés en un seul fichier.
2. **QC / filtrage** — fastplong filtre par qualité et longueur, puis produit un
   rapport JSON par barcode.
3. **Rapport de run** — fastplong génère un rapport HTML unique à partir du
   `sequencing_summary.txt` du run (toutes stats confondues, tous barcodes).

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

| Paramètre                               | Défaut       | Description                                                            |
|------------------------------------------|--------------|-------------------------------------------------------------------------|
| `input`                                | *(requis)*   | Dossier contenant les sous-dossiers `barcodeXX/`                     |
| `out_dir`                              | `output`     | Dossier de sortie                                                     |
| `fastplong_trim_front`                 | `20`         | Bases coupées en début de read                                        |
| `fastplong_trim_tail`                  | `20`         | Bases coupées en fin de read                                          |
| `fastplong_disable_adapter_trimming`   | `true`       | Désactive le trimming d'adaptateurs                                   |
| `fastplong_discard_chimeric_reads`     | `true`       | Rejette les reads chimériques                                         |
| `fastplong_mean_qual`                  | `14`         | Qualité moyenne minimale pour garder un read                          |
| `fastplong_length_required`            | `300`        | Longueur minimale pour garder un read                                 |
| `fastplong_length_limit`               | `10000`      | Longueur maximale autorisée                                           |
| `sequencing_summary`                   | auto-détecté | Fichier `sequencing_summary*.txt` (sinon cherché à côté de `input`)   |
| `run_name`                             | auto-détecté | Nom du run utilisé dans le rapport (sinon le nom du dossier parent de `input`) |

## Sortie

```
output/
├── 1_fastq_merge/               barcodeXX.fastq.gz   (FASTQ fusionné, 1 par barcode)
├── 2_fastq_filtered/            barcodeXX.fastq.gz   (FASTQ filtré par fastplong, 1 par barcode)
├── QC/                          barcodeXX.json        (rapport fastplong, 1 par barcode)
└── <run_name>-report.html       rapport HTML du run (à partir de sequencing_summary)
```

Le rapport HTML par barcode généré par l'étape de filtrage n'est pas copié dans
`out_dir` (seul le JSON par barcode l'est) ; seul le rapport de run (étape 3)
produit un HTML publié.
