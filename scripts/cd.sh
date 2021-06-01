#!/bin/bash


function verify_cd_parameters {
    echo "@Verifying cd parameters"

    # verify symphony yaml
    if [ -z "$symphony_yaml_file" ]; then
        export code="1"
        error "1" "Missing path to symphony.yml. Please provide a path to the file via -sc or --symphony-config"
        return $code
    fi

    if [ ! -f "$symphony_yaml_file" ]; then
        export code="1"
        error "1" "Invalid path, $symphony_yaml_file file not found. Please provide a valid path to the file via -sc or --symphony-config"
        return $code
    fi

    validate_symphony "$symphony_yaml_file"
}