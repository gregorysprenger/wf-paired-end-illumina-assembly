process ANNOTATE {

    publishDir "${params.outpath}/annot",
        mode: "${params.publish_dir_mode}",
        pattern: "*.gbk"
    publishDir "${params.process_log_dir}",
        mode: "${params.publish_dir_mode}",
        pattern: ".command.*",
        saveAs: { filename -> "${base}.${task.process}${filename}"}

    label "process_high"
    tag { "${base}" }

    container "snads/prokka@sha256:ef7ee0835819dbb35cf69d1a2c41c5060691e71f9138288dd79d4922fa6d0050"

    input:
        tuple val(base), val(size), path(paired_bam), path(single_bam), path(base_fna)

    output:
        tuple val(base), val(size), path("${base}.gbk"), emit: annotation
        path ".command.out"
        path ".command.err"
        path "versions.yml", emit: versions

    shell:
        '''
        source bash_functions.sh
        
        # Remove seperator characters from basename for future processes
        short_base=$(echo !{base} |  sed 's/[-._].*//g')
        sed -i "s/!{base}/${short_base}/g" !{base_fna}

        # Annotate cleaned and corrected assembly
        msg "INFO: Running prokka with !{task.cpus} threads"

        prokka --outdir prokka --prefix "!{base}"\
        --force --addgenes --locustag "!{base}" --mincontiglen 1\
        --evalue 1e-08 --cpus !{task.cpus} !{base_fna}

        for ext in gb gbf gbff gbk;
        do
            if [ -s "prokka/!{base}.${ext}" ]; then
                mv -f prokka/!{base}.${ext} !{base}.gbk
                break
            fi
        done

        verify_file_minimum_size "!{base}.gbk" 'annotated assembly' "!{size}" '0.11'

        # Get process version
        cat <<-END_VERSIONS > versions.yml
        "!{task.process}":
            prokka: $(prokka --version 2>&1 | awk 'NF>1{print $NF}')
        END_VERSIONS
        '''
}