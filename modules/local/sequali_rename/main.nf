process SEQUALI_RENAME {
    tag "$meta.id"
    label 'process_minimum'

    conda "conda-forge::sed=4.8"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'docker.io/library/ubuntu:20.04' }"

    input:
    tuple val(meta), path(json, stageAs: 'input.json'), path(reads)

    output:
    tuple val(meta), path("*.json"), emit: json

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    sed 's/${reads[0].name}/${prefix}/g' input.json > __tmp.json
    ${!meta.single_end ? "sed -i 's/${reads[1].name}/${prefix}/g' __tmp.json" : ''}
    mv __tmp.json ${prefix}.json
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.json
    """
}
