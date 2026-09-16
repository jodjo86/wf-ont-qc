process FASTPLONG {
    tag "$barcode"
    label 'process_medium'
    container 'quay.io/biocontainers/fastplong:0.7.0--h43da1c4_0'

    publishDir("${params.outdir}/2_fastq_filtered", mode: 'copy', pattern: '*.fastq.gz')
    publishDir("${params.outdir}/QC",               mode: 'copy', pattern: '*.json')

    input:
    tuple val(barcode), path(merged_fastq)

    output:
    tuple val(barcode), path("${barcode}.fastq.gz"), emit: fastq
    tuple val(barcode), path("${barcode}.json"),     emit: json

    script:
    """
    fastplong \\
        -i ${merged_fastq} \\
        -o ${barcode}.fastq.gz \\
        --json ${barcode}.json \\
        --html ${barcode}.discard.html \\
        --thread ${task.cpus} \\
        ${params.fastplong_args}
    """
}
