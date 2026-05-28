process SEQKIT_STATS_READS {
    tag "${meta.id}"
    label 'process_minimum'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/ubuntu:20.04'
        : 'ubuntu:20.04'}"

    input:
    tuple val(meta), path(stats_tsv)

    output:
    tuple val(meta), stdout,                              emit: read_number
    path("fastqs_under_th_${meta.id}.txt"), optional: true, emit: fastqs_under_th

    when:
    task.ext.when == null || task.ext.when

    script:
    def min_reads = params.minimum_read_number ?: 1
    """
    mapfile -t read_counts < <(
        awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if(\$i=="num_seqs")c=i} NR>1{print \$c}' ${stats_tsv}
    )
    mapfile -t file_names < <(
        awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if(\$i=="file")c=i} NR>1{print \$c}' ${stats_tsv}
    )
    if [ \${#read_counts[@]} -eq 0 ]; then
        echo "${meta.id}.empty.fastq.gz" >> fastqs_under_th_${meta.id}.txt
        echo "0"
    else
        for i in "\${!read_counts[@]}"; do
            if [ ! "\${read_counts[\$i]+x}" ] || [ -z "\${read_counts[\$i]}" ]; then
                echo "\${file_names[\$i]:-empty.fastq.gz}" >> fastqs_under_th_${meta.id}.txt
                read_counts[\$i]=0
            elif [ "\${read_counts[\$i]}" -lt ${min_reads} ]; then
                echo "\${file_names[\$i]}" >> fastqs_under_th_${meta.id}.txt
            fi
            echo "\${read_counts[\$i]}"
        done
    fi
    """

    stub:
    """
    echo "0"
    touch fastqs_under_th_${meta.id}.txt
    """
}
