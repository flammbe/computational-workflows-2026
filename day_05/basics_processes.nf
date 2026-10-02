params {
    step: Integer = 0
    zip: String = 'zip'
}


process SAYHELLO {
    debug true
    script:
    """
        echo 'Hello world!'
    """
}

process SAYHELLO_PYTHON {
    debug true
    script:
    """
        python3 -c "print('Hello world!')"
    """
}

process SAYHELLO_PARAM {
    debug true

    input:
    val hello

    script:
    """
        echo $hello
    """
}

process SAYHELLO_FILE {
    debug true

    publishDir 'results', mode: 'copy'

    input:
    val hello

    output:
    path 'hello_file.txt'

    script:
    """
        echo $hello > hello_file.txt
    """
}

process UPPERCASE {
    debug true

    publishDir 'results', mode: 'copy'

    input:
    val hello

    output:
    path 'hello_upper.txt'

    script:
    """
        hello="${hello}"                        # save hello in bash variable
        echo "\${hello^^}" > hello_upper.txt    # capitalize this variable and print it to the output file
    """
}

process PRINTUPPER {
    debug true

    input:
    path hello_file

    script:
    """
        cat ${hello_file}
    """
}

process ZIP {
    debug true
    stageInMode 'copy' // necessary to copy file in work dir, simlink is not enough, since we wnat to zip it.

    publishDir 'results', mode: 'copy'

    input:
    path hello

    output:
    path "${params.zip == 'zip' ? hello.baseName + '.zip' : hello.name + (params.zip == 'gzip' ? '.gz' : '.bz2')}"

    script:
    if(params.zip=='zip'){
        """
            zip "${hello.baseName}.zip" "$hello"
        """
    }
    else if(params.zip in ['gzip', 'bzip2']) { // They both use the same format for their work, so same cammand (different tool) can be used.
        """
            ${params.zip} -k "$hello"
        """
    }
    else {
        """
            echo "Compression format isn't supported" >&2
            exit 1
        """
    }
}

process ALLZIP {
    debug true
    stageInMode 'copy' 

    publishDir 'results', mode: 'copy'

    input:
    path hello

    output:
    path "${hello.baseName}.zip", emit: zip_file //multiple emission names to differentiate in view. 
    path "${hello.name}.gz", emit: gzip_file
    path "${hello.name}.bz2", emit: bzip2_file
    

    script:
    """
        zip "${hello.baseName}.zip" "$hello"
        gzip -k "$hello"
        bzip2 -k "$hello"
    """
}

process WRITETOFILE {
    debug true

    publishDir 'results', mode: 'copy'

    input:
    val text
    
    output:
    path 'names.tsv', emit: outfile

    script:
    """
        echo "$text" >> names.tsv
    """
}


workflow {

    // Task 1 - create a process that says Hello World! (add debug true to the process right after initializing to be sable to print the output to the console)
    if (params.step == 1) {
        SAYHELLO()
    }

    // Task 2 - create a process that says Hello World! using Python
    if (params.step == 2) {
        SAYHELLO_PYTHON()
    }

    // Task 3 - create a process that reads in the string "Hello world!" from a channel and write it to command line
    if (params.step == 3) {
        greeting_ch = channel.of("Hello world!")
        SAYHELLO_PARAM(greeting_ch)
    }

    // Task 4 - create a process that reads in the string "Hello world!" from a channel and write it to a file. WHERE CAN YOU FIND THE FILE?
    if (params.step == 4) {
        greeting_ch = channel.of("Hello world!")
        out_ch = SAYHELLO_FILE(greeting_ch)
        out_ch.view()
    }
    // Since i added a 'publishDir', inside the folder i specified (results), otherwise would be only found in work folder of nextflow.

    // Task 5 - create a process that reads in a string and converts it to uppercase and saves it to a file as output. View the path to the file in the console
    if (params.step == 5) {
        greeting_ch = channel.of("Hello world!")
        out_ch = UPPERCASE(greeting_ch)
        out_ch.view()
    }

    // Task 6 - add another process that reads in the resulting file from UPPERCASE and print the content to the console (debug true). WHAT CHANGED IN THE OUTPUT?
    if (params.step == 6) {
        greeting_ch = channel.of("Hello world!")
        out_ch = UPPERCASE(greeting_ch)
        PRINTUPPER(out_ch)
    }

    
    // Task 7 - based on the paramater "zip" (see at the head of the file), create a process that zips the file created in
    // the UPPERCASE process either in "zip", "gzip" OR "bzip2" format. Print out the path to the zipped file in the console
    if (params.step == 7) {
        greeting_ch = channel.of("Hello world!")
        out_ch = UPPERCASE(greeting_ch)
        ZIP(out_ch).view()
    } 

    // Task 8 - Create a process that zips the file created in the UPPERCASE process in "zip", "gzip" AND "bzip2" format. 
    // Print out the paths to the zipped files in the console

    if (params.step == 8) {
        greeting_ch = channel.of("Hello world!")
        out_ch = UPPERCASE(greeting_ch)
        ALLZIP(out_ch)

        //need to look at all three output files:
        ALLZIP.out.zip_file.view()
        ALLZIP.out.gzip_file.view()
        ALLZIP.out.bzip2_file.view()
    }

    // Task 9 - Create a process that reads in a list of names and titles from a channel and writes them to a file.
    //          Store the file in the "results" directory under the name "names.tsv"

    if (params.step == 9) {
        in_ch = channel.of(
            ['name': 'Harry', 'title': 'student'],
            ['name': 'Ron', 'title': 'student'],
            ['name': 'Hermione', 'title': 'student'],
            ['name': 'Albus', 'title': 'headmaster'],
            ['name': 'Snape', 'title': 'teacher'],
            ['name': 'Hagrid', 'title': 'groundkeeper'],
            ['name': 'Dobby', 'title': 'hero'],
        )

        in_ch
            .map {tuple -> "${tuple.name}\t${tuple.title}"}
            .collect()
            .map { rows -> rows.join('\n') }
            | WRITETOFILE
    }

}