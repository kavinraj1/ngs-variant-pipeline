process RTG_FORMAT {
    tag "${fasta.name}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/rtg-tools:3.13--hdfd78af_0'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path('*.sdf'), emit: sdf
    tuple val("${task.process}"), val('rtg-tools'), eval("rtg version | sed -n 's/^Product: RTG Tools //p'"), topic: versions

    script:
    def avail_mem = Math.max(1, (task.memory.toGiga() * 0.8).intValue())
    """
    export RTG_MEM=${avail_mem}g RTG_TALKBACK=false RTG_USAGE=false
    rtg format --output ${fasta.baseName}.sdf ${fasta}
    """
}
