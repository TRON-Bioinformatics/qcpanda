/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { SEQUALI                                 } from '../modules/nf-core/sequali/main'
include { SEQUALI_RENAME                          } from '../modules/local/sequali_rename/main'
include { GUNZIP as GUNZIP_RRNA_FASTAS            } from '../modules/nf-core/gunzip/main'
include { SORTMERNA as SORTMERNA_INDEX            } from '../modules/nf-core/sortmerna/main'
include { SORTMERNA                               } from '../modules/nf-core/sortmerna/main'
include { FASTQSCREEN_FASTQSCREEN as FASTQSCREEN  } from '../modules/local/fastqscreen/main'
include { FASTP                                   } from '../modules/nf-core/fastp/main'
include { FASTQC                                  } from '../modules/nf-core/fastqc/main'
include { SEQKIT_SANA            } from '../modules/nf-core/seqkit/sana/main'
include { SEQKIT_SAMPLE          } from '../modules/nf-core/seqkit/sample/main'
include { SEQKIT_STATS           } from '../modules/nf-core/seqkit/stats/main'
include { KRAKEN2_KRAKEN2        } from '../modules/nf-core/kraken2/kraken2/main'
include { UNTAR as UNTAR_KRAKEN2_DB        } from '../modules/nf-core/untar/main'
include { UNTAR as UNTAR_BRACKEN_DB        } from '../modules/nf-core/untar/main'
include { UNTAR as UNTAR_FASTQSCREEN_DB    } from '../modules/nf-core/untar/main'
include { KRAKEN2_RATIOS         } from '../modules/local/kraken2_ratios/main'
include { BRACKEN_READ_LENGTH    } from '../modules/local/bracken_read_length/main'
include { BRACKEN_BRACKEN        } from '../modules/nf-core/bracken/bracken/main'
include { SANKEY_PLOT            } from '../modules/local/sankey_plot/main'
include { FASTQ_NGSCHECKMATE     } from '../subworkflows/nf-core/fastq_ngscheckmate/main'
include { NGSCM_ANALYSIS         } from '../modules/local/ngscm_analysis/main'
include { GENERATE_MULTIQC_CONFIG } from '../modules/local/generate_multiqc_config/main'
include { SEQKIT_PAIR            } from '../modules/local/seqkit_pair/main'
include { SEQKIT_STATS_READS     } from '../modules/local/seqkit_stats_reads/main'
include { MERGE_OUTPUTS          } from '../modules/local/merge_outputs/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_qcpanda_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow QCPANDA {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:

    def ch_versions = channel.empty()

    // Optional channels fed into GENERATE_MULTIQC_CONFIG; remain empty lists
    // when the corresponding steps are skipped.
    // Both are queue channels that emit exactly once so that GENERATE_MULTIQC_CONFIG
    // waits for both before running (avoids race between SANKEY_PLOT and NGSCM_ANALYSIS).
    def ch_sankey_htmls  = channel.of([])
    def ch_ngscm_plots   = channel.of([])
    def ch_bracken_tsvs  = channel.of([])
    def ch_multiqc_files = channel.empty()
    //
    // MODULE: Run SeqKit Sana to sanitize reads before statistics
    //
    def ch_reads_for_stats = ch_samplesheet
    if (!params.skip_seqkit_sana) {
        SEQKIT_SANA(
            ch_samplesheet.flatMap { meta, reads ->
                reads.withIndex().collect { read, idx ->
                    [meta + [read_idx: idx], read]
                }
            }
        )
        ch_reads_for_stats = SEQKIT_SANA.out.reads
            .map { meta, read -> [meta - [read_idx: meta.read_idx], read] }
            .groupTuple()
    }

    //
    // MODULE: Run SeqKit Stats
    //
    SEQKIT_STATS(ch_reads_for_stats)

    //
    // MODULE: Extract read counts and flag FASTQs under minimum threshold
    //
    SEQKIT_STATS_READS(SEQKIT_STATS.out.stats)

    //
    // Filter samples below minimum read number threshold
    //
    def ch_input_above_min = ch_samplesheet
        .join(SEQKIT_STATS_READS.out.read_number)
        .filter { _meta, _reads, read_number_str ->
            def values = read_number_str.trim().split('\n')*.toLong()
            values.every { val -> val >= params.minimum_read_number }
        }

    ch_input_above_min.ifEmpty {
        error "ERROR ~ No samples passed the read number filter of ${params.minimum_read_number} reads."
    }

    //
    // MODULE: Merge per-sample fastqs_under_th files into a single output file
    //
    MERGE_OUTPUTS(
        SEQKIT_STATS_READS.out.fastqs_under_th.collect(),
        "fastqs_under_th.txt"
    )

    //
    // Branch paired-end samples by R1/R2 read count equality
    //
    def ch_input_equal = ch_input_above_min
        .filter { _meta, _reads, read_number_str ->
            def values = read_number_str.trim().split('\n')*.toLong()
            values.size() == 1 || values[0] == values[1]
        }
        .map { meta, reads, _read_number_str -> [ meta, reads ] }

    def ch_input_unequal = ch_input_above_min
        .filter { _meta, _reads, read_number_str ->
            def values = read_number_str.trim().split('\n')*.toLong()
            values.size() == 2 && values[0] != values[1]
        }
        .map { meta, reads, _read_number_str -> [ meta, reads ] }

    //
    // MODULE: Run SeqKit Pair on samples with unequal R1/R2 read counts
    //
    def ch_input_paired
    if (!params.skip_seqkit_pair) {
        SEQKIT_PAIR(ch_input_unequal)
        ch_input_paired = ch_input_equal.mix(SEQKIT_PAIR.out.reads)
    } else {
        ch_input_paired = ch_input_equal
    }

    //
    // MODULE: Run FastQC on paired reads (equal samples + seqkit pair output);
    // when seqkit pair is skipped, also include unequal samples as-is
    //
    if (!params.skip_fastqc) {
        def ch_fastqc_input = params.skip_seqkit_pair
            ? ch_input_paired.mix(ch_input_unequal)
            : ch_input_paired
        FASTQC(ch_fastqc_input)
        ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.map { _meta, zip -> zip })
    }

    //
    // MODULE: Run Fastp for adapter trimming and quality filtering
    //
    if (!params.skip_fastp) {
        FASTP(
            ch_input_paired.map { meta, reads -> [ meta, reads, [] ] },
            params.fastp_discard_trimmed_pass,
            params.fastp_save_trimmed_fail,
            params.fastp_save_merged
        )
        ch_multiqc_files = ch_multiqc_files.mix(FASTP.out.json.map { _meta, json -> json })
    }

    //
    // MODULE: Run Sequali for QC reporting, then rename FASTQ paths in the JSON
    // to sample name so MultiQC displays sample names correctly
    //
    if (!params.skip_sequali) {
        SEQUALI(ch_input_paired)
        SEQUALI_RENAME(
            SEQUALI.out.json.join(
                ch_input_paired
            )
        )
        ch_multiqc_files = ch_multiqc_files.mix(SEQUALI_RENAME.out.json.map { _meta, json -> json })
    }

    //
    // MODULE: Run FastQ Screen to screen reads for contamination against multiple genomes
    //
    if (!params.skip_fastq_screen) {
        // Parse CSV and branch: tarballs (.tar.gz/.tgz) go through UNTAR; S3/dir paths are used directly
        def ch_refs_rows = channel.fromPath(params.fastq_screen_references, checkIfExists: true)
            .splitCsv(header: true)
            .branch { row ->
                tarball:   row.dir ==~ /.*\.(tar\.gz|tgz|tar\.bz2)$/
                directory: true
            }

        UNTAR_FASTQSCREEN_DB(
            ch_refs_rows.tarball.map { row ->
                [[id: row.name, basename: row.basename, aligner: row.aligner], file(row.dir, checkIfExists: true)]
            }
        )

        def ch_from_tarball = UNTAR_FASTQSCREEN_DB.out.untar
            .map { meta, dir -> [meta.id, dir, meta.basename, meta.aligner] }

        def ch_from_dir = ch_refs_rows.directory
            .map { row -> [row.name, file(row.dir, checkIfExists: true), row.basename, row.aligner] }

        def ch_fastqscreen_refs = ch_from_tarball
            .mix(ch_from_dir)
            .toList()
            .transpose()
            .toList()

        FASTQSCREEN(
            ch_input_paired,
            ch_fastqscreen_refs
        )
        ch_multiqc_files = ch_multiqc_files.mix(FASTQSCREEN.out.txt.map { _meta, txt -> txt })
    }

    //
    // MODULE: Run SortMeRNA to quantify rRNA contamination
    //
    if (!params.skip_sortmerna) {
        // Read rRNA reference FASTAs from the text file; gunzip any .gz files
        def ch_rrna_inputs = channel.from(
                file(params.sortmerna_ref_txt, checkIfExists: true).readLines()
            )
            .map { line -> file(line.trim(), checkIfExists: true) }
            .branch { fasta ->
                gz:    fasta.name.endsWith('.gz')
                plain: true
            }

        def ch_rrna_fastas = GUNZIP_RRNA_FASTAS(
                ch_rrna_inputs.gz.map { fasta -> [ [:], fasta ] }
            )
            .gunzip
            .map { _meta, fasta -> fasta }
            .mix(ch_rrna_inputs.plain)

        // Build SortMeRNA index once from all rRNA references
        SORTMERNA_INDEX(
            channel.of([ [:], [] ]),
            ch_rrna_fastas.collect().map { refs -> [ [id: 'rrna_refs'], refs ] },
            channel.of([ [:], [] ])
        )

        // Run SortMeRNA per sample using the pre-built index
        SORTMERNA(
            ch_input_paired,
            ch_rrna_fastas.collect().map { refs -> [ [id: 'rrna_refs'], refs ] },
            SORTMERNA_INDEX.out.index.first()
        )
        ch_multiqc_files = ch_multiqc_files.mix(SORTMERNA.out.log.map { _meta, log -> log })
    }

    //
    // Subsample reads for Kraken2 organism detection
    // (other QC tools run on full reads via ch_input_paired)
    //
    if (!params.skip_kraken2) {
        // Prepare Kraken2 database channel:
        // Accepts either a directory path or a .tar.gz archive; the archive is unpacked at runtime.
        def ch_kraken2_db
        if (params.kraken2_db?.endsWith('.tar.gz')) {
            UNTAR_KRAKEN2_DB([[id: 'kraken2_db'], file(params.kraken2_db, checkIfExists: true)])
            ch_kraken2_db = UNTAR_KRAKEN2_DB.out.untar.map { _meta, db -> db }.first()
        } else {
            ch_kraken2_db = channel.value(file(params.kraken2_db, checkIfExists: true))
        }

        SEQKIT_SAMPLE(
            ch_input_paired.flatMap { meta, reads ->
                (reads instanceof List ? reads : [reads]).withIndex().collect { read, idx ->
                    [ meta + [read_idx: idx], read ]
                }
            }
        )
        def ch_reads_for_kraken = SEQKIT_SAMPLE.out.fastx
            .map { meta, read -> [ meta - [read_idx: meta.read_idx], read ] }
            .groupTuple()
        def save_reads_assignment = (!params.skip_bracken || !params.skip_ngscm)
        KRAKEN2_KRAKEN2(
            ch_reads_for_kraken,
            ch_kraken2_db,
            false,                  // save_output_fastqs
            save_reads_assignment   // save per-read assignment when needed for ratios
        )
        ch_multiqc_files = ch_multiqc_files.mix(KRAKEN2_KRAKEN2.out.report.map { _meta, report -> report })

        // Compute unclassified + organism ratios; needed by Bracken and NGSCheckMate
        if (!params.skip_bracken || !params.skip_ngscm) {
            KRAKEN2_RATIOS(
                KRAKEN2_KRAKEN2.out.report
            )
        }

        // Determine best Bracken k-mer length, then run Bracken abundance estimation
        // only for samples with unclassified ratio below the configured threshold.
        if (!params.skip_bracken) {
            def ch_reports_for_bracken = KRAKEN2_KRAKEN2.out.report
                .join(KRAKEN2_RATIOS.out.ratios)
                .filter { _meta, _report, ratios ->
                    def lines = ratios.trim().split('\n')
                    lines.size() >= 1 && lines[0].toDouble() < params.unclassified_ratio_th
                }
                .map { meta, report, _ratios -> [ meta, report ] }

            def ch_reads_for_bracken = ch_reads_for_kraken
                .join(KRAKEN2_RATIOS.out.ratios)
                .filter { _meta, _reads, ratios ->
                    def lines = ratios.trim().split('\n')
                    lines.size() >= 1 && lines[0].toDouble() < params.unclassified_ratio_th
                }
                .map { meta, reads, _ratios -> [ meta, reads ] }

            // Prepare Bracken database channel:
            // Accepts either a directory path or a .tar.gz archive; the archive is unpacked at runtime.
            // If bracken_db points to the same archive as kraken2_db, reuse the already-unpacked channel.
            def ch_bracken_db
            if (params.bracken_db == params.kraken2_db && params.kraken2_db?.endsWith('.tar.gz')) {
                ch_bracken_db = ch_kraken2_db
            } else if (params.bracken_db?.endsWith('.tar.gz')) {
                UNTAR_BRACKEN_DB([[id: 'bracken_db'], file(params.bracken_db, checkIfExists: true)])
                ch_bracken_db = UNTAR_BRACKEN_DB.out.untar.map { _meta, db -> db }.first()
            } else {
                ch_bracken_db = channel.value(file(params.bracken_db, checkIfExists: true))
            }

            BRACKEN_READ_LENGTH(ch_reads_for_bracken, ch_bracken_db)
            BRACKEN_BRACKEN(
                ch_reports_for_bracken
                    .join(BRACKEN_READ_LENGTH.out.read_length)
                    .map { meta, report, klen -> [ meta + [read_length: klen.trim()], report ] },
                ch_bracken_db
            )
            ch_bracken_tsvs = BRACKEN_BRACKEN.out.reports
                .map { _meta, tsv -> tsv }
                .collect()
                .ifEmpty([])

            if (!params.skip_sankey) {
                SANKEY_PLOT(BRACKEN_BRACKEN.out.txt)
                ch_sankey_htmls = SANKEY_PLOT.out.html
                    .map { _meta, html -> html }
                    .collect()
                    .ifEmpty([])
            }
        }

        // Verify sample identity via NGSCheckMate on samples enriched for the target organism
        if (!params.skip_ngscm) {
            // Filter to samples where the organism ratio meets the minimum threshold
            def ch_reads_for_ngscm = ch_input_paired
                .join(KRAKEN2_RATIOS.out.ratios)
                .filter { _meta, _reads, ratios ->
                    def lines = ratios.trim().split('\n')
                    lines.size() >= 2 && lines[1].toDouble() >= params.execute_ngscm_threshold
                }
                .map { meta, reads, _ratios -> [ meta, reads ] }

            FASTQ_NGSCHECKMATE(
                ch_reads_for_ngscm,
                channel.of([ [id: 'snp_pt'], file(params.ngscm_snp_patternsfile, checkIfExists: true) ])
            )

            NGSCM_ANALYSIS(
                FASTQ_NGSCHECKMATE.out.all
                    .join(
                        FASTQ_NGSCHECKMATE.out.vaf
                            .map { _meta, vaf -> vaf }
                            .collect()
                            .map { vafs -> [ [id: 'snp_pt'], vafs ] }
                    ),
                params.ngscm_patient_map
                    ? channel.value(file(params.ngscm_patient_map, checkIfExists: true))
                    : channel.value([])
            )
            ch_ngscm_plots = NGSCM_ANALYSIS.out.plots
                .map { _meta, dir -> dir }
                .ifEmpty([])
        }
    }

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name:  'qcpanda_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: Generate MultiQC config (waits for sankey + ngscm analysis)
    //
    GENERATE_MULTIQC_CONFIG(ch_sankey_htmls, ch_ngscm_plots, ch_bracken_tsvs)

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))

    // Build a proper channel for the MultiQC config so Nextflow resolves it as a
    // channel dependency rather than a literal closure value.
    def ch_multiqc_config = multiqc_config
        ? channel.value(file(multiqc_config, checkIfExists: true))
        : GENERATE_MULTIQC_CONFIG.out.config

    MULTIQC(
        ch_multiqc_files.flatten().collect()
            .map { files -> [[id: 'qcpanda'], files] }
            .combine(ch_multiqc_config)
            .map { meta, files, config ->
                [
                    meta,
                    files,
                    config,
                    multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                    [],
                    [],
                ]
            }
    )
    emit:multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
