# TRON-Bioinformatics/qcpanda: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.0.1 - 2026-05-29

### `Added`

### `Changed`

- updated nft-utils from 0.0.3 to 1.0.0
- updated default.nf.test and split the tests into multiple files
- switch optional ngscm pateint_map input file from tsv to csv format
- moved unittest data from `bin/tests/data/` to [TRON-Bioinformatics repo](https://github.com/TRON-Bioinformatics/test-datasets/tree/qcpanda/unittest_data)
- increased GENERATE_MULTIQC_CONFIG process memory from 64.MB and 64.MB on repeat to 512.MB and 512.MB on repeat

### `Fixed`

- TRON/qcpanda renamed to TRON-Bioinformatics/qcpanda

---

## v2.0.0 - 2026-05-23

Complete rewrite of TRON-Bioinformatics/qcpanda as an [nf-core](https://nf-co.re/)-style pipeline using the [nf-core tools 4.0.1](https://github.com/nf-core/tools/releases/tag/4.0.1) template. The pipeline logic is preserved and extended; all breaking changes relative to v1.6.x are listed below.

### `Added`

#### Pipeline structure

- nf-core directory layout: `workflows/`, `subworkflows/`, `modules/`, `conf/`, `assets/`, `docs/`
- nf-schema plugin (v2.5.1) for JSON-schema samplesheet validation via `assets/schema_input.json`; input is now a CSV samplesheet (`--input`) instead of a TSV table (`--input_table`)
- `conf/base.config` with per-process memory stepping for OOM retries; each process has an empirically tuned start memory, retry increment, and `maxRetries`
- Separate container config files per architecture and runtime: `conf/containers_docker_amd64.config`, `conf/containers_singularity_oras_amd64.config`, etc.
- `modules.json` for nf-core module version tracking
- `nf-test.config` for nf-test configuration
- `.github/` CI/CD: `nf-test.yml`, `linting.yml`, composite action `actions/nf-test/`, issue templates, PR template

#### New modules

- **NEW FEATURE**: `SEQKIT_SANA` (nf-core) — optional read sanitisation step before all other processing (`--skip_seqkit_sana`; default: skipped)

#### New parameters

- `--seqkit_keep_sampled` — publish downsampled FASTQ files (default: false)
- `--seqkit_keep_paired` — publish paired FASTQ files after `SEQKIT_PAIR` (default: false)
- `--seqkit_keep_unpaired` — publish unpaired reads discarded by `SEQKIT_PAIR` (default: false)
- `--ngscm_patient_map` — optional CSV mapping samples to patients for NGSCheckMate grouping
- `--fastp_discard_trimmed_pass` — discard reads that pass trimming (e.g. to keep only failed reads)
- `--fastp_save_merged` — save merged reads from fastp overlapping paired-end mode
- `--fastp_save_trimmed_fail` — save reads that fail fastp quality filters

#### Testing

- nf-test pipeline-level test (`tests/default.nf.test`) with stub mode
- Module-level nf-tests for `SEQKIT_STATS_READS` covering paired-end, single-end, and empty FASTQ edge cases

### `Changed`

- All modules migrated to nf-core module format with per-module containers; single global `environment.yml` removed
- `--input_table` (TSV) replaced by `--input` (CSV samplesheet); column `fastq_2` empty for single-end samples
- `--output` renamed to `--outdir` (nf-core standard)
- `--fastqscreen_conf` renamed to `--fastq_screen_references`
- `--kraken_db` renamed to `--kraken2_db`
- `--snps_pattern_file` renamed to `--ngscm_snp_patternsfile`
- `--sortmerna_filter` renamed to `--remove_ribo_rna`
- `--sortmerna_filter` renamed to `--remove_ribo_rna`
- `--reads_for_kraken` renamed to `--seqkit_sample_n`
- `--bracken_db` added as a separate parameter; previously the Bracken database was shared with `--kraken_db`
- All `--extra_*_args` parameters removed; tool arguments now configured via `ext.args` in `conf/modules.config`
- `--multiqc_config` removed; MultiQC config now generated dynamically by `GENERATE_MULTIQC_CONFIG`
- GitLab CI/CD replaced by GitHub Actions
- Singularity is the primary CI container runtime; Docker and Conda also supported via profiles

### `Removed`

- `--remove_work` parameter (work directory management left to the user / executor)
- `--extra_seqkit_stats_args`, `--extra_seqkit_pair_args`, `--extra_fastqc_args`, `--extra_fastp_args`, `--extra_fastqscreen_args`, `--extra_sequali_args`, `--extra_kraken_args`, `--extra_bracken_args`, `--extra_sortmerna_args`, `--extra_ngscm_fastq_args`, `--extra_ngscm_vaf_args`, `--extra_multiqc_args` — replaced by `ext.args` in `conf/modules.config`
- `--multiqc_config` static YAML — replaced by dynamic `GENERATE_MULTIQC_CONFIG` module
- `bin/analyze_trace_files.py` — standalone analysis script moved out of pipeline repo
- Custom conda `environment.yml` — replaced by per-module containers
- GitLab `.gitlab-ci.yml` configuration

### `Fixed`

- Empty FASTQ handling in `SEQKIT_STATS_READS`: header-only TSV now emits `0` read count instead of empty stdout---

## v1.6.3 - 2026-05-03

### `Added`

- `fastp_store_unpaired` parameter to save unpaired reads where one mate passes fastp filters but its pair does not (`--unpaired1`/`--unpaired2`); only applies to paired-end samples (default: false)

### `Removed`

- Bot for automatic execution removed from the main pipeline; it is now separately developed

### `Changed`

- Sankey plots now embedded as self-contained interactive HTML (highcharter) in MultiQC via `srcdoc` iframes with sample dropdown

---

## v1.6.2 - 2026-03-30

### `Changed`

- Samples folder output is now split into `samples_data` and `samples_reports` folders

### `Fixed`

- Sample duplications inside MultiQC Sequali report
- fastq_screen not reporting human and mouse composition

---

## v1.6.1 - 2026-02-11

### `Changed`

- Process memory allocations in `nextflow.config`
- Expanded OOM exit codes in `errorStrategy` in `nextflow.config`

### `Fixed`

- `nextflow.config` bug in `process_minimum` label

---

## v1.6.0 - 2026-02-03

### `Added`

- **NEW FEATURE**: SeqKit Stats reports simple statistics of FASTA/Q files (GC%, mean length, total reads, % est. dups) in the General Statistics section of MultiQC
- Parameter to match up paired-end reads from two FASTQ files (`--skip_seqkit_pair`; default true)
- `bin/analyze_trace_files.py` script to analyze Nextflow trace files and generate statistical summaries and suggestions

### `Changed`

- SeqKit is now used to count reads instead of counting `+` signs
- Nextflow trace file output includes more columns: `cpus`, `memory`, `attempt`, `%mem`
- Improved dynamic resource allocation split by process

### `Fixed`

- FastQC reporting only R2 in MultiQC report if input FASTQs did not have R1/R2 or 1/2 in file names
- Samples with the same basename in FASTQ files resulted in the same file names after downsampling
- GitHub CI/CD test lack of memory

---

## v1.5.0 - 2025-12-01

### `Added`

- Separate unittest for `sample_table_handler` script
- Samples with unequal R1 and R2 read counts are now logged in `output_folder/r1_r2_unequal_samples.txt`
- **NEW FEATURE**: Sequali — sequencing quality control tool with adapter search, overrepresented sequence analysis, and duplication analysis

### `Changed`

- FASTQs with read numbers lower than the threshold are now logged in `output_folder/fastqs_under_th.txt` instead of `failed_fastq_files.txt`
- fastp trimmed output files now include sample name prefix (e.g., `Sample_01_trimmed_R1.fastq.gz`)
- Updated MultiQC from 1.21 to 1.25

### `Fixed`

- `sample_table_handler` did not output file
- fastp error when input sample did not have same number of reads in R1 and R2; such samples are now skipped
- Wrong dendrogram clustering in custom NGSCheckMate report

---

## v1.4.1 - 2025-07-09

### `Changed`

- Increased number of process repeats from 3 to 4 in dynamic memory allocation

### `Fixed`

- Bot not running because Python not in `environment.yml`
- `dummy_fastq2.fq` not being mapped to Apptainer image because `/path` could not be found
- FASTQ files having more reads than the maximum value allowed for a 32-bit signed integer

---

## v1.4.0 - 2025-07-05

### `Added`

- Parameter to skip samples with read count below `params.minimum_read_number` (default 1)
- **NEW FEATURE**: The pipeline now supports single-end FASTQ inputs

### `Fixed`

- Pipeline now raises an error if the sample channel is empty

---

## v1.3.2 - 2025-05-28

### `Added`

- DT searchable, sortable, and downloadable table for sample correlation and homozygosity rate in custom NGSCheckMate RMarkdown report
- Bot will remove previous pipeline version folders with failed runs
- Python bot unittest for previous pipeline removal code
- Custom parameters can be added to each tool in `nextflow.config`

### `Removed`

- Custom undetected organism warning from Kraken2 MultiQC report
- "Visualization as graph" section from custom NGSCheckMate RMarkdown report

### `Changed`

- `nextflow.config` parameters are now grouped by tool
- Switched from Singularity to Apptainer profile

---

## v1.3.1 - 2025-05-20

### `Added`

- `sortmerna_filter` Nextflow parameter to filter rRNA reads from input FASTQ files (default false)
- `fastp_trim` Nextflow parameter to output fastp-trimmed FASTQ files (default false)

### `Changed`

- SortMeRNA will not execute automatically due to commercial usage restrictions; use `--skip_sortmerna false`
- SortMeRNA reference input is a text file where each line contains path to a SortMeRNA reference FASTA
- Nextflow work directory is now kept by default; use `--remove_work` parameter to remove it on successful finish

---

## v1.3.0 - 2025-05-16

### `Added`

- **NEW FEATURE**: SortMeRNA — local sequence alignment tool for filtering, mapping, and clustering; detects bacterial rRNA in samples
- `bin/bot/bot_latest.py` script to traverse input folders with flowcells, check pipeline versions, and create `latest` symlinks

### `Removed`

- Filtered outputs from fastp process workdir (still present in MultiQC statistics)

### `Changed`

- Dynamic resource allocation: all process labels now start at 50% less memory than before and increase by 100% for each retry (max 3 retries)
- Simplified GitLab CI/CD code for pipeline integration test

### `Fixed`

- fastp samples in MultiQC all had `_R1` in their names; now labeled by sample name

---

## v1.2.4 - 2025-04-23

### `Fixed`

- Wrong path mapping for custom R Markdown script channel and R custom scripts in `main.nf`
- Wrong patient labeling from `output_all.txt` NGSCheckMate output for clustering and heatmaps in custom NGSCheckMate report; now contains full sample names

---

## v1.2.3 - 2025-04-10

### `Added`

- Unittest for `generate_multiqc_config.py`
- Unittest for `bracken_read_length.py`
- Unittest for `generate_sankey_plot.R`
- Unittest for `ngscm_report.Rmd`
- All tools can now be included/excluded from the pipeline run in `nextflow.config`

### `Changed`

- Due to non-commercial use restrictions, Sankey is NOT included by default in the pipeline run

### `Fixed`

- Bug in bot file matcher that would throw error if there was no matched file
- Bug in custom NGSCheckMate report where patient name was generated based on columns that sometimes did not exist
- Bug in FASTQC process where output was overwritten if `.` was used as delimiter in input FASTQ names

---

## v1.2.2 - 2025-03-26

### `Added`

- Option in config to exclude NGSCheckMate analysis
- Option in config to keep work directory
- Option to run the bot on all flowcells regardless of the status of previous runs (`--run_all` parameter)

### `Changed`

- MultiQC will not link to custom NGSCheckMate report if there was only one sample

### `Fixed`

- Input table generator now detects `I1/2` files and excludes them from the input table
- NGSCheckMate now searches for unique sample strings for sample ID and determines patient ID based on ID substring
- Parent directory name will be appended to sample name when there are multiple FASTQs with the same name in different directories

---

## v1.2.1 - 2025-03-21

### `Added`

- Execute NGSCheckMate only if a certain percentage of reads originate from a certain organism (default 0.4; Homo sapiens)
- Skip Bracken/Sankey if a certain percentage of reads are unclassified (default 0.8)

### `Fixed`

- Skip dendrogram generation in custom NGSCheckMate report if there are only 2 samples
- Skip heatmap generation in custom NGSCheckMate report if there is only 1 sample

---

## v1.2.0 - 2025-03-19

### `Added`

- **NEW FEATURE**: NGSCheckMate output analysis using custom RMarkdown script
- Assert test for custom analysis output
- Bot unit test

### `Changed`

- Updated CI test with more samples that are sample replicates
- FASTQs are now paired based on the two largest files in a sample folder instead of pairing R1 and R2 files
- Updated Python version from 3.7 to 3.10

---

## v1.1.5 - 2025-02-28

### `Added`

- Expanded logger with pipeline version, already finished flowcells, and flowcells that previously failed due to process errors
- Link inside MultiQC report to custom NGSCheckMate report

### `Changed`

- Increased fastp process label from `medium` to `high`
- Pipeline will now skip only on failed process errors not caused by SLURM overload

### `Fixed`

- Bot now checks if pipeline successfully finished in current version

---

## v1.1.4 - 2025-02-25

### `Added`

- Rerun flowcell if SLURM error was caused by SLURM overload
- Adjustment to different sequencing type folder structures and their demultiplexing outputs

---

## v1.1.3 - 2025-02-21

### `Changed`

- Logfile location moved to output folder
- NGSCheckMate sample VAF creation parallelization and subsequent analysis (speeds up NGSCheckMate)

### `Fixed`

- Generated input table now has only unique rows
- Work directory used to get removed even when an error occurred; this is now fixed

---

## v1.1.2 - 2025-02-17

### `Added`

- Bot logs are saved by date in `logs/` folder
- Delete work directory on successful pipeline run
- Output folder has a pipeline subfolder where output is saved

### `Changed`

- Updated README so bot section is at the end

### `Fixed`

- Mambaforge GitLab CI/CD test now pins specific version

---

## v1.1.1 - 2024-11-06

### `Added`

- Two-pass mode for downsampling of FASTQ to avoid memory issues
- Changed folder structure of output
- Test scripts for bot

### `Removed`

- Code for single-end data handling as most tools did not support it

### `Fixed`

- Bot code to enable Nextflow use
- NGSCheckMate results on all data
- Assertions on test data

---

## v1.1.0 - 2024-05-03

### `Added`

- Nextflow workflow with CSV table as input
- Script to generate input tables from flowcells
- Subdivided conda environment into process-specific environments
- Improved testing environment

### `Removed`

- Flowcell DB
- BLAST-based organism detection

### `Fixed`

- Race condition during MultiQC config editing

---

## v1.0.2 - 2023-12-02

### `Added`

- BLAST search for contamination checks
- Combination of Kraken2 and Bracken for contamination checks
- Sankey plot for visualization
- SeqKit for downsampling
- Upgraded dependencies in conda environment
- More test data

---

## v1.0.1 - 2022-12-15

### `Added`

- MultiQC and NGSCheckMate to results output
- Outsourced pipeline to be standalone
- Improved testing environment
- Conda environment as YAML to simplify installation

---

## v1.0.0 - 2022-10-20

### `Added`

- Initial release supporting the following QC tools: fastp, FastQC, and fastq-screen
- Automatic FASTQ parsing
- DB for processing status
