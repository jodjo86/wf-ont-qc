process FASTPLONG {
    tag "$barcode"
    label 'process_medium'
    container 'quay.io/biocontainers/fastplong:0.7.0--h43da1c4_0'

    publishDir("${params.out_dir}/2_fastq_filtered", mode: 'copy', pattern: '*.fastq.gz')
    publishDir("${params.out_dir}/QC",               mode: 'copy', pattern: '*.html')

    input:
    tuple val(barcode), path(merged_fastq)

    output:
    tuple val(barcode), path("${barcode}.fastq.gz"), emit: fastq
    tuple val(barcode), path("${barcode}.html"),     emit: html

    script:
    def disable_adapter_trimming = params.fastplong_disable_adapter_trimming ? '--disable_adapter_trimming' : ''
    def discard_chimeric_reads   = params.fastplong_discard_chimeric_reads   ? '--discard_chimeric_reads'   : ''
    """
    fastplong \\
        -i ${merged_fastq} \\
        -o ${barcode}.fastq.gz \\
        --html ${barcode}.html \\
        --thread ${task.cpus} \\
        --trim_front ${params.fastplong_trim_front} \\
        --trim_tail ${params.fastplong_trim_tail} \\
        --mean_qual ${params.fastplong_mean_qual} \\
        --length_required ${params.fastplong_length_required} \\
        --length_limit ${params.fastplong_length_limit} \\
        ${disable_adapter_trimming} \\
        ${discard_chimeric_reads}
    """
}
