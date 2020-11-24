#!/bin/bash

shell_dir=$(dirname $0)
has_serial="false"
has_root="false"
has_proxy_ip="false"
has_proxy_port="false"
redsocks_port=8989

while [[ $# -ge 1 ]]; do
	case $1 in
		-s )
		  has_serial="true"
			serial=$2
			shift 2
			;;
		-r|--root )
			has_root="true"
			shift
			;;
		-p|--proxy_ip )
		  has_proxy_ip="true"
			proxy_ip=$2
			shift 2
			;;
	  -P|--proxy_port )
	    has_proxy_port="true"
	    proxy_port=$2
	    shift 2
	    ;;
	  --redsocks_port )
	    redsocks_port=$2
	    shift 2
	  ;;
		* )
			echo "unknown parameter: $1"
			shift
			;;
	esac
done

adb_base="adb"

if [ $has_serial == "true" ]; then
  adb_base="$adb_base -s $serial"
fi

if [ $has_root == "true" ]; then
  adb_shell="$adb_base shell su -c"
else
  adb_shell="$adb_base shell"
fi

if [ $has_proxy_ip == "false" ]; then
    echo "not found proxy ip address parameter, use -p or --proxy_ip."
    exit 0
fi

if [ $has_proxy_port == "false" ]; then
    echo "not found proxy port parameter, use --proxy_port."
    exit 0
fi



echo "1. Create REDSOCKS chain in nat table."
command="$adb_shell iptables -t nat -N REDSOCKS"
echo "execute: $command"
eval "$command"

printf "2. Ignore LANs and some other reserved addresses.\nSee Wikipedia and RFC5735 for full list of reserved networks."
command="$adb_shell iptables -t nat -A REDSOCKS -d 0.0.0.0/8          -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 10.0.0.0/8         -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 100.64.0.0/10      -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 127.0.0.0/8        -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 169.254.0.0/16     -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 172.16.0.0/12      -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 192.0.0.0/24       -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 192.0.2.0/24       -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 192.88.99.0/24     -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 192.168.0.0/16     -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 198.18.0.0/15      -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 198.51.100.0/24    -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 203.0.113.0/24     -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 224.0.0.0/4        -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 240.0.0.0/4        -j RETURN" && eval "$command"
command="$adb_shell iptables -t nat -A REDSOCKS -d 255.255.255.255/32 -j RETURN" && eval "$command"

echo "3. Ignore proxy IP address in REDSOCKS chain."
command="$adb_shell iptables -t nat -A REDSOCKS -d $proxy_ip     -j RETURN"
echo "execute: $command"
eval "$command"

echo "4. Anything else should be redirected to local port port."
command="$adb_shell iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports $redsocks_port"
echo "execute: $command"
eval "$command"

echo "5. apply REDSOCKS Chain on nat.OUTPUT."
command="$adb_shell iptables -t nat -A OUTPUT -p tcp -j REDSOCKS"
echo "execute: $command"
eval "$command"

echo "6. lookup nat.OUTPUT and nat.REDSOCKS table."
command="$adb_shell iptables --line -t nat -nvxL OUTPUT"
eval "$command"
command="$adb_shell iptables --line -t nat -nvxL REDSOCKS"
eval "$command"

echo "
base {
  log_debug = off;
  log_info = off;
  log = stderr;
  daemon = on;
  redirector = iptables;
}
redsocks {
  local_ip = 0.0.0.0;
  local_port = $redsocks_port;
  ip = $proxy_ip;
  port = $proxy_port;
  type = socks5;
}
" > $shell_dir/redsocks.conf


echo "7. push redsocks and config to the device."
command="$adb_base push $shell_dir/redsocks* /data/local/tmp"
eval "$command"


echo "8. chmod a+x for redsocks and start."
command="$adb_shell chmod a+x /data/local/tmp/redsocks"
eval "$command"
command="$adb_shell /data/local/tmp/redsocks -c /data/local/tmp/redsocks.conf"
eval "$command"

