# TRON-Bioinformatics/qcpanda: Usage

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

TRON-Bioinformatics/qcpanda runs a battery of quality control tools on Illumina paired-end (or single-end) FASTQ data and aggregates all results into a single interactive MultiQC report. The pipeline covers read sanitisation, adapter trimming, contamination screening, rRNA quantification, taxonomic classification with Sankey visualisation, and optional sample identity verification via NGSCheckMate.

Several steps require external reference databases or configuration files to be provided at run time (see [Reference databases](#reference-databases) below). Steps that depend on these files are skipped by default and must be explicitly enabled.

## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 3 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

### Samplesheet columns

| Column    | Description                                                                                                                                                                 |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample`  | Unique sample name. Spaces are automatically converted to underscores (`_`). The same name may appear on multiple rows to merge lanes of the same sample before processing. |
| `fastq_1` | Full path to the R1 (or single-end) gzipped FASTQ file. Must have the extension `.fastq.gz` or `.fq.gz`.                                                                    |
| `fastq_2` | Full path to the R2 gzipped FASTQ file for paired-end data. Leave empty for single-end samples.                                                                             |

### Example samplesheet

```csv title="samplesheet.csv"
sample,fastq_1,fastq_2
SAMPLE_A,/data/SAMPLE_A_R1.fastq.gz,/data/SAMPLE_A_R2.fastq.gz
SAMPLE_B,/data/SAMPLE_B_R1.fastq.gz,/data/SAMPLE_B_R2.fastq.gz
SAMPLE_SE,/data/SAMPLE_SE_R1.fastq.gz,
```

When the same `sample` name appears on multiple rows (e.g. multiple sequencing lanes), the pipeline merges the FASTQ files before processing.

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

## Reference databases

Several pipeline steps require external reference data. Provide the relevant paths when enabling those steps:

| Parameter                   | Required when                         | Description                                                                                                                                                                                                                                 |
| --------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--kraken2_db`              | `--skip_kraken2 false` (default)      | Path to a Kraken2 database directory or `.tar.gz` archive.                                                                                                                                                                                  |
| `--bracken_db`              | `--skip_bracken false` (default)      | Path to a Bracken database directory containing `kmer_distrib` files. Can be the same directory as `--kraken2_db`.                                                                                                                          |
| `--fastq_screen_references` | `--skip_fastq_screen false` (default) | Path to a CSV file with columns `name,dir,basename,aligner` describing each reference genome to screen against. `dir` may be a local/S3 directory path or a local/S3 `.tar.gz` archive that will be unpacked at runtime. See example below. |

#### Example FastQ Screen references CSV

```csv title="fastq_screen_references.csv"
name,dir,basename,aligner
Human,/path/to/fastq_screen_db/Human,hg38,bowtie2
Mouse,/path/to/fastq_screen_db/Mouse,mm10,bowtie2
Bacteria,/path/to/fastq_screen_db/bacteria_db.tar.gz,16srRNA.bacteria,bowtie
```

| Column     | Description                                                                                                                                    |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`     | Display name for the reference in FastQ Screen output and MultiQC report.                                                                      |
| `dir`      | Path to the Bowtie2/Bowtie index directory (local or S3), or a `.tar.gz` archive (local or S3) that will be unpacked automatically at runtime. |
| `basename` | Basename of the Bowtie2/Bowtie index files within `dir` (i.e. the prefix shared by all `.bt2`/`.ebwt` index files).                            |
| `aligner`  | Aligner to use: `bowtie2` or `bowtie`.                                                                                                         |

| Parameter                  | Required when                  | Description                                                                                                                    |
| -------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| `--sortmerna_ref_txt`      | `--skip_sortmerna false`       | Path to a plain-text file where each line is the full path to one rRNA reference FASTA (`.fa` or `.fa.gz`). See example below. |
| `--ngscm_snp_patternsfile` | `--skip_ngscm false` (default) | Path to the NGSCheckMate SNP patterns file (`SNP.pt`). Typically found at `<NGSCheckMate_install_dir>/SNP/SNP.pt`.             |

#### Example SortMeRNA references file

```txt title="sortmerna_fastas.txt"
/path/to/sortmerna_db/rfam-5.8s-database-id98.fasta
/path/to/sortmerna_db/rfam-5s-database-id98.fasta
/path/to/sortmerna_db/silva-arc-16s-id95.fasta
/path/to/sortmerna_db/silva-bac-16s-id90.fasta
/path/to/sortmerna_db/silva-euk-18s-id95.fasta
/path/to/sortmerna_db/silva-euk-28s-id98.fasta
```

One FASTA path per line. Files may be plain (`.fa`, `.fasta`) or gzip-compressed (`.fa.gz`, `.fasta.gz`); the pipeline decompresses them automatically.

> [!NOTE]
> `--skip_sortmerna` defaults to `true`. You must pass `--skip_sortmerna false` together with `--sortmerna_ref_txt` to enable rRNA quantification. All other steps are enabled by default and can be individually disabled with their respective `--skip_*` flags.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run TRON-Bioinformatics/qcpanda \
   -profile docker \
   --input samplesheet.csv \
   --outdir ./results \
   --kraken2_db /path/to/kraken2_db \
   --bracken_db /path/to/bracken_db \
   --ngscm_snp_patternsfile /path/to/SNP.pt
```

To also enable SortMeRNA rRNA quantification (disabled by default):

```bash
nextflow run TRON-Bioinformatics/qcpanda \
   -profile docker \
   --input samplesheet.csv \
   --outdir ./results \
   --kraken2_db /path/to/kraken2_db \
   --bracken_db /path/to/bracken_db \
   --fastq_screen_references /path/to/fastq_screen_references.csv \
   --ngscm_snp_patternsfile /path/to/SNP.pt \
   --skip_sortmerna false \
   --sortmerna_ref_txt /path/to/rrna_refs.txt
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/running/run-pipelines#configuring-pipelines), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run TRON-Bioinformatics/qcpanda -profile docker -params-file params.yaml
```

with:

```yaml title="params.yaml"
input: "./samplesheet.csv"
outdir: "./results/"
kraken2_db: "/path/to/kraken2_db"
bracken_db: "/path/to/bracken_db"
ngscm_snp_patternsfile: "/path/to/SNP.pt"
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull TRON-Bioinformatics/qcpanda
```

### Reproducibility

It is a good idea to specify the pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [TRON-Bioinformatics/qcpanda releases page](https://github.com/TRON-Bioinformatics/qcpanda/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducibility, you can use share and reuse [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Pipeline-specific parameters

### Read filtering

| Parameter               | Default | Description                                                                                                                |
| ----------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------- |
| `--minimum_read_number` | `1`     | Minimum number of reads per FASTQ file. Samples with any file below this threshold are excluded from all downstream steps. |

### Skip flags

All major pipeline steps can be disabled individually. Steps that are **on** by default are marked with ✓.

| Parameter             | Default   | Description                                                                                   |
| --------------------- | --------- | --------------------------------------------------------------------------------------------- |
| `--skip_seqkit_sana`  | `true`    | Skip SeqKit Sana read sanitisation.                                                           |
| `--skip_seqkit_pair`  | `false` ✓ | Skip SeqKit Pair repair of unequal R1/R2 read counts. When true, unequal samples are dropped. |
| `--skip_fastqc`       | `false` ✓ | Skip FastQC quality control.                                                                  |
| `--skip_fastp`        | `false` ✓ | Skip fastp adapter trimming.                                                                  |
| `--skip_sequali`      | `false` ✓ | Skip Sequali per-sample QC reporting.                                                         |
| `--skip_fastq_screen` | `false` ✓ | Skip FastQ Screen contamination screening. Requires `--fastq_screen_references` when enabled. |
| `--skip_sortmerna`    | `true`    | Skip SortMeRNA rRNA quantification. Requires `--sortmerna_ref_txt` when enabled.              |
| `--skip_kraken2`      | `false` ✓ | Skip Kraken2 taxonomic classification. Requires `--kraken2_db`.                               |
| `--skip_bracken`      | `false` ✓ | Skip Bracken species abundance estimation. Requires `--bracken_db` and Kraken2.               |
| `--skip_sankey`       | `false` ✓ | Skip Sankey lineage plot generation. Requires Bracken.                                        |
| `--skip_ngscm`        | `false` ✓ | Skip NGSCheckMate sample identity verification. Requires `--ngscm_snp_patternsfile`.          |

### Kraken2 / Bracken options

| Parameter                  | Default        | Description                                                                                                                                                                                                                                      |
| -------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `--seqkit_sample_n`        | `10000`        | Number of reads sampled per FASTQ before Kraken2. Reduces runtime without losing classification accuracy.                                                                                                                                        |
| `--unclassified_ratio_th`  | `0.8`          | Maximum unclassified fraction (0-1) from Kraken2 allowed to run Bracken on a sample. Samples with unclassified ratio greater than or equal to this threshold are skipped for Bracken.                                                            |
| `--ngscm_organism`         | `Homo sapiens` | Species name as it appears in the Kraken2 **report** file (last column). Used to compute the fraction of reads assigned to this organism, which is compared against `--execute_ngscm_threshold` to decide whether NGSCheckMate runs on a sample. |
| `--noise_threshold_sankey` | `0.9`          | Minimum read percentage (0–100) for a species lineage to appear in the Sankey plot.                                                                                                                                                              |

### NGSCheckMate options

| Parameter                   | Default | Description                                                                                                                                                                               |
| --------------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--execute_ngscm_threshold` | `0.4`   | Minimum fraction (0–1) of reads assigned to `--ngscm_organism` in the Kraken2 report required to run NGSCheckMate on a sample. Samples below this threshold are skipped silently.         |
| `--ngscm_patient_map`       | —       | Optional comma-separated file with columns `patient` and `sample`. When provided, NGSCheckMate analysis is run per-patient and plots are coloured/grouped accordingly. See example below. |

#### Example patient map

```csv title="patient_map.csv"
patient,sample
PATIENT_1,SAMPLE_A_L001
PATIENT_1,SAMPLE_A_L002
PATIENT_2,SAMPLE_B_L001
```

The `patient` column groups samples that are expected to match (e.g. different timepoints or replicates from the same donor). The `sample` values must match exactly the `sample` column in your input samplesheet.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen)

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

> [!IMPORTANT]
> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to check if your system is supported, please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer environment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://charliecloud.io/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `wave`
  - A generic configuration profile to enable [Wave](https://seqera.io/wave/) containers. Use together with one of the above (requires Nextflow ` 24.03.0-edge` or later).
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the pipeline steps, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher resources request (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#set-max-resources) and [customise process resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#customize-process-resources) section of the nf-core website.

### Custom Containers

In some cases, you may wish to change the container or conda environment used by a pipeline steps for a particular tool. By default, nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However, in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#update-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#modifying-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
