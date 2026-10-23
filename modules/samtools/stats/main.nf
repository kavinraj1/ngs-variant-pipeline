process SAMTOOLS_STATS {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/samtools:1.24--h9dcdb79_1'

    input:
    tuple val(meta), path(bam), path(bai)
    tuple val(meta2), path(fasta)

    output:
    tuple val(meta), path('*.stats'), emit: stats
    tuple val("${task.process}"), val('samtools'), eval("samtools --version | sed -n '1s/^samtools //p'"), topic: versions

    script:
    """
    samtools stats --threads ${task.cpus} --reference ${fasta} ${bam} > ${meta.id}.stats
    """
}
