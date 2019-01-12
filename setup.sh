#!/bin/bash

set -e

function getCurrentDir() {
    local current_dir="${BASH_SOURCE%/*}"
    if [[ ! -d "${current_dir}" ]]; then current_dir="$PWD"; fi
    echo "${current_dir}"
}

function includeDependencies() {
    # shellcheck source=./setupLibrary.sh
    source "${current_dir}/setupLibrary.sh"
}

current_dir=$(getCurrentDir)
includeDependencies
output_file="output.log"

function main() {

    echo "************************************"
    echo "* New user setup                   *"
    echo "************************************"
    printf "\n"
    read -rp $'Enter the username of the new user account:\n' username
    read -rp $'Paste in the public SSH key for the new user:\n' sshKey

    promptForPassword

    addUserAccount "${username}" "${password}" true

    clear

    echo "************************************"
    echo "* SSH hardening                    *"
    echo "************************************"
    printf "\n"
    read -rp $'Enter the port for the SSH server (Default is 22):\n' sshPort

    clear 

    # echo "************************************"
    # echo "* Default shell environment        *"
    # echo "************************************"
    # printf "\n"
    # zshPreztoAsShell

    echo 'Running setup script...'
    logTimestamp "${output_file}"

    exec 3>&1 >>"${output_file}" 2>&1

    echo "Updating packages... " >&3
    sudo apt-get -y update

    echo "Upgrading packages... " >&3
    sudo apt-get -y upgrade

    echo "Installing ZSH and Prezto ... " >&3
    installZshPrezto

    echo "Updating shell environment... " >&3
    updateSkel

    echo "Hardening SSH... " >&3
    disableSudoPassword "${username}"
    addSSHKey "${username}" "${sshKey}"
    changeSSHConfig "${username}" "${sshPort}"

    echo "Setting up UFW... " >&3
    setupUfw "${sshPort}"

    if ! hasSwap; then
        setupSwap
    fi

    setupTimezone

    echo "Installing Network Time Protocol... " >&3
    configureNTP

    sudo service ssh restart

    cleanup

    echo "Setup Done! Log file is located at ${output_file}" >&3
}

function setupSwap() {
    createSwap
    mountSwap
    tweakSwapSettings "10" "50"
    saveSwapSettings "10" "50"
}

function hasSwap() {
    [[ "$(sudo swapon -s)" == *"/swapfile"* ]]
}

function cleanup() {
    if [[ -f "/etc/sudoers.bak" ]]; then
        revertSudoers
    fi
}

function logTimestamp() {
    local filename=${1}
    {
        echo "===================" 
        echo "Log generated on $(date)"
        echo "==================="
    } >>"${filename}" 2>&1
}

function setupTimezone() {
    echo -ne "Enter the timezone for the server (Default is 'Europe/Paris'):\n" >&3
    read -r timezone
    if [ -z "${timezone}" ]; then
        timezone="Europe/Paris"
    fi
    setTimezone "${timezone}"
    echo "Timezone is set to $(cat /etc/timezone)" >&3
}

# Keep prompting for the password and password confirmation
function promptForPassword() {
   PASSWORDS_MATCH=0
   while [ "${PASSWORDS_MATCH}" -eq "0" ]; do
       read -s -rp "Enter new UNIX password:" password
       printf "\n"
       read -s -rp "Retype new UNIX password:" password_confirmation
       printf "\n"

       if [[ "${password}" != "${password_confirmation}" ]]; then
           echo "Passwords do not match! Please try again."
       else
           PASSWORDS_MATCH=1
       fi
   done 
}

function zshPreztoAsShell() {
    while true; do
        read -p "Do want to use ZSH and Prezto as default shell environment for all users?" yn
        case $yn in
            [Yy]* ) zshPrezto=true; break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done    
}

pre
main
