#!/bin/bash

warn="\e[1;31m"      # warning           red
info="\e[1;34m"      # info              blue
q="\e[1;32m"         # questions         green

filename="9u1ck.sh"  # filename
dirname="9u1ck"      # dirname

    echo -e "\e[1;37m                                                                

               █████╗ ██╗   ██╗ ██╗ ██████╗██╗  ██╗   ███████╗██╗  ██╗
              ██╔══██╗██║   ██║███║██╔════╝██║ ██╔╝   ██╔════╝██║  ██║
              ╚██████║██║   ██║╚██║██║     █████╔╝    ███████╗███████║
               ╚═══██║██║   ██║ ██║██║     ██╔═██╗    ╚════██║██╔══██║
               █████╔╝╚██████╔╝ ██║╚██████╗██║  ██╗██╗███████║██║  ██║
               ╚════╝  ╚═════╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═╝

    >$info Running Instalation
    "

### Run as ROOT
if [[ "$(id -u)" != "0" ]]; then
    echo -e "$warn\nThis script must be run as root" 1>&2
exit 0
fi

echo -e "$warn\nImportant: run this installer from the same directory as /$filename\n"
sleep 1

### Location Selector
echo -e "$q\nWhere are we installing $filename? e.g. /usr/bin"
read var
if [[ ! $var =~ ^/ ]];then  # if "/" is omitted eg "opt"
    var="/""$var"           # then add it
fi

### Create working dir
if [[ ! -d $var/$dirname/ ]];then
    mkdir $var/$dirname/
fi

### Copy .sh
chmod 744 $filename && cp -bi --preserve $filename $var/
if [[ -x $var/$filename ]];then
    echo -e "$info\n$filename installed to $var\n"
else
    echo -e "$warn\nFailed to install $filename!\n"
fi

### Install Dependencies
apt-get update

declare -a progs=(Eterm macchanger aircrack-ng ferret sslstrip nginx dsniff)
for i in ${progs[@]}; do
    echo -e "$info"
    if [[ ! -x /usr/bin/"$i" ]] && [[ ! -x /usr/sbin/"$i" ]] && [[ ! -x /usr/share/"$i" ]];then
	i="$(tr [A-Z] [a-z] <<< "$i")" 	# to deal with Eterm/eterm
	apt-get install "$i"
    else
	echo -e "$info\n$i already present"
    fi
done

if [[ ! -x /usr/sbin/dhcpd ]];then
    echo -e "$q\nInstall isc-dhcp-server? (y/n)"
    read var
    if [[ $var == y ]];then
        apt-get install isc-dhcp-server
    fi
else
    echo -e "$info\nIsc-dhcp-server already present"
fi

if [[ ! -x /usr/bin/wicd ]];then
    echo -e "$q\nInstall & configure wicd (network-manager alternative)? (y/n)"
    read var
    if [[ $var == y ]];then
        # install wicd
        apt-get install wicd
        # stop network-manager
        service network-manager stop
        # remove network-manager from startup
        update-rc.d network-manager disable
        # restart wicd
        service wicd restart
    fi
else
    echo -e "$info\nWicd already present"
fi

###

echo -e "$info\nFinished. \nIf there were no error messages, you can safely delete this files.

\nRun by typing \"$filename\" (presuming your installation directory is on the path)."

sleep 2
exit 0
