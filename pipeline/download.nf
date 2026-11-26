// =====================================================================
// download.nf — Descarga FASTQ desde NCBI SRA, comprimidos y sin pico
// de disco (fastq-dump --gzip). Opcional: submuestreo a N lecturas.
// Uso:
//   nextflow run pipeline/download.nf -profile aws -c pipeline/nextflow.config \
//     --ids pipeline/ids.csv --outdir s3://<bucket>/fastq --max_spots 30000000
// =====================================================================

params.ids       = null        // archivo con un SRR por línea
params.outdir    = null        // carpeta de salida (s3://...)
params.max_spots = 30000000    // lecturas por muestra; 0 = todas

process FASTQ_DUMP {
    tag "$srr"                                   // nombre que verás en el progreso
    container 'quay.io/biocontainers/sra-tools:3.2.1--h4304569_1'
    cpus 2
    memory '4 GB'
    errorStrategy 'retry'                        // la red falla: reintentar
    maxRetries 3
    publishDir params.outdir, mode: 'copy'       // copia los resultados a S3

    input:
    val srr

    output:
    tuple val(srr), path("${srr}_1.fastq.gz"), path("${srr}_2.fastq.gz")

    script:
    def limit = params.max_spots ? "-X ${params.max_spots}" : ""
    """
    fastq-dump --split-files --gzip ${limit} ${srr}
    """
}

workflow {
    // 1. Leer los SRR del archivo (uno por línea, sin líneas vacías)
    ids = Channel.fromPath(params.ids)
                 .splitText()
                 .map { it.trim() }
                 .filter { it }

    // 2. Descargar cada uno en paralelo
    FASTQ_DUMP(ids)

    // 3. Escribir el samplesheet para nf-core/rnaseq
    FASTQ_DUMP.out
        .map { srr, r1, r2 -> "${srr},${params.outdir}/${r1.name},${params.outdir}/${r2.name},auto" }
        .collectFile(name: 'samplesheet.csv',
                     seed: 'sample,fastq_1,fastq_2,strandedness',
                     newLine: true, sort: true,
                     storeDir: "${params.outdir}/samplesheet")
}
