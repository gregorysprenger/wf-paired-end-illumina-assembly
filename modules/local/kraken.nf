process KRAKEN_ONE {

    publishDir "${params.outpath}/trim_reads",
        mode: "${params.publish_dir_mode}",
        pattern: "*.tab*"
    publishDir "${params.process_log_dir}",
        mode: "${params.publish_dir_mode}",
        pattern: ".command.*",
        saveAs: { filename -> "${base}.${task.process}${filename}"}

    label "process_high"
    tag { "${base}" }

    container "staphb/kraken@sha256:d372099288c3a7c0cc90ea7e516c643e7096c90a551b45d531bd26b4e7f46255"

    input:
        tuple val(base), val(size), path(R1_paired_gz), path(R2_paired_gz), path(single_gz)
        path kraken1_db

    output:
        path "${base}.taxonomy1-reads.tab"
        path "${base}_kraken1.tab.gz"
        path ".command.out"
        path ".command.err"
        path "versions.yml", emit: versions

    shell:
        '''
        source bash_functions.sh
        source summarize_kraken.sh

        if [[ -d "!{kraken1_db}" ]]; then
            database="!{kraken1_db}"
            msg "INFO: Using user specified Kraken 1 database: !{params.kraken1_db}"
        else
            database="/kraken-database/minikraken_20171013_4GB"
            msg "INFO: Using pre-loaded MiniKraken database for Kraken 1"
        fi

        # Investigate taxonomic identity of cleaned reads
        if [ ! -s !{base}.taxonomy1-reads.tab ]; then
            msg "INFO: Running Kraken1 with !{task.cpus} threads"
            kraken --db ${database} --threads !{task.cpus} --fastq-input --gzip-compressed \
            !{R1_paired_gz} !{R2_paired_gz} !{single_gz} > !{base}_kraken.output

            msg "INFO: Running kraken-report"
            kraken-report --db ${database} !{base}_kraken.output > kraken.tab 2>&1 | tr '^M' '\n' 1>&2

            msg "INFO: Summarizing Kraken1"
            summarize_kraken 'kraken.tab' > !{base}.taxonomy1-reads.tab

            mv kraken.tab !{base}_kraken1.tab
            gzip !{base}_kraken1.tab
        fi

        # Get process version
        echo -e "\"!{task.process}\":" > versions.yml
        echo -e "    kraken: $(kraken --version | head -n 1 | awk 'NF>1{print $NF}')" >> versions.yml
        '''
}

process KRAKEN_TWO {

    publishDir "${params.outpath}/trim_reads",
        mode: "${params.publish_dir_mode}",
        pattern: "*.tab*"
    publishDir "${params.process_log_dir}",
        mode: "${params.publish_dir_mode}",
        pattern: ".command.*",
        saveAs: { filename -> "${base}.${task.process}${filename}"}

    label "process_high"
    tag { "${base}" }

    container "staphb/kraken2@sha256:5b107d0141d6042a6b0ac6a5852990dc541fbff556a85eb0c321a7771200ba56"

    input:
        tuple val(base), val(size), path(R1_paired_gz), path(R2_paired_gz), path(single_gz)
        path kraken2_db

    output:
        path "${base}.taxonomy2-reads.tab"
        path "${base}_kraken2.tab.gz"
        path ".command.out"
        path ".command.err"
        path "versions.yml", emit: versions

    shell:
        '''
        source bash_functions.sh
        source summarize_kraken.sh

        if [[ -d "!{kraken2_db}" ]]; then
            database="!{kraken2_db}"
            msg "INFO: Using user specified Kraken 2 database: !{params.kraken2_db}"
        else
            database="/kraken2-db"
            msg "INFO: Using pre-loaded MiniKraken2 database for Kraken 2"
        fi

        if [ ! -s !{base}.taxonomy2-reads.tab ]; then
            msg "INFO: Running Kraken2 with !{task.cpus} threads"
            kraken2 --db "${database}" --threads !{task.cpus} --gzip-compressed --output /dev/null \
            --use-names --report kraken2.tab \
            !{R1_paired_gz} !{R2_paired_gz} !{single_gz}

            msg "INFO: Summarizing Kraken2"
            summarize_kraken 'kraken2.tab' > !{base}.taxonomy2-reads.tab

            mv kraken2.tab !{base}_kraken2.tab
            gzip !{base}_kraken2.tab

        fi

        # Get process version
        cat <<-END_VERSIONS > versions.yml
        "!{task.process}":
            kraken2: $(kraken2 --version | head -n 1 | awk 'NF>1{print $NF}')
        END_VERSIONS
        '''
}