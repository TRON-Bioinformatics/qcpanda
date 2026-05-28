process BRACKEN_READ_LENGTH {
    tag "$meta.id"
    label 'process_minimum'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/biopython:1.84' :
        'quay.io/biocontainers/biopython:1.84' }"

    input:
    tuple val(meta), path(reads)
    path(db)

    output:
    tuple val(meta), stdout, emit: read_length
    tuple val("${task.process}"), val('bracken_read_length'), eval('python --version | sed "s/Python //"'), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Use R1 (first read) to estimate read length; both reads have the same length
    def read1 = reads instanceof List ? reads[0] : reads
    """
    bracken_read_length.py \\
        -d ${db} \\
        -f ${read1}
    """

    stub:
    """
    echo -n "100"
    """
}
