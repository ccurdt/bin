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
    	sudo apt update > pipass-install-stdout.log 2> pipass-install-err.log;
	    sudo apt -y upgrade > pipass-install-stdout.log 2> pipass-install-err.log;
    else
    	printf "We don't know what your PKGMAN is.";
    fi
}

dependencies_install() {
    # git
    if command_exists git; then
        printf "\\n${SYM_CHECK} git is installed.\\n"
    else
        printf "\\n${SYM_X} git is not installed.\\n"
            if [ "$PKGMAN" = "apt" ]; then
	            sudo apt install -y git > pipass-install-stdout.log 2> pipass-install-err.log;
            elif [ "$PKGMAN" = "dnf" ]; then
                sudo dnf install -y git > pipass-install-stdout.log 2> pipass-install-err.log;
            fi
    fi

    # php
    if command_exists php; then
        printf "${SYM_CHECK} php is installed.\\n"
    else
        printf "${SYM_X} php is not installed.\\n"
            if [ "$PKGMAN" = "apt" ]; then
	            sudo apt install -y php php-curl > pipass-install-stdout.log 2> pipass-install-err.log;
            elif [ "$PKGMAN" = "dnf" ]; then
                sudo dnf install -y php php-curl > pipass-install-stdout.log 2> pipass-install-err.log;
            fi
    fi

    # php7.3/4-curl
    if [ "$PKGMAN" = "apt" ]; then
        if dpkg --get-selections | egrep "php7.3-curl|php-7.4-curl" > pipass-install-stdout.log 2> pipass-install-err.log; then
            printf "${SYM_CHECK} php-curl is installed.\\n"
        else
            printf "${SYM_X} php-curl is not installed.\\n"
            sudo apt install -y php-curl > pipass-install-stdout.log 2> pipass-install-err.log;
        fi

    elif [ "$PKGMAN" = "dnf" ]; then
        if dnf list installed | egrep "php7.3-curl|php-7.4-curl" > pipass-install-stdout.log 2> pipass-install-err.log; then
            printf "${SYM_CHECK} php-curl is installed.\\n"
        else
            printf "${SYM_X} php-curl is not installed.\\n"
            sudo dnf install -y php-curl > pipass-install-stdout.log 2> pipass-install-err.log;
        fi
    fi
}

if [[ $EUID -ne 0 ]]; then
   printf "${SYM_X} ${CL_RED}FATAL:${CL_BLANK} The installer must be run with root permissions\\n" 
   exit 1
fi

while true; do
    read -p "To ensure compatibility, the system should be updated. Is this ok? [Y/n] " yn
    case $yn in
        [Yy]* ) update_system; break;;
        [Nn]* ) break;;
        * ) update_system; break;;
    esac
done

while true; do
    read -p "The installer will now check for and automatically install necessary dependencies. Is this ok? [Y/n] " yn
    case $yn in
        [Yy]* ) dependencies_install; break;;
        [Nn]* ) break;;
        * ) update_system; break;;
    esac
done

