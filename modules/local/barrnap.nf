process BARRNAP {

    publishDir "${params.outpath}/ssu",
        mode: "${params.publish_dir_mode}",
        pattern: "*.fa"
    publishDir "${params.process_log_dir}",
        mode: "${params.publish_dir_mode}",
        pattern: ".command.*",
        saveAs: { filename -> "${base}.${task.process}${filename}"}

    tag { "${base}" }
    
    container "snads/barrnap@sha256:e22cbd789c36d5626460feb6c7e5f6f7d55c8628dacae68ba0da30884195a837"

    input:
        tuple val(base), val(size), path(annotation), path(base_fna), path(extracted_rna)

    output:
        tuple val(base), val(size), path("16S.${base}.fa"), emit: extracted_base
        path ".command.out"
        path ".command.err"
        path "versions.yml", emit: versions

    shell:
        '''
        source bash_functions.sh

        if [[ ! -f "!{extracted_rna}" ]] || [[ ! -s "!{extracted_rna}" ]]; then
            msg "INFO: absent 16S rRNA gene annotation in !{annotation}" >&2
            msg 'Running barrnapp' >&2
            barrnap !{base_fna} > !{base}.gff
            bedtools getfasta \
                -fi !{base_fna} \
                -bed !{base}.gff \
                -fo 16S.!{base}.fa

            if [[ $(grep -c '>' "!{extracted_rna}") -eq 0 ]]; then
                msg "INFO: RNAmmer was unable to locate a 16S rRNA gene sequence in !{base_fna}" >&2
                rm "16S.!{base}.fa"
                exit 2
            fi
        fi

        verify_file_minimum_size "16S.!{base}.fa" '16S extracted FastA file' '500c' '100'

        awk -v awk_var="!{base}" '/^>/{print ">" awk_var "_" ++i; next} {print}' \
        16S.!{base}.fa > !{base}.fa-renamed
        rm -f 16S.!{base}.fa
        mv -f !{base}.fa-renamed 16S.!{base}.fa

        verify_file_minimum_size "16S.!{base}.fa" '16S extracted and renamed FastA file' '500c' '100'

        # Get process version
        cat <<-END_VERSIONS > versions.yml
        "!{task.process}":
            barrnap: $(barrnap --version 2>&1 | awk 'NF>1{print $NF}')
        END_VERSIONS
        '''
}