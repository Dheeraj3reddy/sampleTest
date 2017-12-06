#!/bin/bash

function semverParseInto() {
    local RE='[^0-9]*\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\)\([0-9A-Za-z-]*\)'
    #MAJOR
    eval $2=`echo $1 | sed -e "s#$RE#\1#"`
    #MINOR
    eval $3=`echo $1 | sed -e "s#$RE#\2#"`
    #MINOR
    eval $4=`echo $1 | sed -e "s#$RE#\3#"`
    #SPECIAL
    eval $5=`echo $1 | sed -e "s#$RE#\4#"`
}

function semverEQ() {
    local MAJOR_A=0
    local MINOR_A=0
    local PATCH_A=0
    local SPECIAL_A=0

    local MAJOR_B=0
    local MINOR_B=0
    local PATCH_B=0
    local SPECIAL_B=0

    semverParseInto $1 MAJOR_A MINOR_A PATCH_A SPECIAL_A
    semverParseInto $2 MAJOR_B MINOR_B PATCH_B SPECIAL_B

    if [ $MAJOR_A -ne $MAJOR_B ]; then
        return 1
    fi

    if [ $MINOR_A -ne $MINOR_B ]; then
        return 1
    fi

    if [ $PATCH_A -ne $PATCH_B ]; then
        return 1
    fi

    if [[ "_$SPECIAL_A" != "_$SPECIAL_B" ]]; then
        return 1
    fi


    return 0

}

function semverLT() {
    local MAJOR_A=0
    local MINOR_A=0
    local PATCH_A=0
    local SPECIAL_A=0

    local MAJOR_B=0
    local MINOR_B=0
    local PATCH_B=0
    local SPECIAL_B=0

    semverParseInto $1 MAJOR_A MINOR_A PATCH_A SPECIAL_A
    semverParseInto $2 MAJOR_B MINOR_B PATCH_B SPECIAL_B

    if [ $MAJOR_A -lt $MAJOR_B ]; then
        return 0
    fi

    if [[ $MAJOR_A -le $MAJOR_B  && $MINOR_A -lt $MINOR_B ]]; then
        return 0
    fi

    if [[ $MAJOR_A -le $MAJOR_B  && $MINOR_A -le $MINOR_B && $PATCH_A -lt $PATCH_B ]]; then
        return 0
    fi

    if [[ "_$SPECIAL_A"  == "_" ]] && [[ "_$SPECIAL_B"  == "_" ]] ; then
        return 1
    fi
    if [[ "_$SPECIAL_A"  == "_" ]] && [[ "_$SPECIAL_B"  != "_" ]] ; then
        return 1
    fi
    if [[ "_$SPECIAL_A"  != "_" ]] && [[ "_$SPECIAL_B"  == "_" ]] ; then
        return 0
    fi

    if [[ "_$SPECIAL_A" < "_$SPECIAL_B" ]]; then
        return 0
    fi

    return 1

}

function semverGT() {
    semverEQ $1 $2
    local EQ=$?

    semverLT $1 $2
    local LT=$?

    if [ $EQ -ne 0 ] && [ $LT -ne 0 ]; then
        return 0
    else
        return 1
    fi
}

function check_image_version() {
    required_base_name=$1
    required_min_ver=$2
    required_docker_file=$3
    match_special=$4

    if [ ! -f "$required_docker_file" ]; then
        echo "ERROR: Required Docker file $required_docker_file cannot be found!"
        return 1
    fi

    current_base_name=$([[ "`grep \"^FROM[[:blank:]]\" $required_docker_file`" =~ FROM[[:blank:]](.+): ]] && echo ${BASH_REMATCH[1]})
    current_base_ver=$([[ "`grep \"^FROM[[:blank:]]\" $required_docker_file`" =~ FROM[[:blank:]].+:(.+)$ ]] && echo ${BASH_REMATCH[1]})

    if [[ ! $current_base_name =~ $required_base_name ]]; then
        echo "ERROR: Wrong base image is used in $required_docker_file. Expected: $required_base_name"
        return 1
    fi

    if semverGT $required_min_ver $current_base_ver; then
        echo "ERROR: Base image version ($current_base_ver) in $required_docker_file is less than the required minimum version $required_min_ver. Please upgrade."
        return 1
    fi

    semverParseInto $current_base_ver major minor patch special
    if [ "_$match_special" != "_$special" ]; then
        echo "ERROR: Base image special version in $required_docker_file does not match the required special version \"$match_special\""
        return 1
    fi

    return 0
}

BUILDER_BASE_NAME="docker-asr-release.dr.corp.adobe.com/asr/(static_builder_base|static_builder_node_v7|static_builder_node_v8)$"
BUILDER_MIN_VER=1.1.0
BUILDER_DOCKER_FILE=Dockerfile.build.mt

DEPLOYER_BASE_NAME=docker-asr-release.dr.corp.adobe.com/asr/static_deployer_base
DEPLOYER_MIN_VER=1.1.0-alpine
DEPLOYER_SPECIAL_VER="-alpine"
DEPLOYER_DOCKER_FILE=Dockerfile

if ! check_image_version $BUILDER_BASE_NAME $BUILDER_MIN_VER $BUILDER_DOCKER_FILE ''; then
    exit 1
fi

if ! check_image_version $DEPLOYER_BASE_NAME $DEPLOYER_MIN_VER $DEPLOYER_DOCKER_FILE $DEPLOYER_SPECIAL_VER; then
    exit 1
fi

echo "Check passed"