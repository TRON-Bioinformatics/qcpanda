process MERGE_OUTPUTS {
    label 'process_minimum'

    conda "${moduleDir}/environment.yml"
    container "docker.io/library/ubuntu:20.04"

    input:
    path(input_files)
    val(output_name)

    output:
    path("${output_name}"), optional: true, emit: merged

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    cat ${input_files} | sort > ${output_name}
    """

    stub:
    """
    touch ${output_name}
    """
}
