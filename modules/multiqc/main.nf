process MULTIQC {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/multiqc:1.35--pyhdfd78af_2'

    input:
    path qc_files, stageAs: 'qc/*'
    path config

    output:
    path 'multiqc_report.html', emit: report
    path 'multiqc_report_data', emit: data

    script:
    """
    multiqc --force --config ${config} --filename multiqc_report.html qc/
    """
}
