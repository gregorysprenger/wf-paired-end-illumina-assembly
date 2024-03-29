# wf-paired-end-illumina-assembly: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.0.3 - November 27, 2023

### `Added`

- Catching of errors in bash runner scripts for BBDuk and SPAdes.
- Add sample name and assembler name to outputs.
- Added and sorted error codes in bash runner script to ignore if process is resubmitted and completes.
- Allow output of "fastq" or "fq" files from subsampled reads module.
- Within rosalind_hpc.config, resubmit SPAdes if the exit code is anything other than zero.

### `Fixed`

- Fixed parsing of 16S BLAST database input so that results have species names.
- Quast and Kraken1 software versions information is now parsed correctly.
- Bash runner scripts are updated to correctly parse run information for errors.
- Fixed publishDir for SPAdes and Kraken1 so that output files are placed into outdir.
- Concatenation of QC filechecks to create one large summary.
- Removal of input reads if reads are subsampled to avoid original and subsampled reads to be passed to downstream processes.

### `Updated`

- Ignore header when counting number of lines in genome coverage summary file within bash runner script.
- Changed number of retries for SPAdes in rosalind_hpc.config to 5.
- Removed non-working loop in SPAdes module as the process should be resubmitted to abide by resource constraints.
- Changed rosalind_hpc.config high memory parameter and allow memory to be increased for resubmissions.
- Consolidated input and outputs for each module.
- Updated QC filecheck function to remove failed inputs from downstream processes without terminating entire workflow.
- Parsed out meta information when collecting outputfiles to create a concatenated summary file.
- Added the addition of headers to QC filechecks within each module.
- Dropped forced reformatting of FastQ files within BBDuk module.

### `Deprecated`

## v2.0.2 - November 16, 2023

### `Added`

### `Fixed`

- Added collect operators to database/reference channels to allow for all inputs to be analyzed for each process
- Removed extra slashes '/' from run_assembly.uge-nextflow scripts
- Updated paths for summary email when using run_assembly.uge-nextflow scripts

### `Updated`

### `Deprecated`

## v2.0.1 - November 16, 2023

### `Added`

### `Fixed`

- Made bin directory executable when added to github so Nextflow can use them
- Changed log directory to pipeline_info directory in run_assembly.uge-nextflow scripts
- Removed --gtdb_db from run_assembly.uge-nextflow scripts until GTDB-Tk module version is updated

### `Updated`

### `Deprecated`

## v2.0.0 - November 15, 2023

### `Added`

- nf-core Styling
- Allow samplesheet (XLSX, CSV, TSV) OR directory as input
- Use SKESA instead of SPAdes for assembling contigs
- Downsampling of input FastQ files
- Contig taxonomic classification using GTDB-Tk
- Intra-contig gene information using BUSCO
- Ability to use a BUSCO config file
- Always reformat FastQ files before removing PhiX using BBDuk
- Database prep modules to decompress and extract databases
- Function to check QC File Checks if they fail and place them in the QC log directory to remove the hassle of passing these files to each subsequent module
- Comments in input/output channels in subworkflows to make it easier to reference for future changes/additions
- Added "-\<assembler\>" to outputs after contigs are assembled
- Added headers to each output file
- Option to change the "mode" of SPAdes (ie. isolate, meta, etc.)
- Option to use different k-mer sizes for SPAdes
- Added evalue similarity cut-off to Prokka
- Ability to use a curated protein file along with Prokka's database

### `Fixed`

- Errors in run_assembly.uge-nextflow scripts
- Handle "lock" issues when using the same work directory with run_assembly.uge-nextflow scripts
- Remove duplicate rows and junk information in errors.tsv if workflow fails due to a locked session
- Updated "INFO" messages to be more readable

### `Updated`

- Docker containers to ensure they all have built in tests and removed built-in databases
- More comments and whitespace to separate information in conf/params.config
- Separated kraken1 and kraken2 modules
- Use channels for databases instead of passing params
- Use downloadable database .tar.gz files instead of using built-in databases in docker images
- Converted spades and skesa workflows into one workflow and use subworkflows "downsampling.nf" and "assemble_contigs.nf"
- Renamed assemble*{spades,skesa} to assemble_contigs*{spades,skesa}
- **CHANGED OUTPUT FILE STRUCTURE:** Output files are generally under the name of the tool that produced them
- Updated docs/output.md to reflect new file structure
- Removed QC file checking from modules and use checkQCFileChecks function in workflows/assembly.nf and subworkflows/assemble_contigs.nf
- Renamed emit names to hopefully clarify what each output means
- Moved all `publishDir` information to conf/modules.config
- Set filter contig length to 1000
- Place .command.{out,err} on one line for each module
- Added content section to main README.md to allow for easier navigation
- Added BUSCO and GTDB-Tk references to CITATIONS.md
- Parsing of BBDuk output to add more information to a PhiX Summary file
- Fixed github actions to properly run

### `Deprecated`

## v1.0.0 - January 20, 2023

Initial release of wf-paired-end-illumina-assembly.
