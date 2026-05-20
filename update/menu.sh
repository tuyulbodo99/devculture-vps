#!/bin/bash
# =================================================================
#   DevCulture VPS — Main Menu  v3.2.0
#   @devculturebot | github.com/tuyulbodo99/devculture-vps
# =================================================================
set -euo pipefail
source /usr/local/lib/devculture/utils.sh 2>/dev/null || {
  LIB_URL=https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/lib/utils.sh
  TMP=$(mktemp /tmp/dc-XXXXX.sh)
  wget -qO $TMP $LIB_URL 2>/dev/null || curl -fsSL $LIB_URL -o $TMP
  source $TMP; rm -f $TMP
}
check_root; check_license



PERMISSION

if [ "$res" = "Expired" ]; then
Exp="\e[36mExpired\033[0m"
rm -f /home/needupdate > /dev/null 2>&1
else
Exp=$(curl -sS https://raw.githubusercontent.com/tuyulbodo99/ijin/main/original | grep $MYIP | awk '{print $3}')
fi
export RED='\033[0;31m'
export GREEN='\033[0;32m'

# // SSH Websocket Proxy
ssh_ws=$( systemctl status ws-stunnel | grep Active | awk '{print $3}' | sed 's/(//g' | sed 's/)//g' )
if [[ $ssh_ws == "running" ]]; then
    status_ws="${GREEN}ON${NC}"
else
    status_ws="${RED}OFF${NC}"
fi

# // nginx
nginx=$( systemctl status nginx | grep Active | awk '{print $3}' | sed 's/(//g' | sed 's/)//g' )
if [[ $nginx == "running" ]]; then
    status_nginx="${GREEN}ON${NC}"
else
    status_nginx="${RED}OFF${NC}"
fi

# // SSH Websocket Proxy
xray=$( systemctl status xray | grep Active | awk '{print $3}' | sed 's/(//g' | sed 's/)//g' )
if [[ $xray == "running" ]]; then
    status_xray="${GREEN}ON${NC}"
else
    status_xray="${RED}OFF${NC}"
fi

function add-host(){
clear
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC} ${COLBG1}               • ADD VPS HOST •                ${NC} $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
read -rp "  New Host Name : " -e host
echo ""
if [ -z $host ]; then
echo -e "  [INFO] Type Your Domain/sub domain"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo ""
read -n 1 -s -r -p "  Press any key to back on menu"
menu
else
echo "IP=$host" > /var/lib/devculturevpn-pro/ipvps.conf
echo ""
echo "  [INFO] Dont forget to renew cert"
echo ""
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo ""
read -n 1 -s -r -p "  Press any key to Renew Cret"
crtxray
fi
}
function updatews(){
clear

echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC} ${COLBG1}            • UPDATE SCRIPT VPS •              ${NC} $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC}  $COLOR1[INFO]${NC} Check for Script updates"
sleep 2
wget -q -O /root/install_up.sh "https://raw.githubusercontent.com/tuyulbodo99/original/main/update/update.sh" && chmod +x /root/install_up.sh
sleep 2
./install_up.sh
sleep 5
rm /root/install_up.sh
rm /opt/.ver
version_up=$( curl -sS https://raw.githubusercontent.com/tuyulbodo99/ijin/main/versi)
echo "$version_up" > /opt/.ver
echo -e "$COLOR1│${NC}  $COLOR1[INFO]${NC} Successfully Up To Date!"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌────────────────────── BY ───────────────────────┐${NC}"
echo -e "$COLOR1│${NC}              • DevCulture •                $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
echo ""
read -n 1 -s -r -p "  Press any key to back on menu"
menu
}
clear
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC} ${COLBG1}               • VPS PANEL MENU •              ${NC} $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
uphours=`uptime -p | awk '{print $2,$3}' | cut -d , -f1`
upminutes=`uptime -p | awk '{print $4,$5}' | cut -d , -f1`
uptimecek=`uptime -p | awk '{print $6,$7}' | cut -d , -f1`
cekup=`uptime -p | grep -ow "day"`
IPVPS=$(curl -s ipinfo.io/ip )
serverV=$( curl -sS https://raw.githubusercontent.com/tuyulbodo99/ijin/main/versi)
if [ "$Isadmin" = "ON" ]; then
uis="${GREEN}Premium User$NC"
else
uis="${RED}Free Version$NC"
fi
echo -e "$COLOR1│$NC User Roles     : $uis"
if [ "$cekup" = "day" ]; then
echo -e "$COLOR1│$NC System Uptime  : $uphours $upminutes $uptimecek"
else
echo -e "$COLOR1│$NC System Uptime  : $uphours $upminutes"
fi
echo -e "$COLOR1│$NC Memory Usage   : $uram / $tram"
echo -e "$COLOR1│$NC ISP & City     : $ISP & $CITY"
echo -e "$COLOR1│$NC Current Domain : $(cat /etc/xray/domain)"
echo -e "$COLOR1│$NC IP-VPS         : ${COLOR1}$IPVPS${NC}"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│$NC [ SSH WS : ${status_ws} ]  [ XRAY : ${status_xray} ]   [ NGINX : ${status_nginx} ] $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "  ${COLOR1}[01]${NC} • SSHWS   [${YELLOW}Menu${NC}]   ${COLOR1}[07]${NC} • THEME    [${YELLOW}Menu${NC}]  $COLOR1│$NC"   
echo -e "  ${COLOR1}[02]${NC} • VMESS   [${YELLOW}Menu${NC}]   ${COLOR1}[08]${NC} • BACKUP   [${YELLOW}Menu${NC}]  $COLOR1│$NC"  
echo -e "  ${COLOR1}[03]${NC} • VLESS   [${YELLOW}Menu${NC}]   ${COLOR1}[09]${NC} • ADD HOST/DOMAIN  $COLOR1│$NC"  
echo -e "  ${COLOR1}[04]${NC} • TROJAN  [${YELLOW}Menu${NC}]   ${COLOR1}[10]${NC} • RENEW CERT       $COLOR1│$NC"  
echo -e "  ${COLOR1}[05]${NC} • SS WS   [${YELLOW}Menu${NC}]   ${COLOR1}[11]${NC} • SETTINGS [${YELLOW}Menu${NC}]  $COLOR1│$NC"
echo -e "  ${COLOR1}[06]${NC} • SET DNS [${YELLOW}Menu${NC}]   ${COLOR1}[12]${NC} • INFO     [${YELLOW}Menu${NC}]  $COLOR1│$NC"
if [ "$Isadmin" = "ON" ]; then
echo -e "                                                  $COLOR1│$NC"
echo -e "  ${COLOR1}[13]${NC} • REG IP  [${YELLOW}Menu${NC}]   ${COLOR1}[14]${NC} • SET BOT  [${YELLOW}Menu${NC}]  $COLOR1│$NC"
ressee="menu-ip"
bottt="menu-bot"
else
ressee="menu"
bottt="menu"
fi
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
myver="$(cat /opt/.ver)"

if [[ $serverV > $myver ]]; then
echo -e "$RED┌─────────────────────────────────────────────────┐${NC}"
echo -e "$RED│$NC ${COLOR1}[100]${NC} • UPDATE TO V$serverV" 
echo -e "$RED└─────────────────────────────────────────────────┘${NC}"
up2u="updatews"
else
up2u="menu"
fi

DATE=$(date +'%d %B %Y')
datediff() {
    d1=$(date -d "$1" +%s)
    d2=$(date -d "$2" +%s)
    echo -e "$COLOR1│$NC Expiry In   : $(( (d1 - d2) / 86400 )) Days"
}
mai="datediff "$Exp" "$DATE""

echo -e "$COLOR1┌─────────────────────────────────────────────────┐$NC"
echo -e "$COLOR1│$NC Version     :${COLOR1} $(cat /opt/.ver) Latest Version${NC}"
echo -e "$COLOR1│$NC Client Name : $Name"
if [ $exp \> 1000 ];
then
    echo -e "$COLOR1│$NC License     : Lifetime"
else
    datediff "$Exp" "$DATE"
fi;
echo -e "$COLOR1└─────────────────────────────────────────────────┘$NC"
echo -e "$COLOR1┌────────────────────── BY ───────────────────────┐${NC}"
echo -e "$COLOR1│${NC}              • DevCulture •            $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
echo -e ""
echo -ne " Select menu : "; read opt
case $opt in
01 | 1) clear ; menu-ssh ;;
02 | 2) clear ; menu-vmess ;;
03 | 3) clear ; menu-vless ;;
04 | 4) clear ; menu-trojan ;;
05 | 5) clear ; menu-ss ;;
06 | 6) clear ; menu-dns ;;
06 | 7) clear ; menu-theme ;;
07 | 8) clear ; menu-backup ;;
09 | 9) clear ; add-host ;;
10) clear ; crtxray ;;
11) clear ; menu-set ;;
12) clear ; info ;;
13) clear ; $ressee ;;
14) clear ; $bottt ;;
100) clear ; $up2u ;;
00 | 0) clear ; menu ;;
*) clear ; menu ;;
esac
