process BWA_INDEX {
    tag "${fasta.name}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/bwa:0.7.19--h577a1d6_1'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path('bwa'), emit: index
    tuple val("${task.process}"), val('bwa'), eval("bwa 2>&1 | sed -n 's/^Version: //p'"), topic: versions

    script:
    """
    mkdir bwa
    bwa index -p bwa/${fasta.baseName} ${fasta}
    """
}
