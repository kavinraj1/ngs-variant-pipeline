process GATK4_HAPLOTYPECALLER {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/gatk4:4.6.2.0--py310hdfd78af_1'

    input:
    tuple val(meta), path(bam), path(bai)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fai)
    tuple val(meta4), path(dict)
    path intervals

    output:
    tuple val(meta), path('*.vcf.gz'), path('*.vcf.gz.tbi'), emit: vcf
    tuple val("${task.process}"), val('gatk4'), eval("gatk --version 2>&1 | sed -n 's/^The Genome Analysis Toolkit (GATK) v//p'"), topic: versions

    script:
    def avail_mem = Math.max(1, (task.memory.toGiga() * 0.8).intValue())
    def interval_arg = intervals ? "--intervals ${intervals}" : ''
    """
    gatk --java-options "-Xmx${avail_mem}g" HaplotypeCaller \\
        --input ${bam} \\
        --reference ${fasta} \\
        --output ${meta.id}.vcf.gz \\
        ${interval_arg} \\
        --native-pair-hmm-threads ${task.cpus} \\
        --tmp-dir .
    """
}
