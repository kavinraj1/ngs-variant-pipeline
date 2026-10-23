process SAMTOOLS_FAIDX {
    tag "${fasta.name}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/samtools:1.24--h9dcdb79_1'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path('*.fai'), emit: fai
    tuple val("${task.process}"), val('samtools'), eval("samtools --version | sed -n '1s/^samtools //p'"), topic: versions

    script:
    """
    samtools faidx ${fasta}
    """
}
