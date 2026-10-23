process FASTP {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/fastp:1.4.0--h43da1c4_0'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*.trimmed.fastq.gz'), emit: reads
    tuple val(meta), path('*.fastp.json'),       emit: json
    tuple val(meta), path('*.fastp.html'),       emit: html
    tuple val("${task.process}"), val('fastp'), eval("fastp --version 2>&1 | sed 's/^fastp //'"), topic: versions

    script:
    """
    fastp \\
        --in1 ${reads[0]} \\
        --in2 ${reads[1]} \\
        --out1 ${meta.id}_R1.trimmed.fastq.gz \\
        --out2 ${meta.id}_R2.trimmed.fastq.gz \\
        --detect_adapter_for_pe \\
        --thread ${task.cpus} \\
        --json ${meta.id}.fastp.json \\
        --html ${meta.id}.fastp.html
    """
}
