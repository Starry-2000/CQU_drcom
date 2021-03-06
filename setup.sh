#!/usr/bin/sh
CONFIG=drcom.conf
CONFIG_PATH=/etc
DRCOM_ORIGIN=latest-wired.py
DRCOM=drcom
DRCOM_PATH=/usr/bin
VERSION_CQU_DRCOM='2.2.4.2a'
# for cli options
# "-" option is to rewrite long options which getopts do not support.
# ":" behind "-" is to undertake option string value of "-"
# like "--debug" option, "-" is a short option undertaking "-debug",
# and "debug" is the actual option handle by getopts
optspec="-:Vcvh"
# - for long flag option
# V for verbose option
# c for config changes option
# h for help option
# v for version option

if [ ! -f "/etc/os-release" ];then
	echo "Recheck your package. You cannot run this script."
	sleep 1
	exit;
fi

# import system information
source /etc/os-release;
distro=`echo $NAME | tr 'A-Z' 'a-z'` # By purefkh, to set all capital letters to lower case

# rewrite echo func By @Hagb
echo() { printf '%s\n' "$*" ; }

# hello mates
hello() {
    echo "======================================"
    echo "Welcome to CQU_drcom setup script."
    echo "======================================"
}

# config network
network_config() {
    read -p "Manually config the network? [y/N]: " ifSet_wan
    case $ifSet_wan in
    n|N|"")
        ;;
    y|Y)
        read -p "IP (Default to 192.168.1.1): " ifSet_wan_ip
        read -p "DNS (Default to 8.8.8.8 8.8.4.4; use SPACE to specific mutiple DNS): " ifSet_wan_dns
        read -p "GATEWAY (Default to 192.168.1.0): " ifSet_wan_gateway
        read -p "NETMASK (Default to 255.255.255.0): " ifSet_wan_netmask

        uci del network.wan.proto
        uci set network.wan.proto='static'
        uci set network.wan.ipaddr=$ifSet_wan_ip$([ -z "$ifSet_wan_ip" ] && echo 192.168.1.1)
        uci set network.wan.netmask=$ifSet_wan_netmask$([ -z "$ifSet_wan_netmask" ] && echo 255.255.255.0)
        uci set network.wan.gateway=$ifSet_wan_gateway$([ -z "$ifSet_wan_gateway" ] && echo 192.168.1.0)
        uci set network.wan.dns="$ifSet_wan_dns$([ -z "$ifSet_wan_dns" ] && echo 8.8.8.8 8.8.4.4)"
        echo "Commit changes..."
        uci commit
        echo "Restarting network service..."
        /etc/init.d/network restart
        ;;
    esac
}

# remove old file
clean_up() {
    if [ -f "$CONFIG_PATH/$CONFIG" ];then
        mv $CONFIG_PATH/$CONFIG $CONFIG_PATH/$CONFIG.save
    fi
    if [ -f "$DRCOM_PATH/$DRCOM" ];then
        rm $DRCOM_PATH/$DRCOM $DRCOM_PATH/$DRCOM.save
    fi
}

# change root passwd
root_pwd_change() {
    read -p "Change your root password? (For security it will show nothing when you enter.) [Y/n]:" rootpasswd
    case $rootpasswd in
    Y|y|"")
        passwd root;;
    N|n)
        # shellcheck disable=SC2104
        pass;;
    esac
    clear
}

#Gether information
inform_gather() {

    echo "[1] A"
    echo "[2] B"
    echo "[3] D"
    echo ""

    read -p "Please enter your campus: " CHOICE
    case $CHOICE in
    1)
        echo ""
        echo "You choose campus A"
        campus=a;;
    2)
        echo ""
        echo "You choose campus B"
        campus=b;;
    3)
        echo ""
        echo "You choose campus D"
        campus=d;;
    *)
        echo ""
        echo "Errors! Please run the program again."
        exit 0;;
    esac
    clear

    # change username and passwd
    read -p "Please enter your Student number: " username
    read -p "Please enter your password: " password

    # Crontab setting confirm
    echo "The cron is a schedule for script to run. It's like:"
    echo "*/1 * * * * sh /usr/bin/networkChecking.sh && sleep 30 && sh /usr/bin/networkChecking.sh"
    echo "* */8 * * * echo $NULL > ~/networkChecking.log"
    echo ""
    echo "which means the networkChecking script will run every 30 seconds and "
    echo "every 8 hour it will clean logs of drcom."
    echo ""
    read -p "Set up cron? [Y/n]: " ifSet
    case $ifSet in
    Y|y|"")
        ifSet_cron=Yes;;
    N|n)
        ifSet_cron=no;;
    esac
}

wlan_ssid_settings() {
    # Change WIFI ssid
    read -p "Change wifi ssid ? [Y/n]: " ifset_ssid
    case $ifset_ssid in
    Y|y|"")
        read -p "Use different name? [y/N]: " ifset_ssid_diff
        case $ifset_ssid_diff in
        Y|y)
            read -p "Enter 5Ghz wifi SSID: " wifi_ssid0
            read -p "Enter 2.4Ghz wifi SSID: " wifi_ssid1
            ;;
        N|n|"")
            read -p "Enter wifi SSID: " wifi_ssid1
            wifi_ssid0="${wifi_ssid1}_5G"
            ;;
        esac
        ;;
    N|n)
        echo "SSID will be " $distro
        wifi_ssid0=$distro\_5G
        wifi_ssid1=$distro
        ;;
    esac
}

wlan_passwd_setting() {
    # Wifi password
    read -p "Change your WIFI password ? [Y/n]: " ifChange
    case $ifChange in
    Y|y|"")
        read -p "Use different password? [y/N]: " ifset_passwd_diff
        case $ifset_passwd_diff in
        Y|y)
            echo "Enter password for " "$wifi_ssid0"
            read -p ">" wifi_password0
            echo "Enter password for " "$wifi_ssid1"
            read -p ">" wifi_password1
            ;;
        N|n|"")
            read -p "Please enter your new WIFI password: " wifi_password0
            wifi_password1="$wifi_password0"
            ;;
        esac
        ;;
    N|n)
        echo "Wifi password will leave empty."
        ;;
    esac
}


# Information recheck
recheck() {
    clear
    echo "Your campus:"
    echo $campus
    echo "Your Student number:"
    echo $username
    echo "Your password:"
    echo $password
    echo "SSID for 5Ghz:"
    echo "$wifi_ssid0"
    echo "SSID for 2.4Ghz:"
    echo "$wifi_ssid1"
    echo "Change WIFI password:"
    echo $ifChange

    case $ifChange in
    Y|y|"")
        echo "WIFI password for 5Ghz:"
        echo "$wifi_password0"
        echo "WIFI password for 2.4Ghz"
        echo "$wifi_password1" ;;
    N|n|*)
        # shellcheck disable=SC2104
        pass;;
    esac

    echo "Crontab:"
    echo $ifSet_cron
    echo ""
}

# give chances to reenter information
config_choice_changes() {
		while [ $confirm == "no" ]
		do
				clear
				echo ""
				echo "Choose the section to resetup from:"
				echo "[1] campus"
				echo "[2] student number"
				echo "[3] password"
				echo "[4] wifi SSID"
				echo "[5] wifi password"
				echo "[6] crontab"
				echo "Or press any other key to back to information recheck ..."
				read -p  "Please input only the number of the section: " toChange
				case $toChange in
				1)
						read -p "Please enter your campus(a/b/d): " campus
						;;
				2)
						read -p "Please enter your Student number: " username
						;;
				3)
						read -p "Please enter your password: " password
						;;
				4)
						wlan_ssid_settings
						;;
				5)
						wlan_passwd_setting
						;;
				6)
						read -p "Set up cron? [Y/n]" ifSet
						case $ifSet in
						Y|y|"")
								ifSet_cron=Yes;;
						N|n)
								ifSet_cron=no;;
						esac
						;;
				*)
						confirm=yes
						;;
				esac
		done
}

setup_confirm() {
		while :
		do
				recheck
				read -p "Is the above information right? [Y/n]: " solution
				case $solution in
				Y|y|"")
						echo "Good!"
						read -n1 -p "Press any key to continue installation... "
						echo ""
						clear
						break
						;;
				N|n)
						confirm=no
						config_choice_changes
						;;
				*)
						echo "invalid input!"
						;;
				esac
		done

}


setup_packages() {
    # setup python2
    echo "Setting up python2..."
    echo "Changing repositories..."
    echo "Old opkg sources file will be installed as /etc/opkg/distfeeds.conf.save"
    cp /etc/opkg/distfeeds.conf /etc/opkg/distfeeds.conf.save
    sed -i 's/downloads.openwrt.org/mirrors.cqu.edu.cn\/openwrt/g' /etc/opkg/distfeeds.conf
    ping -c 1 mirrors.cqu.edu.cn
    if [ $? -eq 0 ]
    then
        echo "Network is connected..."
    else
        echo "Failed... Please check your network connection."
        exit 0
    fi
    opkg update
    echo ""
    echo "Installing python..."
    opkg install python


    #set up base64
    echo "Setting up coreutils-base64..."
    opkg install coreutils-base64
}

setup_drcom() {
    #setup drcom
    echo "Setting up Dr.com..."
    case $campus in
    "a")
        echo "c2VydmVyID0gJzIwMi4yMDIuMC4xODAnCnVzZXJuYW1lPScnCnBhc3N3b3JkPScnCkNPTlRST0xDSEVDS1NUQVRVUyA9ICdceDIwJwpBREFQVEVSTlVNID0gJ1x4MDUnCmhvc3RfaXAgPSAnMTcyLjI0LjE1Mi44MScKSVBET0cgPSAnXHgwMScKaG9zdF9uYW1lID0gJ0dJTElHSUxJRVlFJwpQUklNQVJZX0ROUyA9ICcyMDIuMjAyLjAuMzMnCmRoY3Bfc2VydmVyID0gJzIwMi4yMDIuMi41MCcKQVVUSF9WRVJTSU9OID0gJ1x4MmZceDAwJwptYWMgPSAweDJjNjAwY2U4YzNjYgpob3N0X29zID0gJ05PVEU3JwpLRUVQX0FMSVZFX1ZFUlNJT04gPSAnXHhkY1x4MDInCnJvcl92ZXJzaW9uID0gRmFsc2UK" | base64 -d > $CONFIG
        ;;
    "b")
        echo "c2VydmVyID0gJzIwMi4yMDIuMC4xNjMnCnVzZXJuYW1lPScnCnBhc3N3b3JkPScnCkNPTlRST0xDSEVDS1NUQVRVUyA9ICdceDIwJwpBREFQVEVSTlVNID0gJ1x4MDYnCmhvc3RfaXAgPSAnMTcyLjI1LjE1NC45NCcKSVBET0cgPSAnXHgwMScKaG9zdF9uYW1lID0gJ0dJTElHSUxJRVlFJwpQUklNQVJZX0ROUyA9ICc4LjguOC44JwpkaGNwX3NlcnZlciA9ICcxMC4xMC43LjY2JwpBVVRIX1ZFUlNJT04gPSAnXHgyNVx4MDAnCm1hYyA9IDB4MTA3ZDFhMWYwNzliCmhvc3Rfb3MgPSAnTk9URTIwJwpLRUVQX0FMSVZFX1ZFUlNJT04gPSAnXHhkOFx4MDInCnJvcl92ZXJzaW9uID0gRmFsc2UK" |base64 -d > $CONFIG
        ;;
    "d")
        echo "c2VydmVyID0gIjEwLjI1NC43LjQiCnVzZXJuYW1lPScnCnBhc3N3b3JkPScnCmhvc3RfbmFtZSA9ICJHSUxJR0lMSUVZRSIKaG9zdF9vcyA9ICJOT1RFNyIKaG9zdF9pcCA9ICIxMC4yMzAuNTkuMjUxIgpQUklNQVJZX0ROUyA9ICIyMDIuMjAyLjAuMzMiCmRoY3Bfc2VydmVyID0gIjEwLjIzMC41OS4yIgptYWMgPSAweGI4ODhlMzA1MTY4MApDT05UUk9MQ0hFQ0tTVEFUVVMgPSAnXHgwMCcKQURBUFRFUk5VTSA9ICdceDAwJwpLRUVQX0FMSVZFX1ZFUlNJT04gPSAnXHhkY1x4MDInCicnJwpBVVRIX1ZFUlNJT046CiAgICB1bnNpZ25lZCBjaGFyIENsaWVudFZlckluZm9BbmRJbnRlcm5ldE1vZGU7CiAgICB1bnNpZ25lZCBjaGFyIERvZ1ZlcnNpb247CicnJwpBVVRIX1ZFUlNJT04gPSAnXHgyZlx4MDAnCklQRE9HID0gJ1x4MDEnCnJvcl92ZXJzaW9uID0gRmFsc2UKCg==" | base64 -d > $CONFIG
        ;;
    esac
    cp $DRCOM_ORIGIN $DRCOM #to avoid drcom not found
    sed -i "s/username=''/username=\'$username\'/g" $CONFIG
    sed -i "s/password=''/password=\'$(echo "$password" | sed 's/\\/\\\\\\\\/g;s/[&/]/\\&/g;s/'\''/\\\\'\'/g)\'/g" $CONFIG

    #set up startup service
    echo "Setting up startup service..."
    case $distro in
    "pandorabox")
        echo '#!/bin/sh
        # /etc/hotplug.d/iface/99-drcom
        if [ "$ACTION" = ifup ]; then
            if [ "${INTERFACE}" = "wan" ]; then
                sleep 10 && python /usr/bin/drcom > ~/drcom.log &
            fi
        fi' > 99-drcom
        chmod a+x 99-drcom
        cp -p 99-drcom /etc/hotplug.d/iface/ ;;

    "openwrt")
        echo '#!/bin/sh /etc/rc.common
        START=99
        start() {
            echo "[RUNNING] Starting drcom service..."
            (/usr/bin/drcom > /dev/null &)&
            sleep 1
            echo "[DONE] Start drcom service succesfully."
        }
        stop() {
            echo "[RUNNING] Stopping drcom..."
            kill -9 $(pidof python /usr/bin/drcom)
            sleep 1
            echo "[DONE] Drcom has been stopped."
        }
        restart() {
            echo "[RUNNING] Stopping drcom ... "
            kill -9 $(pidof python /usr/bin/drcom);
            sleep 1
            echo "[RUNNING] Restarting drcom ... "
            (/usr/bin/drcom > /dev/null &)&
            sleep 2
            echo "[DONE] Drcom restart succesfully."
        }' > drcomctl
        chmod a+x drcomctl
        mv drcomctl /etc/init.d/.
        /etc/init.d/drcomctl enable
        ;;
    esac

    echo "installing drcom to /usr/bin/drcom"
    echo "installing drcom.conf to /etc/drcom.conf"
    cp -p drcom /usr/bin/ && chmod a+x /usr/bin/drcom
    cp -p $CONFIG /etc/
    sleep 1s

    #setup networkChecking
    echo "IyEgL3Vzci9iaW4vc2gKIyAvdXNyL2Jpbi9uZXR3b3JrQ2hlY2tpbmcuc2gKCmxvZz1+L25ldHdvcmtDaGVja2luZy5sb2cKaWYgWyAhIC1mICR7bG9nfSBdCnRoZW4KICAgIHRvdWNoICR7bG9nfQpmaQoKZHJfbG9nPX4vZHJjb20ubG9nCmlmIFsgISAtZiAke2RyX2xvZ30gXQp0aGVuCiAgICB0b3VjaCAke2RyX2xvZ30KZmkKCnBpbmcgLWMgMSBiYWlkdS5jb20gPiAvZGV2L251bGwgMj4mMQppZiBbICQ/IC1lcSAwIF0KdGhlbgogICAgZWNobyBgZGF0ZWAgICIuLi4uLi5PSy4uLi4uLiIgPiAke2xvZ30KICAgIGVjaG8gJE5VTEwgPiAke2RyX2xvZ30KZWxzZQogICAgZWNobyBgZGF0ZWAgIi4uLi4uLkZhaWxlZC4uLi4uLiIgPiAke2xvZ30KICAgIHBzIHwgZ3JlcCAidGltZW91dCwgcmV0cnlpbmciICR7ZHJfbG9nfSB8IGdyZXAgLXYgZ3JlcAogICAgaWYgWyAkPyAtZXEgMCBdCiAgICB0aGVuCiAgICAgICAgZWNobyAkTlVMTCA+ICR7ZHJfbG9nfQogICAgICAgIGVjaG8gYGRhdGVgICIuLi4uLi50aW1lb3V0Li4uLi4uIiA+PiAke2xvZ30KICAgICAgICByZWJvb3QKICAgIGZpCiAgICBwcyB8IGdyZXAgZHJjb20gfCBncmVwIC12IGdyZXAKICAgIGlmIFsgJD8gLW5lIDAgXQogICAgdGhlbgogICAgICAgIGVjaG8gIi4uLi4uLnN0YXJ0IGRyY29tLi4uLi4uIiA+PiAke2xvZ30KICAgIGVsc2UKICAgICAgICBlY2hvICIuLi4uLi5kcmNvbSBpcyBydW5uaW5nLCBraWxsLi4uLi4uIiA+PiAke2xvZ30KICAgICAgICBlY2hvICIuLi4uLi5zdGFydCBkcmNvbS4uLi4uLiIgPj4gJHtsb2d9CiAgICAgICAga2lsbCAtOSAkKHBpZG9mIHB5dGhvbiAvdXNyL2Jpbi9kcmNvbSkKICAgIGZpCiAgICBweXRob24gL3Vzci9iaW4vZHJjb20gPiAke2RyX2xvZ30gJgpmaQoK" | base64 -d > networkChecking.sh
    chmod a+x networkChecking.sh

    # Network Checking
        (/usr/bin/drcom > /dev/null &)&
        sh networkChecking.sh
        echo "Network checking..."
        sleep 2s
        ping -c 1 baidu.com > /dev/null 2>&1

        if [ $? -eq 0 ]
        then
        echo "OK..."
        else
        echo "Failed... Please contact me."
        exit 0
        fi
}

setup_crontab() {
#setup cron
		case $ifSet in
		Y|y)
				echo "Set up cron..."
				echo "Ki8xICogKiAqICogc2ggL3Vzci9iaW4vbmV0d29ya0NoZWNraW5nLnNoICYmIHNsZWVwIDMwICYmIHNoIC91c3IvYmluL25ldHdvcmtDaGVja2luZy5zaAoqICovOCAqICogKiBlY2hvICA+IH4vbmV0d29ya0NoZWNraW5nLmxvZwo=" | base64 -d > wrtcron
				chmod a+x wrtcron
				cp -p networkChecking.sh /usr/bin/
				crontab wrtcron
				/etc/init.d/cron restart
				sleep 1s;;
		N|n)
				;;
		esac
}

# setup wireless interface
setup_wlan() {
    case $ifChange in
    Y|y|"")
        if [[ $distro == "openwrt" ]]
        then
            uci set wireless.@wifi-device[0].disabled=0
            uci set wireless.@wifi-device[1].disabled=0
            uci set wireless.@wifi-iface[0].ssid="$wifi_ssid0"
            uci set wireless.@wifi-iface[1].ssid="$wifi_ssid1"
        fi
        uci set wireless.@wifi-iface[0].encryption=psk2
        uci set wireless.@wifi-iface[1].encryption=psk2
        uci set wireless.@wifi-iface[0].key="$wifi_password0"
        uci set wireless.@wifi-iface[1].key="$wifi_password1"
        uci commit
        wifi up
        wifi reload;;
    N|n|*)
        echo "password will leave empty";;
    esac
}

setup_done() {
    sleep 1s
    clear
    echo "Done. Enjoy!"
    echo "--------------------"
    echo "Wifi ssid (5Ghz) :" "$wifi_ssid0"
    echo "Passwd :" "$wifi_password0"
    echo "Wifi ssid (2.4Ghz) :" "$wifi_ssid1"
    echo "Passwd :" "$wifi_password1"
    echo ""
    echo "Note: some of mobile phones of Huawei and OPPO don't support 5Ghz wifi, so"
    echo "  you may find only one ssid of your routine in the list."
    echo "--------------------"
}

setup_done_debug() {
		echo "=========="
		echo "Student number: "
		echo $username
		echo "Password: "
		echo $password
		echo "Wifi ssid (5Ghz) :" "$wifi_ssid0"
		echo "Passwd :" "$wifi_password0"
		echo "Wifi ssid (2.4Ghz) :" "$wifi_ssid1"
		echo "Passwd :" "$wifi_password1"
		echo "Crontab: "
		echo $ifSet
		echo "=========="
		uname -a
		echo $distro
		cat /etc/os-release
}

# for end for process bar
spin() {
		sp='/-\|'
		printf ' '
		while true; do
				printf '\b%.1s' "$sp"
				sp=${sp#?}${sp%???}
				sleep 0
		done

}

# process bar
progressbar()
{
       bar="##################################################"
       barlength=${#bar}
       n=$(($1*barlength/100))
       printf "\r[%-${barlength}s (%d%%)] " "${bar:0:n}" "$1"
}

# Handle actions without options
if [ ! $1 ]; then
		# config renew after sys-upgrade
		read -p "Is is installation after system upgrade? [y/N]: " ifSet_upgrade
		case $ifSet_upgrade in
				n|N|"")
						clear
						hello
						network_config
						root_pwd_change
						inform_gather
						wlan_ssid_settings
						wlan_passwd_setting
						setup_confirm
						clean_up
						setup_packages
						setup_drcom
						setup_crontab
						setup_wlan
						setup_done
						;;
				y|Y)
						clear
						wifi_ssid0="the one you have set"
						wifi_ssid1="the one you have set"
						wifi_password0="the one you have set"
						wifi_password1="the one you have set"
						hello
						network_config
						inform_gather
						setup_confirm
						setup_packages
						setup_drcom
						setup_crontab
						setup_done
						echo "All done!"
						;;
		esac
else # When running with options
		while getopts "$optspec" optchar; do
				case $optchar in
				-)
						case $OPTARG in
						dry-run)
								clear
								echo "This flag is for test and will print most of the variables."
								network_config
								root_pwd_change
								inform_gather
								wlan_ssid_settings
								wlan_passwd_setting
								setup_confirm
								setup_done_debug
								;;
						help)
								echo ""
								echo "USAGE: sh ./setup.sh [options]"
								echo ""
								echo "-V, --dry-run		Verbose. Run the scripts without actually setting up."
								echo "-c              Change config file."
								echo "-h, --help			Display this message."
								echo "-v, --version   Print version info."
								;;
						version)
								echo "https://github.com/purefkh/CQU_drcom/"
								echo "Version:" $VERSION_CQU_DRCOM
								;;
						esac
						;;
				V)
						clear
						echo "This flag is for test and will print most of the variables."
						hello
						network_config
						root_pwd_change
						inform_gather
						wlan_ssid_settings
						wlan_passwd_setting
						setup_confirm
						setup_done_debug
						;;
				h)
						echo "USAGE: sh ./setup.sh [options]"
						echo "-V, --dry-run			Verbose. Run the scripts without actually setting up."
						echo "-h, --help				Display this message."
						;;
				c)
						;;
				v)
						;;
				*)
						if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                echo "Non-option argument: '-${OPTARG}'" >&2
            fi
						;;
				esac
		done
fi
