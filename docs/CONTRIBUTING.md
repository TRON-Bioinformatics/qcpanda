---
title: Contributing
markdownPlugin: checklist
---

# `TRON-Bioinformatics/qcpanda`: Contributing guidelines

Hi there!
Thanks for taking an interest in improving TRON-Bioinformatics/qcpanda.

This page describes the recommended nf-core way to contribute to both TRON-Bioinformatics/qcpanda and nf-core pipelines in general, including:

- [General contribution guidelines](#general-contribution-guidelines): common procedures or guides across all nf-core pipelines.
- [Pipeline-specific contribution guidelines](#pipeline-specific-contribution-guidelines): procedures or guides specific to the development conventions of TRON-Bioinformatics/qcpanda.

## General contribution guidelines

### Contribution quick start

To contribute code to any nf-core pipeline:

- [ ] Ensure you have Nextflow, nf-core tools, and nf-test installed. See the [nf-core/tools repository](https://github.com/nf-core/tools) for instructions.
- [ ] Check whether a GitHub [issue](https://github.com/TRON-Bioinformatics/qcpanda/issues) about your idea already exists. If an issue does not exist, create one so that others are aware you are working on it.
- [ ] [Fork](https://help.github.com/en/github/getting-started-with-github/fork-a-repo) the [TRON-Bioinformatics/qcpanda repository](https://github.com/TRON-Bioinformatics/qcpanda) to your GitHub account.
- [ ] Create a branch on your forked repository and make your changes following [pipeline conventions](#pipeline-contribution-conventions) (if applicable).
- [ ] To fix major bugs, name your branch `patch` and follow the [patch release](#patch-release) process.
- [ ] Update relevant documentation within the `docs/` folder, use nf-core/tools to update `nextflow_schema.json`, and update `CITATIONS.md`.
- [ ] Run and/or update tests. See [Testing](#testing) for more information.
- [ ] [Lint](#lint-tests) your code with nf-core/tools.
- [ ] Submit a pull request (PR) against the `dev` branch and request a review.

If you are not used to this workflow with Git, see the [GitHub documentation](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests) or [Git resources](https://try.github.io/) for more information.

### Testing

Once you have made your changes, run the pipeline with nf-test to test them locally.
For additional information, use the `--verbose` flag to view the Nextflow console log output.

```bash
nf-test test --tag test --profile +docker --verbose
```

If you have added new functionality, ensure you update the test assertions in the `.nf.test` files in the `tests/` directory.
Update the snapshots with the following command:

```bash
nf-test test --tag test --profile +docker --verbose --update-snapshots
```

When you create a pull request with changes, GitHub Actions will run automatic tests.
Pull requests are typically reviewed when these tests are passing.

Two types of tests are typically run:

#### Lint tests

nf-core has a [set of guidelines](https://nf-co.re/docs/specifications/overview) which all pipelines must follow.
To enforce these, run linting with nf-core/tools:

```bash
nf-core pipelines lint <pipeline_directory>
```

If you encounter failures or warnings, follow the linked documentation printed to screen.
For more information about linting tests, see [nf-core/tools API documentation](https://nf-co.re/docs/nf-core-tools/api_reference/latest/pipeline_lint_tests/actions_awsfulltest).

#### Pipeline tests

Each nf-core pipeline should be set up with a minimal set of test data.
GitHub Actions runs the pipeline on this data to ensure it runs through and exits successfully.
If there are any failures then the automated tests fail.
These tests are run with the latest available version of Nextflow and the minimum required version specified in the pipeline code.

### Patch release

> [!WARNING]
> Only in the unlikely event of a release that contains a critical bug.

- [ ] Create a new branch `patch` on your fork based on `upstream/main` or `upstream/master`.
- [ ] Fix the bug and use nf-core/tools to bump the version to the next semantic version, for example, `1.2.3` → `1.2.4`.
- [ ] Open a Pull Request from `patch` directly to `main`/`master` with the changes.

### Pipeline contribution conventions

nf-core semi-standardises how you write code and other contributions to make the TRON-Bioinformatics/qcpanda code and processing logic more understandable for new contributors and to ensure quality.

#### Add a new pipeline step

To contribute a new step to the pipeline, follow the general nf-core coding procedure.
Please also refer to the [pipeline-specific contribution guidelines](#pipeline-specific-contribution-guidelines):

- [ ] Define the corresponding [input channel](#channel-naming-schemes) into your new process from the expected previous process channel.
- [ ] Install a module with nf-core/tools, or write a local module (see [default processes resource requirements](#default-processes-resource-requirements)), and add it to the target `<workflow>.nf`.
- [ ] Define the output channel if needed. Mix the version output channel into `ch_versions` and relevant files into `ch_multiqc`.
- [ ] Add new or updated parameters to `nextflow.config` with a [default value](#default-parameter-values).
- [ ] Add new or updated parameters and relevant help text to `nextflow_schema.json` with [nf-core/tools](#default-parameter-values).
- [ ] Add validation for relevant parameters to the pipeline utilisation section of `utils_nfcore_\_pipeline/main.nf` subworkflow.
- [ ] Perform local tests to validate that the new code works as expected.
  - [ ] If applicable, add a new test in the `tests` directory.
- [ ] Update `usage.md`, `output.md`, and `citation.md` as appropriate.
- [ ] [Lint](lint) the code with nf-core/tools.
- [ ] Update any diagrams or pipeline images as necessary.
- [ ] Update MultiQC config `assets/multiqc_config.yml` so relevant suffixes, file name cleanup, and module plots are in the appropriate order.
- [ ] If applicable, create a [MultiQC](https://seqera.io/multiqc/) module.
- [ ] Add a description of the output files and, if relevant, images from the MultiQC report to `docs/output.md`.

To update the minimum required Nextflow version, see the [Nextflow version bumping](#nextflow-version-bumping) section below. For more information about pipeline contributions, see [pipeline-specific contribution guidelines](#pipeline-specific-contribution-guidelines).

#### Channel naming schemes

Use the following naming schemes for channels to make the channel flow easier to understand:

- Initial process channel: `ch_output_from_<process>`
- Intermediate and terminal channels: `ch_<previousprocess>_for_<nextprocess>`

#### Default parameter values

Parameters should be initialised and defined with default values within the `params` scope in `nextflow.config`.
They should also be documented in the pipeline JSON schema.

To update `nextflow_schema.json`, run:

```bash
nf-core pipelines schema build
```

The schema builder interface that loads in your browser should automatically update the defaults in the parameter documentation.

#### Default processes resource requirements

If you write a local module, specify a default set of resource requirements for the process.

Sensible defaults for process resource requirements (CPUs, memory, time) should be defined in `conf/base.config`.
Specify these with generic `withLabel:` selectors, so they can be shared across multiple processes and steps of the pipeline.

nf-core provides a set of standard labels that you should follow where possible, as seen in the [nf-core pipeline template](https://github.com/nf-core/tools/blob/main/nf_core/pipeline-template/conf/base.config).
These labels define resource defaults for single-core processes, modules that require a GPU, and different levels of multi-core configurations with increasing memory requirements.

Values assigned within these labels can be dynamically passed to a tool using the the `${task.cpus}` and `${task.memory}` Nextflow variables in the `script:` block of a module (see an example in the [modules repository](https://github.com/nf-core/modules/blob/bd1b6a40f55933d94b8c9ca94ec8c1ea0eaf4b82/modules/nf-core/samtools/bam2fq/main.nf#L30)).

#### Nextflow version bumping

If you use a new feature from core Nextflow, bump the minimum required Nextflow version in the pipeline with:

```bash
nf-core pipelines bump-version --nextflow . <min_nf_version>
```

#### Images and figures guidelines

If you update images or graphics, follow the nf-core [style guidelines](https://nf-co.re/docs/community/brand/workflow-schematics).

## Pipeline specific contribution guidelines

### Repository structure

The pipeline follows the nf-core DSL2 layout:

- `workflows/qcpanda.nf` — main workflow logic
- `modules/local/` — pipeline-specific modules (e.g. `generate_multiqc_config`, `sankey_plot`, `fastqscreen`, `kraken2_ratios`, `seqkit_pair`, `seqkit_stats_reads`, `sequali_rename`, `merge_outputs`, `ngscm_analysis`)
- `modules/nf-core/` — pinned nf-core community modules
- `subworkflows/local/` — local subworkflows (e.g. `utils_nfcore_qcpanda_pipeline`)
- `subworkflows/nf-core/` — nf-core community subworkflows (including `fastq_ngscheckmate`)
- `bin/` — helper scripts called from process `script:` blocks
- `conf/` — base, module, and container configuration files
- `assets/` — samplesheet schema, MultiQC config, and methods description template

### Adding or modifying a pipeline step

In addition to the general steps above, follow these conventions when modifying qcpanda:

- **Skip parameter**: every optional step must be guarded by a `params.skip_<tool>` boolean in `nextflow.config` and `nextflow_schema.json`. Default to `false` (enabled) for steps that should run on all datasets, `true` for steps that require external databases not always available (FastQ Screen, SortMeRNA).
- **MultiQC integration**: mix output files into `ch_multiqc_files` using `.map { _meta, file -> file }`. Add the corresponding suffix to `fn_clean_exts` in `bin/generate_multiqc_config.py` and a ranked entry in `report_section_order`.
- **Channel defaults**: use `channel.of([])` (not `channel.value([])`) for optional channels that may be empty; this avoids `DataflowVariable` race conditions.
- **Versions**: if a process does not emit a `versions` topic, add a `topic: 'versions'` emission with `versions.yml` or emit to `ch_versions`.

### Running local tests

Run the full pipeline test with nf-test and update snapshots after functional changes:

```bash
cd /path/to/qcpanda
nf-test test tests/default.nf.test --profile docker --verbose
nf-test test tests/default.nf.test --profile docker --update-snapshot
```

Run module-level nf-tests for a specific local module:

```bash
nf-test test modules/local/<module_name>/tests/main.nf.test --profile docker
```

Run Python unit tests for scripts in `bin/`:

```bash
PYTHONPATH=bin python3 -m unittest discover -s bin/tests -v
```

### Coding style

- Nextflow DSL2; no implicit `it` closure parameters — always declare explicit names (or prefix unused parameters with `_`).
- Shell scripts inside `script:` blocks: use `set -euo pipefail`; prefer named arrays over globs when filenames may collide.
- Python scripts in `bin/`: follow PEP 8; add unit tests in `bin/tests/` for all public functions.
- Keep local module environments minimal — pin only the tool actually used in `environment.yml`.

### Updating the MultiQC config generator

The `GENERATE_MULTIQC_CONFIG` process (`modules/local/generate_multiqc_config/main.nf`) runs `bin/generate_multiqc_config.py` to build `multiqc_config.yaml` at runtime. When adding a new tool:

1. Add the expected output suffix to `fn_clean_exts` in `generate_multiqc_config.py`.
2. Add the tool section name to `report_section_order` with an appropriate priority.
3. Update `assets/multiqc_config.yml` (used as fallback when `--multiqc_config` is supplied).
4. Add/update unit tests in `bin/tests/test_generate_multiqc_config.py`.
