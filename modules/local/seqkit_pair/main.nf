process SEQKIT_PAIR {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/seqkit:2.9.0--h9ee0642_0':
        'quay.io/biocontainers/seqkit:2.9.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.paired.fastq.gz")                  , emit: reads
    tuple val(meta), path("*.unpaired.fastq.gz"), optional: true, emit: unpaired_reads
    tuple val("${task.process}"), val('seqkit'), eval("seqkit version | sed 's/^.*v//'"), emit: versions_seqkit, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def stem1  = reads[0].getName().replaceAll(/\.(fastq|fq)(\.gz)?$/, '')
    def stem2  = reads[1].getName().replaceAll(/\.(fastq|fq)(\.gz)?$/, '')
    """
    seqkit \\
        pair \\
        -1 ${reads[0]} \\
        -2 ${reads[1]} \\
        $args \\
        --threads $task.cpus

    # gzip fastq
    find . -maxdepth 1 -name "*.fastq" -exec gzip {} +

    # rename outputs to use sample prefix
    mv ${stem1}.paired.fastq.gz ${prefix}_1.paired.fastq.gz
    mv ${stem2}.paired.fastq.gz ${prefix}_2.paired.fastq.gz

    # rename unpaired outputs if they exist (only produced when -u is passed)
    [ -f ${stem1}.unpaired.fastq.gz ] && mv ${stem1}.unpaired.fastq.gz ${prefix}_1.unpaired.fastq.gz || true
    [ -f ${stem2}.unpaired.fastq.gz ] && mv ${stem2}.unpaired.fastq.gz ${prefix}_2.unpaired.fastq.gz || true
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}_1.paired.fastq.gz
    echo "" | gzip > ${prefix}_2.paired.fastq.gz
    """

}
