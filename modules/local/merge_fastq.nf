process MERGE_FASTQ {
    tag "$barcode"
    label 'process_single'
    container 'bash:5.2'

    publishDir(
        path: "${params.out_dir}/1_fastq_merge",
        mode: 'copy',
        saveAs: { it.replace('.merged.fastq.gz', '.fastq.gz') }
    )

    input:
    tuple val(barcode), path(fastq_files)

    output:
    tuple val(barcode), path("${barcode}.merged.fastq.gz")

    script:
    """
    #!/usr/local/bin/bash
    merged="${barcode}.merged.fastq.gz"
    : > "\$merged"
    for f in ${fastq_files}; do
        case "\$f" in
            *.gz) cat "\$f" >> "\$merged" ;;
            *)    gzip -c "\$f" >> "\$merged" ;;
        esac
    done
    """
}
