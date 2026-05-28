process KRAKEN2_RATIOS {
    tag "$meta.id"
    label 'process_minimum'

    conda "conda-forge::gawk=5.3.0"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.3.0' :
        'biocontainers/gawk:5.3.0' }"

    input:
    tuple val(meta), path(kraken2_report)

    output:
    tuple val(meta), stdout,                                                                      emit: ratios
    tuple val("${task.process}"), val('gawk'), eval('gawk --version | head -1 | sed "s/GNU Awk //"'), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def ngscm_organism = params.ngscm_organism ?: 'Homo sapiens'
    """
    awk -F'\\t' '\$4=="U"{sum+=\$1} END{print sum/100}' ${kraken2_report}
    awk -F'\\t' '/${ngscm_organism}/{sum+=\$1} END{print sum/100}' ${kraken2_report}
    """

    stub:
    """
    printf '0\\n0'
    """
}
