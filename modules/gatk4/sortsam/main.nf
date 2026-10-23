process GATK4_SORTSAM {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/gatk4:4.6.2.0--py310hdfd78af_1'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("${meta.id}.bam"), path("${meta.id}.bai"), emit: bam
    tuple val("${task.process}"), val('gatk4'), eval("gatk --version 2>&1 | sed -n 's/^The Genome Analysis Toolkit (GATK) v//p'"), topic: versions

    script:
    def avail_mem = Math.max(1, (task.memory.toGiga() * 0.8).intValue())
    """
    gatk --java-options "-Xmx${avail_mem}g" SortSam \\
        --INPUT ${bam} \\
        --OUTPUT ${meta.id}.bam \\
        --SORT_ORDER coordinate \\
        --CREATE_INDEX true \\
        --TMP_DIR .
    """
}
