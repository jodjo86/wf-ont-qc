#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { MERGE_FASTQ       } from './modules/local/merge_fastq'
include { FASTPLONG         } from './modules/local/fastplong'
include { FASTPLONG_SUMMARY } from './modules/local/fastplong_summary'

def helpMessage() {
    log.info """
    QC_ONT — merge ONT FASTQ by barcode, QC/preprocess with fastplong, and
    produce a run-level fastplong summary report.

    Usage:
      nextflow run . --input <fastq_pass_dir> [--out_dir output]

    Required:
      --input                Directory containing one sub-directory per barcode
                              (e.g. fastq_pass/barcode01/*.fastq.gz), as produced by
                              MinKNOW/Dorado basecalling.

    Optional:
      --out_dir                              Output directory (default: ${params.out_dir})
      --fastplong_trim_front                 Bases trimmed from read start (default: ${params.fastplong_trim_front})
      --fastplong_trim_tail                  Bases trimmed from read end (default: ${params.fastplong_trim_tail})
      --fastplong_disable_adapter_trimming   Disable adapter trimming (default: ${params.fastplong_disable_adapter_trimming})
      --fastplong_discard_chimeric_reads     Discard chimeric reads (default: ${params.fastplong_discard_chimeric_reads})
      --fastplong_mean_qual                  Minimum mean quality to keep a read (default: ${params.fastplong_mean_qual})
      --fastplong_length_required            Minimum read length to keep a read (default: ${params.fastplong_length_required})
      --fastplong_length_limit               Maximum read length allowed (default: ${params.fastplong_length_limit})
      --sequencing_summary                   Path to the MinKNOW/Dorado sequencing_summary*.txt
                                              file (default: auto-detected next to --input, i.e.
                                              in its parent directory)
      --run_name                             Name used for the run-level report (default: the
                                              protocol_group_id read from final_summary*.txt
                                              next to --input)

    Output (under --out_dir), and nothing else:
      1_fastq_merge/               one merged FASTQ per barcode
      2_fastq_filtered/            one fastplong-filtered FASTQ per barcode
      QC/                          one fastplong HTML report per barcode
      <run_name>-report.html       fastplong run summary report (from sequencing_summary)
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

    def run_dir = file(params.input).getParent()

    def run_name = params.run_name
    if (!run_name) {
        def fs_matches = run_dir.listFiles()?.findAll { it.name ==~ /final_summary.*\.txt/ }
        if (!fs_matches || fs_matches.size() != 1) {
            exit 1, "ERROR: expected exactly one final_summary*.txt in ${run_dir} " +
                     "(found ${fs_matches?.size() ?: 0}); use --run_name to specify the run name explicitly."
        }
        def line = fs_matches[0].readLines().find { it.startsWith('protocol_group_id=') }
        if (!line) {
            exit 1, "ERROR: no protocol_group_id field found in ${fs_matches[0]}; " +
                     "use --run_name to specify the run name explicitly."
        }
        run_name = line.split('=', 2)[1].trim()
    }

    def seq_summary
    if (params.sequencing_summary) {
        seq_summary = file(params.sequencing_summary, checkIfExists: true)
    } else {
        def matches = run_dir.listFiles()?.findAll { it.name ==~ /sequencing_summary.*\.txt/ }
        if (!matches || matches.size() != 1) {
            exit 1, "ERROR: expected exactly one sequencing_summary*.txt in ${run_dir} " +
                     "(found ${matches?.size() ?: 0}); use --sequencing_summary to specify it explicitly."
        }
        seq_summary = matches[0]
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

    FASTPLONG_SUMMARY(seq_summary, run_name)
}
