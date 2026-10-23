process FASTQC {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*.html'), emit: html
    tuple val(meta), path('*.zip'),  emit: zip
    tuple val("${task.process}"), val('fastqc'), eval("fastqc --version | sed 's/^FastQC v//'"), topic: versions

    script:
    """
    fastqc --threads ${task.cpus} --quiet ${reads}
    """
}
