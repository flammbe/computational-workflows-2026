#!/usr/bin/env nextflow

process SPLITLETTERS {

    input:
    tuple val(meta), val(out_name), val(input_str)

    output:
    tuple val(meta), path("${out_name}_*")

    script:
    """
    printf '%s' "${input_str}" | split -b ${meta.block_size} - ${out_name}_
    """
}

process CONVERTTOUPPER {
    publishDir 'results', mode: 'copy'

    input:
    path chunk

    output:
    path "${chunk.name}.uppercase.txt"

    script:
    """
    tr '[:lower:]' '[:upper:]' < "${chunk}" > "${chunk.name}.uppercase.txt"
    """
}

workflow { 
    // 1. Read in the samplesheet (samplesheet_2.csv)  into a channel. The block_size will be the meta-map
    // 2. Create a process that splits the "in_str" into sizes with size block_size. The output will be a file for each block, named with the prefix as seen in the samplesheet_2
    // 4. Feed these files into a process that converts the strings to uppercase. The resulting strings should be written to stdout

    // read in samplesheet
    ch_in = channel.fromPath('samplesheet_2.csv')
        .splitCsv(header: true)
        .map { row -> tuple([block_size: row.block_size.toInteger()], row.out_name, row.input_str) }

    // split the input string into chunks
    ch_split = SPLITLETTERS(ch_in)

    // lets remove the metamap to make it easier for us, as we won't need it anymore
    ch_chunks = ch_split
        .transpose()
        .map { _meta, chunk -> chunk }

    // convert the chunks to uppercase and save the files to the results directory
    CONVERTTOUPPER(ch_chunks)
        .view()
}