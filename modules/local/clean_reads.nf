process CLEAN_READS {

    publishDir "${params.outpath}/asm",
        mode: "${params.publish_dir_mode}",
        pattern: "*.txt"
    publishDir "${params.outpath}/asm",
        mode: "${params.publish_dir_mode}",
        pattern: "*.fna"
    publishDir "${params.process_log_dir}",
        mode: "${params.publish_dir_mode}",
        pattern: ".command.*",
        saveAs: { filename -> "${base}.${task.process}${filename}"}

    label "process_high"
    tag { "${base}" }

    container "gregorysprenger/bwa-samtools-pilon@sha256:209ac13b381188b4a72fe746d3ff93d1765044cbf73c3957e4e2f843886ca57f"
    
    input:
        tuple val(base), val(size), path(R1_paired_gz), path(R2_paired_gz), path(single_gz), path(uncorrected_contigs)

    output:
        tuple val(base), val(size), path("${base}.paired.bam"), path("${base}.single.bam"), emit: bam
        tuple val(base), path("${base}.fna"), emit: base_fna
        path "${base}.InDels-corrected.cnt.txt"
        path "${base}.SNPs-corrected.cnt.txt"
        path ".command.out"
        path ".command.err"
        path "versions.yml", emit: versions

    shell:
        '''
        source bash_functions.sh

        # Correct cleaned SPAdes contigs with cleaned PE reads
        verify_file_minimum_size "!{uncorrected_contigs}" 'filtered SPAdes assembly' "!{size}" '0.1'

        echo -n '' > !{base}.InDels-corrected.cnt.txt
        echo -n '' > !{base}.SNPs-corrected.cnt.txt

        msg "INFO: Correcting contigs with PE reads using !{task.cpus} threads"

        for _ in {1..3}; do
            bwa index !{uncorrected_contigs}

            bwa mem -t !{task.cpus} -x intractg -v 2 !{uncorrected_contigs}\
            !{R1_paired_gz} !{R2_paired_gz} |\
            samtools sort -@ !{task.cpus} --reference !{uncorrected_contigs} -l 9\
            -o !{base}.paired.bam

            verify_file_minimum_size "!{base}.paired.bam" 'binary sequence alignment map' "!{size}" '0.8'

            samtools index !{base}.paired.bam

            pilon --genome !{uncorrected_contigs} --frags !{base}.paired.bam\
            --output "!{base}" --changes \
            --fix snps,indels --mindepth 0.50 --threads !{task.cpus} >&2

            verify_file_minimum_size "!{uncorrected_contigs}" 'polished assembly' "!{size}" '0.1'

            echo $(grep -c '-' !{base}.changes >> !{base}.InDels-corrected.cnt.txt)
            echo $(grep -vc '-' !{base}.changes >> !{base}.SNPs-corrected.cnt.txt)

            rm -f !{base}.{changes,uncorrected.fna}
            rm -f "!{base}"Pilon.bed
            mv -f !{base}.fasta !{base}.uncorrected.fna

            sed -i 's/_pilon//1' !{base}.uncorrected.fna

        done

        mv -f !{base}.uncorrected.fna !{base}.fna

        verify_file_minimum_size "!{base}.fna" 'corrected SPAdes assembly' "!{size}" '0.1'

        # Single read mapping if available
        if [[ !{single_gz} ]]; then
            msg "INFO: Single read mapping with !{task.cpus} threads"
            bwa index !{base}.fna

            bwa mem -t !{task.cpus} -x intractg -v 2 !{base}.fna\
            !{single_gz} |\
            samtools sort -@ !{task.cpus} --reference !{base}.fna -l 9\
            -o !{base}.single.bam

            verify_file_minimum_size "!{base}.single.bam" 'binary sequence alignment map' '1k' '100'
            samtools index !{base}.single.bam

        fi

        # Get process version
        cat <<-END_VERSIONS > versions.yml
        "!{task.process}":
            bwa: $(bwa 2>&1 | head -n 3 | tail -1 | awk 'NF>1{print $NF}')
            samtools: $(samtools --version | head -n 1 | awk 'NF>1{print $NF}')
            pilon: $(pilon --version | cut -d ' ' -f 3)
        END_VERSIONS
        '''
}