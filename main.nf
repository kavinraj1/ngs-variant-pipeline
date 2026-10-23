#!/usr/bin/env nextflow
/*
 * Germline short-variant calling: paired-end FASTQ -> QC -> alignment -> duplicate marking
 * -> GATK HaplotypeCaller -> hard filtering -> (optional) benchmarking against a truth set.
 */

include { FASTQC                         } from './modules/fastqc'
include { FASTP                          } from './modules/fastp'
include { SAMTOOLS_FAIDX                 } from './modules/samtools/faidx'
include { GATK4_CREATESEQUENCEDICTIONARY } from './modules/gatk4/createsequencedictionary'
include { BWA_INDEX                      } from './modules/bwa/index'
include { BWA_MEM                        } from './modules/bwa/mem'
include { GATK4_MARKDUPLICATES           } from './modules/gatk4/markduplicates'
include { GATK4_SORTSAM                  } from './modules/gatk4/sortsam'
include { SAMTOOLS_STATS                 } from './modules/samtools/stats'
include { GATK4_HAPLOTYPECALLER          } from './modules/gatk4/haplotypecaller'
include { GATK4_VARIANTFILTRATION        } from './modules/gatk4/variantfiltration'
include { BCFTOOLS_STATS                 } from './modules/bcftools/stats'
include { RTG_FORMAT                     } from './modules/rtg/format'
include { RTG_VCFEVAL                    } from './modules/rtg/vcfeval'
include { MULTIQC                        } from './modules/multiqc'

workflow {

    main:
    if (!params.input) error "Missing --input (CSV with columns: sample,fastq_1,fastq_2)"
    if (!params.fasta) error "Missing --fasta (reference genome FASTA)"
    if ((params.truth_vcf as boolean) != (params.truth_bed as boolean)) {
        error "--truth_vcf and --truth_bed must be given together"
    }

    ch_reads = channel.fromPath(params.input, checkIfExists: true)
        .splitCsv(header: true, strip: true)
        .map { row ->
            if (!row.sample || !row.fastq_1 || !row.fastq_2) {
                error "Samplesheet rows need sample, fastq_1 and fastq_2: ${row}"
            }
            def meta = [id: row.sample]
            [meta, [file(row.fastq_1, checkIfExists: true), file(row.fastq_2, checkIfExists: true)]]
        }

    ch_fasta     = channel.value([[id: 'reference'], file(params.fasta, checkIfExists: true)])
    ch_intervals = params.intervals ? channel.value(file(params.intervals, checkIfExists: true)) : channel.value([])

    // Reference preparation: runs once and is shared by every sample.
    SAMTOOLS_FAIDX(ch_fasta)
    GATK4_CREATESEQUENCEDICTIONARY(ch_fasta)
    BWA_INDEX(ch_fasta)

    // Read QC and trimming.
    FASTQC(ch_reads)
    FASTP(ch_reads)

    // Alignment and duplicate marking.
    BWA_MEM(FASTP.out.reads, BWA_INDEX.out.index)
    GATK4_MARKDUPLICATES(BWA_MEM.out.sam)
    GATK4_SORTSAM(GATK4_MARKDUPLICATES.out.bam)
    SAMTOOLS_STATS(GATK4_SORTSAM.out.bam, ch_fasta)

    // Variant calling and filtering.
    GATK4_HAPLOTYPECALLER(
        GATK4_SORTSAM.out.bam,
        ch_fasta,
        SAMTOOLS_FAIDX.out.fai,
        GATK4_CREATESEQUENCEDICTIONARY.out.dict,
        ch_intervals
    )
    GATK4_VARIANTFILTRATION(
        GATK4_HAPLOTYPECALLER.out.vcf,
        ch_fasta,
        SAMTOOLS_FAIDX.out.fai,
        GATK4_CREATESEQUENCEDICTIONARY.out.dict
    )
    BCFTOOLS_STATS(GATK4_VARIANTFILTRATION.out.vcf)

    // Optional benchmarking against a truth set (e.g. GIAB).
    ch_benchmark = channel.empty()
    if (params.truth_vcf) {
        ch_truth = channel.value([
            file(params.truth_vcf, checkIfExists: true),
            file("${params.truth_vcf}.tbi", checkIfExists: true),
            file(params.truth_bed, checkIfExists: true)
        ])
        RTG_FORMAT(ch_fasta)
        RTG_VCFEVAL(GATK4_VARIANTFILTRATION.out.vcf, ch_truth, RTG_FORMAT.out.sdf)
        ch_benchmark = RTG_VCFEVAL.out.mqc.map { _meta, tsv -> tsv }
    }

    // Software versions from every process, in MultiQC's versions format.
    ch_versions = channel.topic('versions')
        .unique()
        .map { process, tool, version -> "${process.tokenize(':').last()}:\n  ${tool}: '${version}'" }
        .collectFile(name: 'software_versions_mqc_versions.yml', newLine: true, sort: true)

    ch_multiqc = channel.empty()
        .mix(
            FASTQC.out.zip.map { _meta, files -> files },
            FASTP.out.json.map { _meta, json -> json },
            GATK4_MARKDUPLICATES.out.metrics.map { _meta, metrics -> metrics },
            SAMTOOLS_STATS.out.stats.map { _meta, stats -> stats },
            BCFTOOLS_STATS.out.stats.map { _meta, stats -> stats },
            ch_benchmark,
            ch_versions
        )
        .flatten()
        .collect()

    MULTIQC(ch_multiqc, file(params.multiqc_config, checkIfExists: true))
}
