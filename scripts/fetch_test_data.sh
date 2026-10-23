#!/usr/bin/env bash
# Build a small, realistic germline test dataset for HG002 (GIAB Ashkenazi son) on GRCh38.
#
#   scripts/fetch_test_data.sh [REGION] [NAME]
#   scripts/fetch_test_data.sh chr20:10000000-10200000 test     # ~200 kb, used by -profile test
#   scripts/fetch_test_data.sh chr20:10000000-15000000 chr20_5mb
#
# Produces data/ref/chr20.fa(.fai) and data/<NAME>/ with paired FASTQs, the GIAB v4.2.1
# truth VCF for the region, the confident-region BED clipped to the region, and a samplesheet.
# Requires: curl, samtools, bcftools, tabix (all in the ngs-dev conda env).
set -euo pipefail

REGION="${1:-chr20:10000000-10200000}"
NAME="${2:-test}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA="$ROOT/data"
OUT="$DATA/$NAME"

READS_BAM="https://storage.googleapis.com/deepvariant/case-study-testdata/HG002.novaseq.pcr-free.35x.dedup.grch38_no_alt.chr20.bam"
REF_FA="https://hgdownload.soe.ucsc.edu/goldenPath/hg38/chromosomes/chr20.fa.gz"
GIAB="https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38"
TRUTH_VCF="$GIAB/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz"
TRUTH_BED="$GIAB/HG002_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed"

if [[ ! "$REGION" =~ ^(chr20):([0-9]+)-([0-9]+)$ ]]; then
  echo "REGION must look like chr20:START-END (the reference is chr20 only)" >&2
  exit 1
fi
CHROM="${BASH_REMATCH[1]}"; START="${BASH_REMATCH[2]}"; END="${BASH_REMATCH[3]}"

mkdir -p "$DATA/ref" "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[1/4] Reference: GRCh38 chr20"
if [[ ! -s "$DATA/ref/chr20.fa.fai" ]]; then
  curl -fsSL "$REF_FA" | gunzip -c > "$DATA/ref/chr20.fa"
  samtools faidx "$DATA/ref/chr20.fa"
fi

echo "[2/4] Reads: HG002 NovaSeq 35x, $REGION -> paired FASTQ"
# htslib downloads the remote .bai into the working directory, so run from the temp dir.
# Drop secondary/supplementary records, group mates together, and keep only complete pairs.
(
  cd "$TMP"
  samtools view -u -F 0x900 "$READS_BAM" "$REGION" \
    | samtools collate -u -O - "$TMP/collate" \
    | samtools fastq -n -0 /dev/null -s /dev/null \
        -1 "$OUT/HG002_R1.fastq.gz" -2 "$OUT/HG002_R2.fastq.gz" -
)

echo "[3/4] Truth: GIAB v4.2.1 variants in $REGION"
(
  cd "$TMP"
  bcftools view -r "$REGION" -Oz -o "$OUT/truth.vcf.gz" "$TRUTH_VCF"
)
tabix -f -p vcf "$OUT/truth.vcf.gz"

# BED is 0-based, half-open; REGION is 1-based, inclusive.
printf "%s\t%d\t%d\n" "$CHROM" "$((START - 1))" "$END" > "$OUT/region.bed"
curl -fsSL "$TRUTH_BED" \
  | awk -v c="$CHROM" -v s="$((START - 1))" -v e="$END" 'BEGIN{OFS="\t"}
      $1 == c && $3 > s && $2 < e { print $1, ($2 < s ? s : $2), ($3 > e ? e : $3) }' \
  > "$OUT/truth.bed"

echo "[4/4] Samplesheet"
printf "sample,fastq_1,fastq_2\nHG002,%s,%s\n" "$OUT/HG002_R1.fastq.gz" "$OUT/HG002_R2.fastq.gz" > "$OUT/samplesheet.csv"

pairs=$(( $(gunzip -c "$OUT/HG002_R1.fastq.gz" | wc -l) / 4 ))
vars=$(bcftools view -H "$OUT/truth.vcf.gz" | wc -l | tr -d ' ')
conf=$(awk '{s += $3 - $2} END {print s}' "$OUT/truth.bed")
echo "Done: $OUT"
echo "  read pairs:        $pairs"
echo "  truth variants:    $vars"
echo "  confident bases:   $conf of $((END - START + 1))"
