process BWA_MEM {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/bwa:0.7.19--h577a1d6_1'

    input:
    tuple val(meta), path(reads)
    tuple val(meta2), path(index)

    output:
    // Unsorted but grouped by read name, which is what MarkDuplicates expects next.
    tuple val(meta), path('*.sam'), emit: sam
    tuple val("${task.process}"), val('bwa'), eval("bwa 2>&1 | sed -n 's/^Version: //p'"), topic: versions

    script:
    def read_group = "@RG\\tID:${meta.id}\\tSM:${meta.id}\\tLB:${meta.id}\\tPL:ILLUMINA"
    // -K fixes the batch size so output is identical regardless of thread count.
    // -Y soft-clips supplementary alignments, as in the GATK Best Practices.
    """
    INDEX=\$(find -L ${index}/ -name '*.amb' | sed 's/\\.amb\$//')

    bwa mem \\
        -t ${task.cpus} \\
        -K 100000000 \\
        -Y \\
        -R '${read_group}' \\
        \$INDEX \\
        ${reads} \\
        > ${meta.id}.sam
    """
}
