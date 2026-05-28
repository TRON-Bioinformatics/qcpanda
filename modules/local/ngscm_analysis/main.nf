process NGSCM_ANALYSIS {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/r-base_r-fs_r-tidyverse:c0330fcdf996739f' :
        'community.wave.seqera.io/library/r-base_r-fs_r-tidyverse:bd814f04f784451b' }"

    input:
    tuple val(meta), path(vafncm_all), path(vafs)
    path patient_map

    output:
    tuple val(meta), path("ngscm_plots"),    optional: true, emit: plots
    tuple val(meta), path("ngscm_table.tsv"), optional: true, emit: table

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def patient_map_arg = patient_map ? "--patient_map ${patient_map}" : ""
    """
    ngscm_report.R \\
        --ngscm_all_file ${vafncm_all} \\
        --ngscm_vafs_folder . \\
        --ngscm_table ngscm_table.tsv \\
        --output_dir ngscm_plots \\
        ${patient_map_arg}
    """

    stub:
    """
    mkdir ngscm_plots
    touch ngscm_table.tsv
    """
}
