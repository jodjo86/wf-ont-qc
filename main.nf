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
      nextflow run . --input <fastq_pass_dir> --watch_path   # launch alongside an in-progress MinKNOW run

    Required:
      --input                Directory containing one sub-directory per barcode
                              (e.g. fastq_pass/barcode01/*.fastq.gz), as produced by
                              MinKNOW/Dorado basecalling.

    Optional:
      --watch_path                           Watch --input for new FASTQ files as MinKNOW/Dorado
                                              write them, so the pipeline can be started while the
                                              run is still going. Barcodes are merged/QC'd once
                                              MinKNOW writes final_summary*.txt next to --input (the
                                              run has finished); to stop watching earlier, create a
                                              file named STOP.<nextflow session id>.fastq next to
                                              --input (default: ${params.watch_path})
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

// Return the single file directly under `dir` matching `regex`, or null if there isn't exactly one.
def findOne(dir, regex) {
    def matches = dir.listFiles()?.findAll { it.name ==~ regex }
    return (matches && matches.size() == 1) ? matches[0] : null
}

// Extract protocol_group_id from a MinKNOW/Dorado final_summary*.txt file.
def protocolGroupId(fs_file) {
    def line = fs_file.readLines().find { it.startsWith('protocol_group_id=') }
    if (!line) {
        error "no protocol_group_id field found in ${fs_file}; use --run_name to specify the run name explicitly."
    }
    line.split('=', 2)[1].trim()
}

// Resolve the sequencing_summary*.txt file to use, as a channel: from --sequencing_summary if
// given, by scanning `run_dir` for a single match, or (with --watch_path) by waiting for MinKNOW
// to write it once the run finishes.
def resolveSequencingSummary(run_dir) {
    if (params.sequencing_summary) {
        return Channel.value(file(params.sequencing_summary, checkIfExists: true))
    }
    def found = findOne(run_dir, /sequencing_summary.*\.txt/)
    if (found) {
        return Channel.value(found)
    }
    if (params.watch_path) {
        log.info "Waiting for MinKNOW to write sequencing_summary*.txt in ${run_dir}..."
        return Channel.watchPath("${run_dir}/sequencing_summary*.txt").first()
    }
    exit 1, "ERROR: expected exactly one sequencing_summary*.txt in ${run_dir}; " +
             "use --sequencing_summary to specify it explicitly."
}

// Resolve the run name for the run-level report, as a channel: from --run_name if given, by
// reading protocol_group_id from final_summary*.txt in `run_dir`, or (with --watch_path) by
// waiting for MinKNOW to write it once the run finishes.
def resolveRunName(run_dir, final_summary_file) {
    if (params.run_name) {
        return Channel.value(params.run_name)
    }
    if (final_summary_file) {
        return Channel.value(protocolGroupId(final_summary_file))
    }
    if (params.watch_path) {
        log.info "Waiting for MinKNOW to write final_summary*.txt in ${run_dir}..."
        return Channel.watchPath("${run_dir}/final_summary*.txt").first().map { protocolGroupId(it) }
    }
    exit 1, "ERROR: expected exactly one final_summary*.txt in ${run_dir}; " +
             "use --run_name to specify the run name explicitly."
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

    def run_dir            = file(params.input).getParent()
    def fastq_glob         = "${params.input}/barcode*/*.{fastq,fq,fastq.gz,fq.gz}"
    def final_summary_file = findOne(run_dir, /final_summary.*\.txt/)

    if (params.watch_path && !final_summary_file) {
        // The run isn't finished yet: watch --input for new FASTQ files as MinKNOW/Dorado write
        // them, and stop as soon as MinKNOW writes final_summary*.txt (or the user creates the
        // STOP sentinel), the same signal used below to know the run-level files are ready too.
        def stop_filename = "STOP.${workflow.sessionId}.fastq"
        log.info "Watching ${params.input} for new FASTQ files as MinKNOW writes them."
        log.info "Processing starts automatically once MinKNOW writes final_summary*.txt in " +
                  "${run_dir}; to stop watching earlier, create ${run_dir}/${stop_filename}"

        ch_watched = Channel
            .watchPath("${params.input}/**")
            .filter { it.name ==~ /.*\.(fastq|fq)(\.gz)?$/ }
            .mix(
                Channel.watchPath("${run_dir}/final_summary*.txt"),
                Channel.watchPath("${run_dir}/${stop_filename}")
            )
            .until { it.name ==~ /final_summary.*\.txt/ || it.name == stop_filename }

        ch_fastq_files = Channel.fromPath(fastq_glob).concat(ch_watched)
    } else {
        ch_fastq_files = Channel.fromPath(fastq_glob, checkIfExists: true)
    }

    ch_barcodes = ch_fastq_files
        .map { fq -> tuple(fq.getParent().getName(), fq) }
        .groupTuple()

    MERGE_FASTQ(ch_barcodes)
    FASTPLONG(MERGE_FASTQ.out)

    FASTPLONG_SUMMARY(
        resolveSequencingSummary(run_dir),
        resolveRunName(run_dir, final_summary_file)
    )
}
