# TRON/qcpanda: Output

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [SeqKit Stats](#seqkit-stats) - FASTQ/FASTA statistics (read counts, GC%, length, duplication)
- [FastQC](#fastqc) - Per-sample read quality control _(optional)_
- [fastp](#fastp) - Adapter trimming and quality filtering _(optional)_
- [Sequali](#sequali) - Comprehensive per-sample QC reporting _(optional)_
- [FastQ Screen](#fastq-screen) - Multi-genome contamination screening _(optional)_
- [SortMeRNA](#sortmerna) - rRNA contamination quantification _(optional)_
- [Kraken2](#kraken2) - Taxonomic classification _(optional)_
- [Bracken](#bracken) - Species abundance estimation _(optional)_
- [Sankey plots](#sankey-plots) - Interactive lineage composition plots _(optional)_
- [NGSCheckMate](#ngscheckmate) - Sample identity verification _(optional)_
- [MultiQC](#multiqc) - Aggregate report describing results and QC from the whole pipeline
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution

### SeqKit Stats

<details markdown="1">
<summary>Output files</summary>

- `seqkit/`
  - `stats/`: Per-sample TSV files containing statistics for each input FASTQ file (format, type, num_seqs, sum_len, min_len, avg_len, max_len, Q1, Q2, Q3, sum_gap, N50, Q20%, Q30%, GC%, etc.)

</details>

[SeqKit](https://bioinf.shenwei.me/seqkit/) provides simple statistics of FASTA/Q files. The stats are displayed in the General Statistics section of the MultiQC report.

Samples failing the minimum read number filter (`--minimum_read_number`, default 1) are excluded from all downstream analysis. If any samples are filtered out, details are written to:

- `fastqs_under_th.txt` (in the top-level results directory): lists FASTQ files that did not pass the read number threshold.

### FastQC

<details markdown="1">
<summary>Output files</summary>

- `fastqc/`
  - `*.html`: FastQC report containing quality metrics for each sample.
  - `*.zip`: Zip archive containing the FastQC report and data files.

</details>

[FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) gives quality metrics for raw sequencing reads. Results are displayed in the MultiQC report. Disabled with `--skip_fastqc`.

### fastp

<details markdown="1">
<summary>Output files</summary>

- `fastp/`
  - `*.fastp.json`: JSON report with adapter trimming and quality filtering statistics.
  - `*.fastp.html`: HTML report.

</details>

[fastp](https://github.com/OpenGene/fastp) performs adapter trimming and quality filtering. Statistics are displayed in the MultiQC report. Disabled with `--skip_fastp`.

### Sequali

<details markdown="1">
<summary>Output files</summary>

- `sequali/`
  - `*.json`: Per-sample JSON report with comprehensive QC metrics including duplication rates, insert size distribution, and per-base quality.
  - `*.html`: Standalone HTML report.

</details>

[Sequali](https://github.com/rhpvorderman/sequali) generates comprehensive per-sample QC reports. JSON results are displayed in the MultiQC report. Disabled with `--skip_sequali`.

### FastQ Screen

<details markdown="1">
<summary>Output files</summary>

- `fastq_screen/`
  - `*.txt`: Per-sample screening results showing the percentage of reads mapping to each reference genome.
  - `*.html`: FastQ Screen HTML report.
  - `*.png`: FastQ Screen plot.

</details>

[FastQ Screen](https://www.bioinformatics.babraham.ac.uk/projects/fastq_screen/) screens a subset of reads against multiple reference genomes to detect cross-species contamination. Results are displayed in the MultiQC report. Requires `--fastq_screen_references`. Enabled by default; disabled with `--skip_fastq_screen true`.

### SortMeRNA

<details markdown="1">
<summary>Output files</summary>

- `sortmerna/`
  - `*.log`: Per-sample log file with rRNA alignment statistics (total reads, rRNA reads, percentage).

</details>

[SortMeRNA](https://github.com/biocore/sortmerna) quantifies rRNA contamination by aligning reads against rRNA reference databases. Log statistics are displayed in the MultiQC report. Requires `--sortmerna_ref_txt`. Disabled by default; enabled with `--skip_sortmerna false`.

### Kraken2

<details markdown="1">
<summary>Output files</summary>

- `kraken2/`
  - `*.kraken2.report.txt`: Kraken2 report with taxonomic classification summary (one row per taxon with read counts and percentages).

</details>

[Kraken2](https://github.com/DerrickWood/kraken2) classifies reads against a reference database to determine the taxonomic composition of each sample. A fixed number of reads (`--seqkit_sample_n`, default 10,000) are subsampled before classification to reduce runtime. Report statistics are displayed in the MultiQC report. Requires `--kraken2_db`. Disabled with `--skip_kraken2`.

### Bracken

<details markdown="1">
<summary>Output files</summary>

- `bracken/`
  - `*.tsv`: Per-sample Bracken abundance estimates at species level (re-estimated read counts and fractions).

</details>

[Bracken](https://github.com/jenniferlu717/Bracken) uses Kraken2 output to re-estimate species-level abundances via Bayesian estimation. The optimal k-mer length is determined automatically from the subsampled reads. Requires `--bracken_db` and Kraken2. Disabled with `--skip_bracken`.

### Sankey plots

<details markdown="1">
<summary>Output files</summary>

- `sankey_plots/`
  - `*_sankey_plot.html`: Per-sample interactive Sankey diagram showing the taxonomic lineage composition of classified reads. Only lineages with ≥ `--noise_threshold_sankey`% of reads (default 0.9%) are shown.

</details>

Interactive Sankey diagrams are generated from Bracken output and embedded in the MultiQC report. Requires Bracken. Disabled with `--skip_sankey`.

### NGSCheckMate

<details markdown="1">
<summary>Output files</summary>

- `ngscheckmate/` _(only present if any samples pass the `--execute_ngscm_threshold`)_
  - `ngscm_table.tsv`: Pairwise sample comparison table with correlation scores.
  - `ngscm_plots/`: Directory containing PDF and HTML plots of sample clustering.

</details>

[NGSCheckMate](https://github.com/parklab/NGSCheckMate) verifies sample identity by comparing SNP patterns across samples. It is run only on samples where the fraction of reads assigned to `--ngscm_organism` in the Kraken2 report meets or exceeds `--execute_ngscm_threshold` (default 0.4). If `--ngscm_patient_map` is provided, analysis and plots are performed per patient. Requires `--ngscm_snp_patternsfile`. Disabled with `--skip_ngscm`.

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.
  - Software versions: `qcpanda_software_mqc_versions.yml`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
