process SANKEY_PLOT {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/r-base_r-highcharter_r-htmlwidgets_r-tidyverse:201fc062662efe89' :
        'community.wave.seqera.io/library/r-base_r-highcharter_r-htmlwidgets_r-tidyverse:b6a5d7b5e5c1726c' }"

    input:
    tuple val(meta), path(kraken_report)

    output:
    tuple val(meta), path("${meta.id}_sankey_plot.html"), emit: html
    tuple val("${task.process}"), val('r-highcharter'), eval('Rscript -e "cat(as.character(packageVersion(\'highcharter\')))"'), topic: versions, emit: versions_highcharter

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    """
    generate_sankey_plot.R \\
        ${kraken_report} \\
        ${meta.id}_sankey_plot.html \\
        ${args}
    """

    stub:
    """
    touch ${meta.id}_sankey_plot.html
    """
}
