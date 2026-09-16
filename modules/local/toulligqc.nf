process TOULLIGQC {
    label 'process_medium'
    container 'quay.io/biocontainers/toulligqc:2.9.1--pyhdfd78af_0'

    publishDir(params.out_dir, mode: 'copy')

    input:
    path sequencing_summary
    val  barcode_range
    val  run_name

    output:
    path "${run_name}-report.html"

    script:
    """
    toulligqc \\
        --report-name "${run_name}" \\
        --barcoding \\
        --sequencing-summary-source ${sequencing_summary} \\
        --html-report-path "${run_name}-report.html" \\
        --barcodes ${barcode_range} \\
        --force
    """
}
