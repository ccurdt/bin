#!/bin/bash
# PiPass installer for v>=1.3.5

CL_BLANK='\e[0m'
CL_GREEN='\e[1;32m'
CL_RED='\e[1;31m'
CL_YELLOW='\e[1;93m'
SYM_CHECK="[${CL_GREEN}✓${CL_BLANK}]"
SYM_X="[${CL_RED}✗${CL_BLANK}]"
SYM_QUESTION="[${CL_YELLOW}?${CL_BLANK}]"
SYM_INFO="[i]"

# Global variables

PKGMAN=apt
WEBROOT=/var/www/html/pihole/
BLOCKPAGE_REPO_URL=https://github.com/ccurdt/blockpage.git

# Function declarations

command_exists() {
    local check_command="$1"
    command -v "${check_command}" >/dev/null 2>&1
}

update_system() {
    get_package_manager() {
        if command_exists apt; then
            PKGMAN=apt
        elif command_exists dnf; then
            PKGMAN=dnf
        else
            printf "${SYM_INFO} ${CL_YELLOW}WARN:${CL_BLANK} We couldn't reliabliy determine your package manager. The installer will not attempt to install dependencies.\\n"
        fi
    }

    get_package_manager
    if [ "$PKGMAN" = "apt" ]; then
    	sudo apt update > pipass-update-stdout.log 2> pipass-update-err.log;
	    sudo apt -y upgrade > pipass-update-stdout.log 2> pipass-update-err.log;
    elif [ "$PKGMAN" = "dnf" ]; then
        sudo dnf -y update > pipass-update-stdout.log 2> pipass-update-err.log;
    fi
}

dependencies_install() {
    # git
    if command_exists git; then
        printf "\\n${SYM_CHECK} git is installed.\\n"
    else
        printf "\\n${SYM_X} git is not installed.\\n"
            if [ "$PKGMAN" = "apt" ]; then
	            sudo apt install -y git > pipass-update-stdout.log 2> pipass-update-err.log;
            elif [ "$PKGMAN" = "dnf" ]; then
                sudo dnf install -y git > pipass-update-stdout.log 2> pipass-update-err.log;
            fi
    fi

    # php
    if command_exists php; then
        printf "${SYM_CHECK} php is installed.\\n"
    else
        printf "${SYM_X} php is not installed.\\n"
            if [ "$PKGMAN" = "apt" ]; then
	            sudo apt install -y php php-curl > pipass-update-stdout.log 2> pipass-update-err.log;
            elif [ "$PKGMAN" = "dnf" ]; then
                sudo dnf install -y php php-curl > pipass-update-stdout.log 2> pipass-update-err.log;
            fi
    fi

    # php7.3/4-curl
    if [ "$PKGMAN" = "apt" ]; then
	    if (apt list --installed | grep php-curl) > pipass-update-stdout.log 2> pipass-update-err.log; then
            printf "${SYM_CHECK} php-curl is installed.\\n"
        else
            printf "${SYM_X} php-curl is not installed.\\n"
            sudo apt install -y php-curl > pipass-update-stdout.log 2> pipass-update-err.log;
        fi

    elif [ "$PKGMAN" = "dnf" ]; then
        if dnf list installed | egrep "php7.3-curl|php-7.4-curl" > pipass-update-stdout.log 2> pipass-update-err.log; then
            printf "${SYM_CHECK} php-curl is installed.\\n"
        else
            printf "${SYM_X} php-curl is not installed.\\n"
            sudo dnf install -y php-curl > pipass-update-stdout.log 2> pipass-update-err.log;
        fi
    fi

    # curl
    if command_exists curl; then
        printf "${SYM_CHECK} curl is installed.\\n"
    else
        printf "${SYM_X} curl is not installed.\\n"
            if [ "$PKGMAN" = "apt" ]; then
	            sudo apt install -y curl > pipass-update-stdout.log 2> pipass-update-err.log;
            elif [ "$PKGMAN" = "dnf" ]; then
                sudo dnf install -y curl > pipass-update-stdout.log 2> pipass-update-err.log;
            fi
    fi
}

update_pipass() {
    cd $WEBROOT

    # Copy config file
    printf "${SYM_INFO} Making a copy of your current configuration file in case anything goes wrong.\\n"
    sudo cp config.php config.update-backup.php

    # Remove old origin and add new
    printf "${SYM_INFO} Re-adding git upstream since its URL was moved.\\n"
    sudo git remote remove origin
    printf "${SYM_CHECK} Removed old repository from system.\\n"

    sudo git remote add origin $BLOCKPAGE_REPO_URL
    printf "${SYM_CHECK} Added new repository to system.\\n"

    sudo git reset --hard
    printf "${SYM_CHECK} Forcibly removed local changes to source code and updated to current version tagged upstream copy.\\n"

    VERSION=$(curl https://raw.githubusercontent.com/ccurdt/bin/master/currentversion)
    printf "${SYM_INFO} The latest stable version is $VERSION.\\n"
    
    printf "${SYM_INFO} Downloading lastest source code from upstream.\\n"
    sudo git pull origin master
    printf "${SYM_CHECK} Downloaded complete.\\n"

    sudo git checkout tags/v$VERSION
    printf "${SYM_CHECK} Checked out latest stable version.\\n"
    printf "${SYM_CHECK} Nice! Your PiPass installation is now on v$VERSION.\\n"
}

if [[ $EUID -ne 0 ]]; then
   printf "${SYM_X} ${CL_RED}FATAL:${CL_BLANK} The updater must be run with root permissions\\n"
   exit 1;
fi

while true; do
    printf "\\n"
    read -p "To ensure compatibility, the system should be updated. Is this ok? [Y/n] " yn
    case $yn in
        [Yy]* ) update_system; break;;
        [Nn]* ) break;;
        * ) update_system; break;;
    esac
done

while true; do
    printf "\\n"
    read -p "The updater will now check for and install dependencies. Is this ok? [Y/n] " yn
    case $yn in
        [Yy]* ) dependencies_install; break;;
        [Nn]* ) break;;
        * ) update_system; break;;
    esac
done

if [ -d "$WEBROOT" ]; then
    printf "\\n"
    read -p "Changes to ALL PIPASS FILES will be overwritten (except local config file, PiPass.ini) with the update. Really continue? [Y/n] " yn
    while true; do
        case $yn in
            [Yy]* ) update_pipass; break;;
            [Nn]* ) exit;;
            * ) update_pipass; break;;
        esac
    done
else
    printf "${SYM_INFO} ${CL_YELLOW}WARN:${CL_BLANK} We couldn't reliabliy determine your webroot. Please manually modify the \"WEBROOT\" variable in the script and re-run. Sometimes, this can happen if there is no webserver installed. The updater will exit now.\\n"
    exit;
fi
