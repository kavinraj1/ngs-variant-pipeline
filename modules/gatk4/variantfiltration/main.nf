process GATK4_VARIANTFILTRATION {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/gatk4:4.6.2.0--py310hdfd78af_1'

    input:
    tuple val(meta), path(vcf), path(tbi)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fai)
    tuple val(meta4), path(dict)

    output:
    tuple val(meta), path('*.filtered.vcf.gz'), path('*.filtered.vcf.gz.tbi'), emit: vcf
    tuple val("${task.process}"), val('gatk4'), eval("gatk --version 2>&1 | sed -n 's/^The Genome Analysis Toolkit (GATK) v//p'"), topic: versions

    script:
    def avail_mem = Math.max(1, (task.memory.toGiga() * 0.8).intValue())
    // GATK's recommended hard filters for a single sample, where VQSR has too few variants to train on.
    def filters = [
        SNP_QD2:          'vc.isSNP() && QD < 2.0',
        SNP_QUAL30:       'vc.isSNP() && QUAL < 30.0',
        SNP_SOR3:         'vc.isSNP() && SOR > 3.0',
        SNP_FS60:         'vc.isSNP() && FS > 60.0',
        SNP_MQ40:         'vc.isSNP() && MQ < 40.0',
        SNP_MQRankSum:    'vc.isSNP() && MQRankSum < -12.5',
        SNP_ReadPosRank:  'vc.isSNP() && ReadPosRankSum < -8.0',
        INDEL_QD2:        'vc.isIndel() && QD < 2.0',
        INDEL_QUAL30:     'vc.isIndel() && QUAL < 30.0',
        INDEL_FS200:      'vc.isIndel() && FS > 200.0',
        INDEL_ReadPosRank:'vc.isIndel() && ReadPosRankSum < -20.0',
    ]
    def filter_args = filters.collect { name, expr -> "--filter-name ${name} --filter-expression '${expr}'" }.join(' \\\n        ')
    """
    gatk --java-options "-Xmx${avail_mem}g" VariantFiltration \\
        --variant ${vcf} \\
        --reference ${fasta} \\
        --output ${meta.id}.filtered.vcf.gz \\
        ${filter_args}
    """
}
