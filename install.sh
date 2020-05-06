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

# Stop wildcard expansion for sudoers

set -f

# Global variables

PKGMAN=apt
WEBROOT=/var/www/html/
PHPUSER=www-data
BLOCKPAGE_REPO_URL=https://github.com/pipass/blockpage.git
SUDOERSLINE="${PHPUSER} ALL=(ALL) NOPASSWD: /usr/local/bin/pihole -w *, /usr/local/bin/pihole -w -d *"

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
    elif [ "$PKGMAN" = "dnf" ]; then
        sudo dnf -y update > pipass-install-stdout.log 2> pipass-install-err.log;
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

    # curl
    if command_exists curl; then
        printf "${SYM_CHECK} curl is installed.\\n"
    else
        printf "${SYM_X} curl is not installed.\\n"
            if [ "$PKGMAN" = "apt" ]; then
	            sudo apt install -y curl > pipass-install-stdout.log 2> pipass-install-err.log;
            elif [ "$PKGMAN" = "dnf" ]; then
                sudo dnf install -y curl > pipass-install-stdout.log 2> pipass-install-err.log;
            fi
    fi
}

install_to_webroot() {
    if [[ $(ls $WEBROOT | grep index) ]]; then
        printf "${SYM_X} ${CL_RED}FATAL:${CL_BLANK} Index files have been detected in webroot directory $WEBROOT. To prevent data loss, the installer has exited. Please manually remove those files and re-run the installer.\\n"
        exit 1;
    else
        printf "${SYM_INFO} Downloading PiPass files to your system.\\n"
        cd $WEBROOT
        sudo git init
        sudo git remote add -t \* -f origin $BLOCKPAGE_REPO_URL
        sudo git pull origin master
        printf "${SYM_CHECK} PiPass has been cloned to your webroot directory.\\n"
        move_to_latest_tag;
    fi
}

move_to_latest_tag() {
    VERSION=$(curl https://raw.githubusercontent.com/PiPass/bin/master/currentversion)
    printf "${SYM_INFO} Checking out latest stable version $VERSION.\\n"
    cd $WEBROOT
    sudo git checkout tags/v$VERSION
    printf "${SYM_CHECK} Latest stable version $VERSION checked out.\\n"
}

if [[ $EUID -ne 0 ]]; then
   printf "${SYM_X} ${CL_RED}FATAL:${CL_BLANK} The installer must be run with root permissions\\n"
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
    read -p "The installer will now check for and install dependencies. Is this ok? [Y/n] " yn
    case $yn in
        [Yy]* ) dependencies_install; break;;
        [Nn]* ) break;;
        * ) update_system; break;;
    esac
done

if [ -d "$WEBROOT" ]; then
    printf "\\n"
    read -p "We think that your webroot is $WEBROOT and will install there. Is this ok? [Y/n] " yn
    while true; do
        case $yn in
            [Yy]* ) install_to_webroot; break;;
            [Nn]* ) exit;;
            * ) install_to_webroot; break;;
        esac
    done
else
    printf "${SYM_INFO} ${CL_YELLOW}WARN:${CL_BLANK} We couldn't reliabliy determine your webroot. Please manually modify the \"WEBROOT\" variable in the script and re-run. Sometimes, this can happen if there is no webserver installed. The installer will exit now.\\n"
    exit;
fi

if [[ $(ps aux | grep -v 'grep' | grep ${PHPUSER}) ]]; then
  printf "${SYM_INFO} We think that the php user is ${PHPUSER}, but this is just a guess. Please update the PHPUSER variable in this file if this is wrong.\\n"
else
  # We don't know who PHP is running as. Taking a wild guess, it's probably the current user.
  PHPUSER=$(php -r 'echo exec("whoami");')
  printf "${SYM_INFO} We think that the php user is ${PHPUSER}, but this is just a guess. Please update the PHPUSER variable in this file if this is wrong, and modify the sudoers file accordingly.\\n"
fi

if [ -z "$(sudo cat /etc/sudoers | grep /usr/local/bin/pihole)" ]; then
  echo ${SUDOERSLINE} | sudo tee -a /etc/sudoers
  printf "${SYM_CHECK} sudoers line added successfully.\\n"
else
  printf "${SYM_INFO} sudoers line already exists. No need to add again.\\n"
fi

# Lighttpd 404 configuration
if [ -f /etc/lighttpd/lighttpd.conf ]; then
  sudo cp /etc/lighttpd/lighttpd.conf /etc/lighttpd/lighttpd.conf.pipass.bak
  printf "${SYM_INFO} Backed up lighttpd configuration to lighttpd.conf.pipass.bak.\\n"
  sudo sed -i /etc/lighttpd/lighttpd.conf -re 's/(server.error-handler-404[^"]*")([^"]*)(")/\1index\.php\3/'

  printf "${SYM_CHECK} Successfully modified lighttpd configuration for 404 redirects.\\n"
else
  printf "${SYM_INFO} lighttpd installation not found. Please configure 404 redirects for your webserver manually.\\n"
  ERR=true
fi

# Pi-Hole BLOCKINGMODE configuration
if [ -f /etc/pihole/pihole-FTL.conf ]; then
  sudo cp /etc/pihole/pihole-FTL.conf /etc/pihole/pihole-FTL.conf.pipass.bak
  printf "${SYM_INFO} Backed up Pi-Hole configuration to pihole-FTL.conf.pipass.bak.\\n"

  sudo sed -i '/^BLOCKINGMODE=/{h;s/=.*/=IP/};${x;/^$/{s//BLOCKINGMODE=IP/;H};x}' /etc/pihole/pihole-FTL.conf
else
  printf "${SYM_X} Unable to detect Pi-Hole configuration file. Are you sure Pi-Hole is installed?\\n"
  ERR=true
fi

if [ -z ${ERR} ]; then
  printf "${SYM_CHECK}${CL_GREEN} PiPass installation completed without significant errors.\\n"
else
  printf "${SYM_CHECK}${CL_YELLOW} PiPass installation completed with warnings. See the log above for more info and make a new post on the forum if you need help.\\n"
fi
