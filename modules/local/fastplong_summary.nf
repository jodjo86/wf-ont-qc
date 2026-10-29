process FASTPLONG_SUMMARY {
    label 'process_medium'
    container 'quay.io/biocontainers/fastplong:0.7.0--h43da1c4_0'

    // Copied to out_dir too so EPI2ME Desktop displays the report at the end of the run.
    publishDir(params.out_dir, mode: 'copy', pattern: '*.html')
    publishDir(params.run_out_dir ?: file(params.input).getParent().resolve('output'), mode: 'copy', pattern: '*.html')

    input:
    path sequencing_summary
    val  run_name

    output:
    path "${run_name}-report.html"

    script:
    """
    fastplong \\
        --ont_summary ${sequencing_summary} \\
        --html "${run_name}-report.html"
    """
}
