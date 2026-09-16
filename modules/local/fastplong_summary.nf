process FASTPLONG_SUMMARY {
    label 'process_medium'
    container 'quay.io/biocontainers/fastplong:0.7.0--h43da1c4_0'

    publishDir(params.out_dir,               mode: 'copy', pattern: '*.html')
    publishDir("${params.out_dir}/QC",       mode: 'copy', pattern: '*.json')

    input:
    path sequencing_summary
    val  run_name

    output:
    path "${run_name}-report.html"
    path "${run_name}_fastplong.json"

    script:
    """
    fastplong \\
        --ont_summary ${sequencing_summary} \\
        --json "${run_name}_fastplong.json" \\
        --html "${run_name}-report.html"
    """
}
