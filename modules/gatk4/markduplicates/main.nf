process GATK4_MARKDUPLICATES {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/gatk4:4.6.2.0--py310hdfd78af_1'

    input:
    tuple val(meta), path(sam)

    output:
    tuple val(meta), path('*.markdup.bam'),         emit: bam
    tuple val(meta), path('*.markdup.metrics.txt'), emit: metrics
    tuple val("${task.process}"), val('gatk4'), eval("gatk --version 2>&1 | sed -n 's/^The Genome Analysis Toolkit (GATK) v//p'"), topic: versions

    script:
    def avail_mem = Math.max(1, (task.memory.toGiga() * 0.8).intValue())
    // Aligner output is grouped by read name, so duplicates are marked on whole templates,
    // including their secondary and supplementary alignments, before coordinate sorting.
    """
    gatk --java-options "-Xmx${avail_mem}g" MarkDuplicates \\
        --INPUT ${sam} \\
        --OUTPUT ${meta.id}.markdup.bam \\
        --METRICS_FILE ${meta.id}.markdup.metrics.txt \\
        --ASSUME_SORT_ORDER queryname \\
        --TMP_DIR .
    """
}
