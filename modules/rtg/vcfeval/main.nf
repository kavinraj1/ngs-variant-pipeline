process RTG_VCFEVAL {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container 'quay.io/biocontainers/rtg-tools:3.13--hdfd78af_0'

    input:
    tuple val(meta), path(vcf), path(tbi)
    tuple path(truth_vcf), path(truth_tbi), path(truth_bed)
    tuple val(meta2), path(sdf)

    output:
    tuple val(meta), path("${meta.id}_vcfeval"),     emit: results
    tuple val(meta), path("${meta.id}.benchmark.tsv"), emit: tsv
    tuple val(meta), path("${meta.id}_benchmark_mqc.tsv"), emit: mqc
    tuple val("${task.process}"), val('rtg-tools'), eval("rtg version | sed -n 's/^Product: RTG Tools //p'"), topic: versions

    script:
    def avail_mem = Math.max(1, (task.memory.toGiga() * 0.8).intValue())
    // vcfeval matches calls to the truth by haplotype, so differently represented but equivalent
    // variants still count as matches. Filtered (non-PASS) calls are ignored.
    """
    export RTG_MEM=${avail_mem}g RTG_TALKBACK=false RTG_USAGE=false

    rtg vcfeval \\
        --baseline ${truth_vcf} \\
        --calls ${vcf} \\
        --bed-regions ${truth_bed} \\
        --template ${sdf} \\
        --threads ${task.cpus} \\
        --output ${meta.id}_vcfeval

    count() { rtg vcffilter --input "\$1" --output - \$2 | awk '!/^#/ { n++ } END { print n + 0 }'; }

    printf "sample\\ttype\\tTP_truth\\tTP_calls\\tFP\\tFN\\tprecision\\trecall\\tF1\\n" > ${meta.id}.benchmark.tsv
    for type in SNP INDEL; do
        [ "\$type" = SNP ] && sel=--snps-only || sel=--non-snps-only
        tpb=\$(count ${meta.id}_vcfeval/tp-baseline.vcf.gz \$sel)
        tpc=\$(count ${meta.id}_vcfeval/tp.vcf.gz \$sel)
        fp=\$(count ${meta.id}_vcfeval/fp.vcf.gz \$sel)
        fn=\$(count ${meta.id}_vcfeval/fn.vcf.gz \$sel)
        awk -v s=${meta.id} -v t=\$type -v tpb=\$tpb -v tpc=\$tpc -v fp=\$fp -v fn=\$fn 'BEGIN {
            p = (tpc + fp) ? tpc / (tpc + fp) : 0
            r = (tpb + fn) ? tpb / (tpb + fn) : 0
            f = (p + r) ? 2 * p * r / (p + r) : 0
            printf "%s\\t%s\\t%d\\t%d\\t%d\\t%d\\t%.4f\\t%.4f\\t%.4f\\n", s, t, tpb, tpc, fp, fn, p, r, f
        }' >> ${meta.id}.benchmark.tsv
    done

    {
        echo "# id: 'giab_benchmark'"
        echo "# section_name: 'Accuracy vs GIAB truth (RTG vcfeval)'"
        echo "# description: 'PASS calls compared with the GIAB v4.2.1 benchmark inside its confident regions.'"
        echo "# plot_type: 'table'"
        awk 'BEGIN { FS = OFS = "\\t" } NR == 1 { print "Sample", "TP (truth)", "TP (calls)", "FP", "FN", "Precision", "Recall", "F1"; next }
             { print \$1 " " \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9 }' ${meta.id}.benchmark.tsv
    } > ${meta.id}_benchmark_mqc.tsv
    """
}
