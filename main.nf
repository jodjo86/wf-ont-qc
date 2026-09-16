#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { MERGE_FASTQ } from './modules/local/merge_fastq'
include { FASTPLONG   } from './modules/local/fastplong'

def helpMessage() {
    log.info """
    QC_ONT — merge ONT FASTQ by barcode, then QC/preprocess with fastplong.

    Usage:
      nextflow run . --input <fastq_pass_dir> [--out_dir output]

    Required:
      --input            Directory containing one sub-directory per barcode
                          (e.g. fastq_pass/barcode01/*.fastq.gz), as produced by
                          MinKNOW/Dorado basecalling.

    Optional:
      --out_dir          Output directory (default: ${params.out_dir})
      --fastplong_args   Arguments passed to fastplong (default:
                          '${params.fastplong_args}')

    Output (under --out_dir), and nothing else:
      1_fastq_merge/     one merged FASTQ per barcode
      2_fastq_filtered/  one fastplong-filtered FASTQ per barcode
      QC/                one fastplong JSON report per barcode
    """.stripIndent()
}

workflow {
    if (params.help) {
        helpMessage()
        exit 0
    }

    if (!params.input) {
        helpMessage()
        exit 1, "ERROR: --input is required (directory containing barcode* sub-directories of FASTQ files)."
    }

    ch_barcodes = Channel
        .fromPath("${params.input}/barcode*", type: 'dir', checkIfExists: true)
        .map { dir ->
            def fq = dir.listFiles().findAll { it.name ==~ /.*\.(fastq|fq)(\.gz)?$/ }
            tuple(dir.name, fq)
        }
        .filter { barcode, fq -> fq }

    MERGE_FASTQ(ch_barcodes)
    FASTPLONG(MERGE_FASTQ.out)
}
