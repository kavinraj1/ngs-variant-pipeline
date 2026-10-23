process GATK4_CREATESEQUENCEDICTIONARY {
    tag "${fasta.name}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/gatk4:4.6.2.0--py310hdfd78af_1'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path('*.dict'), emit: dict
    tuple val("${task.process}"), val('gatk4'), eval("gatk --version 2>&1 | sed -n 's/^The Genome Analysis Toolkit (GATK) v//p'"), topic: versions

    script:
    def avail_mem = Math.max(1, (task.memory.toGiga() * 0.8).intValue())
    """
    gatk --java-options "-Xmx${avail_mem}g" CreateSequenceDictionary \\
        --REFERENCE ${fasta} \\
        --OUTPUT ${fasta.baseName}.dict
    """
}
