process GENERATE_MULTIQC_CONFIG {
    tag 'generate_multiqc_config'
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9' :
        'quay.io/biocontainers/python:3.9' }"

    input:
    path sankey_htmls                                // list of {sample}_sankey_plot.html files, or [] if none
    path ngscm_plots                                 // ngscm_plots directory, or [] if none
    path(bracken_tsvs, stageAs: "bracken_tsvs/*")   // list of {sample}.tsv Bracken files, or [] if none

    output:
    path "multiqc_config.yaml", emit: config

    when:
    task.ext.when == null || task.ext.when

    script:
    def sankey_arg  = sankey_htmls  ? "--sankey_dir ."                   : ""
    def ngscm_arg   = ngscm_plots   ? "--ngscm_plots_dir ${ngscm_plots}" : ""
    def bracken_arg = bracken_tsvs  ? "--bracken_dir bracken_tsvs"       : ""
    """
    generate_multiqc_config.py \\
        --output_config multiqc_config.yaml \\
        ${sankey_arg} \\
        ${ngscm_arg} \\
        ${bracken_arg}
    """

    stub:
    """
    touch multiqc_config.yaml
    """
}
