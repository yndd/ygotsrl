#!/bin/bash
# The install script is based off of the Apache 2.0 script from Helm,
# https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
# https://raw.githubusercontent.com/srl-labs/containerlab/main/get.sh

# DEBUG section, fix versions
#: ${SRLINUX_VERSION:="v21.11.3"}
#: ${YGOT_VERSION:="v0.20.0"}

HAS_CURL="$(type "curl" &> /dev/null && echo true || echo false)"
HAS_WGET="$(type "wget" &> /dev/null && echo true || echo false)"

# checkLatestVersion checks if the latest version when none has been specified.
checkLatestVersion() {
  if [ "x$SRLINUX_VERSION" == "x" ]; then
    # Get tag from release URL
    local latest_release_url="https://api.github.com/repos/nokia/srlinux-yang-models/tags"
    if [ "${HAS_CURL}" == "true" ]; then
      SRLINUX_VERSION=$(curl -Ls $latest_release_url | grep '"name"' | head -1 | cut -d '"' -f 4)
    elif [ "${HAS_WGET}" == "true" ]; then
      SRLINUX_VERSION=$(wget $latest_release_url -O - 2>&1 | grep '"name"' | head -1 | cut -d '"' -f 4)
    fi
  fi
  if [ "x$YGOT_VERSION" == "x" ]; then
    # Get tag from release URL
    local latest_release_url="https://api.github.com/repos/openconfig/ygot/releases/latest"
    if [ "${HAS_CURL}" == "true" ]; then
      YGOT_VERSION=$(curl -Ls $latest_release_url | grep '"name"' | head -1 | cut -d '"' -f 4)
    elif [ "${HAS_WGET}" == "true" ]; then
      YGOT_VERSION=$(wget $latest_release_url -O - 2>&1 | grep '"name"' | head -1 | cut -d '"' -f 4)
    fi
  fi
}

# installDependencies installs ygot/generator version x.y.z
installDependencies() {
    go install github.com/openconfig/ygot/generator@$YGOT_VERSION
    go get github.com/openconfig/ygot@$YGOT_VERSION
}

# fetch the SRLinux YANG models for version x.y.z
fetchGitRepo() {
    git clone -b $SRLINUX_VERSION --single-branch https://github.com/nokia/srlinux-yang-models.git nokia > /dev/null 2>&1
}

cleanupGitRepo() {
    rm -f nokia/srlinux-yang-models/srl_nokia/models/*/*tools*.yang
}

# Fix Broken Yang1.1 statements
fixYang11() {
    sed -i 's/modifier \"invert-match\"/\/\/modifier \"invert-match\"/g' nokia/srlinux-yang-models/srl_nokia/models/common/srl_nokia-common.yang
    cat nokia/srlinux-yang-models/srl_nokia/models/common/srl_nokia-common.yang | grep modifier
}

# generate the go structs using ygot/generator, exclude tools
generate() {
    export YANG_FILES=`find nokia/srlinux-yang-models/srl_nokia \( -iname "*.yang" ! -name "*tools*" \)`
    
    generator -output_file=ygotsrl.go \
        -logtostderr \
        -path=nokia/srlinux-yang-models \
        -package_name=ygotsrl -generate_fakeroot -fakeroot_name=Device -compress_paths=false \
        -shorten_enum_leaf_names \
        -typedef_enum_with_defmod \
        -enum_suffix_for_simple_union_enums \
        -generate_rename \
        -generate_append \
        -generate_getters \
        -generate_delete \
        -generate_simple_unions \
        -generate_populate_defaults \
        -include_schema \
        -exclude_state \
        -yangpresence \
        -include_model_data \
        -generate_leaf_getters \
        $YANG_FILES
}

# cleanup the yang repository and build artefacts
cleanup() {
    rm -rf nokia/
}

# help provides possible cli installation arguments
help() {
    echo "Accepted cli arguments are:"
    echo -e "\t[--help|-h ] ->> prints this help"
    echo -e "\t[--ygot <desired_version>] . When not defined it fetches the latest release from GitHub"
    echo -e "\te.g. --ygot 0.20.0"
    echo -e "\t[--srlinux <desired_version>] . When not defined it fetches the latest release from GitHub"
    echo -e "\te.g. --srlinux 21.11.3"
}

# Parsing input arguments (if any)
export INPUT_ARGUMENTS="${@}"
set -u
while [[ $# -gt 0 ]]; do
    case $1 in
    '--ygot')
        shift
        if [[ $# -ne 0 ]]; then
            export YGOT_VERSION="v${1}"
        else
            echo -e "Please provide the desired ygot version. e.g. --ygot 0.20.0"
            exit 0
        fi
        ;;
    '--srlinux')
        shift
        if [[ $# -ne 0 ]]; then
            export SRLINUX_VERSION="v${1}"
        else
            echo -e "Please provide the desired SRLinux version. e.g. --version 21.11.1"
            exit 0
        fi
        ;;
    '--help' | -h)
        help
        exit 0
        ;;
    *)
        exit 1
        ;;
    esac
    shift
done
set +u

checkLatestVersion
installDependencies
fetchGitRepo
fixYang11
generate
cleanup
