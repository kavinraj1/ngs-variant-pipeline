process BCFTOOLS_STATS {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/bcftools:1.24--h118bc1c_4'

    input:
    tuple val(meta), path(vcf), path(tbi)

    output:
    tuple val(meta), path('*.bcftools_stats.txt'), emit: stats
    tuple val("${task.process}"), val('bcftools'), eval("bcftools --version | sed -n '1s/^bcftools //p'"), topic: versions

    script:
    """
    bcftools stats --apply-filters PASS ${vcf} > ${meta.id}.bcftools_stats.txt
    """
}
