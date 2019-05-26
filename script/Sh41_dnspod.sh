#!/bin/sh
#copyright by hiboy
source /etc/storage/script/init.sh
dnspod_enable=`nvram get dnspod_enable`
[ -z $dnspod_enable ] && dnspod_enable=0 && nvram set dnspod_enable=0
if [ "$dnspod_enable" != "0" ] ; then
#nvramshow=`nvram showall | grep '=' | grep dnspod | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow

dnspod_username=`nvram get dnspod_username`
dnspod_password=`nvram get dnspod_password`
dnspod_Token=`nvram get dnspod_Token`
dnspod_domian=`nvram get dnspod_domian`
dnspod_host=`nvram get dnspod_host`
dnspod_domian2=`nvram get dnspod_domian2`
dnspod_host2=`nvram get dnspod_host2`
dnspod_domian6=`nvram get dnspod_domian6`
dnspod_host6=`nvram get dnspod_host6`
dnspod_interval=`nvram get dnspod_interval`

IPv6=0
domain_type=""
post_type=""
hostIP=""
myIP=""
[ -z $dnspod_interval ] && dnspod_interval=600 && nvram set dnspod_interval=$dnspod_interval
fi

if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep dnspod)" ]  && [ ! -s /tmp/script/_dnspod ]; then
	mkdir -p /tmp/script
	{ echo '#!/bin/sh' ; echo $scriptfilepath '"$@"' '&' ; } > /tmp/script/_dnspod
	chmod 777 /tmp/script/_dnspod
fi

dnspod_get_status () {

A_restart=`nvram get dnspod_status`
B_restart="$dnspod_enable$dnspod_username$dnspod_password$dnspod_Token$dnspod_domian$dnspod_host$dnspod_domian2$dnspod_host2$dnspod_domian6$dnspod_host6$dnspod_interval$(cat /etc/storage/ddns_script.sh | grep -v '^#' | grep -v "^$")"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
if [ "$A_restart" != "$B_restart" ] ; then
	nvram set dnspod_status=$B_restart
	needed_restart=1
else
	needed_restart=0
fi
}

dnspod_check () {

dnspod_get_status
if [ "$dnspod_enable" != "1" ] && [ "$needed_restart" = "1" ] ; then
	[ ! -z "$(ps -w | grep "$scriptname keep" | grep -v grep )" ] && logger -t "【DNSPod动态域名】" "停止 dnspod" && dnspod_close
	{ kill_ps "$scriptname" exit0; exit 0; }
fi
if [ "$dnspod_enable" = "1" ] ; then
[ "x${dnspod_Token}" = "x" ] && [ "x${dnspod_username}" = "x" ] && [ "x${dnspod_password}" = "x" ] && { logger -t "【DNSPod动态域名】" "用户名密码或者 Token 等设置未填写, 10 秒后自动尝试重新启动" && sleep 10; nvram set dnspod_status=00; eval "$scriptfilepath &"; exit 0; }
	if [ "$needed_restart" = "1" ] ; then
		dnspod_close
		eval "$scriptfilepath keep &"
		exit 0
	else
		[ -z "$(ps -w | grep "$scriptname keep" | grep -v grep )" ] && nvram set dnspod_status=00 && { eval "$scriptfilepath start &"; exit 0; }
	fi
fi
}

dnspod_keep () {
dnspod_start
logger -t "【DNSPod动态域名】" "守护进程启动"
while true; do
sleep 41
sleep $dnspod_interval
#nvramshow=`nvram showall | grep '=' | grep dnspod | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow
dnspod_enable=`nvram get dnspod_enable`
[ "$dnspod_enable" = "0" ] && dnspod_close && exit 0;
if [ "$dnspod_enable" = "1" ] ; then
	dnspod_start
fi
done
}

dnspod_close () {
kill_ps "/tmp/script/_dnspod"
kill_ps "_dnspod.sh"
kill_ps "$scriptname"
}

dnspod_start () {
IPv6=0
if [ "$dnspod_domian"x != "x" ] && [ "$dnspod_host"x != "x" ] ; then
	DOMAIN="$dnspod_domian"
	HOST="$dnspod_host"
	arDdnsCheck $dnspod_domian $dnspod_host
fi
if [ "$dnspod_domian2"x != "x" ] && [ "$dnspod_host2"x != "x" ] ; then
	sleep 1
	DOMAIN="$dnspod_domian2"
	HOST="$dnspod_host2"
	arDdnsCheck $dnspod_domian2 $dnspod_host2
fi
if [ "$dnspod_domian6"x != "x" ] && [ "$dnspod_host6"x != "x" ] ; then
	IPv6=1
	DOMAIN="$dnspod_domian6"
	HOST="$dnspod_host6"
	arDdnsCheck $dnspod_domian6 $dnspod_host6
fi
}

arDdnsInfo() {
	local domainID recordID recordIP
	if [ "$IPv6" = "1" ]; then
		domain_type="AAAA"
		post_type="Record.Modify"
	else
		domain_type="A"
		post_type="Record.Ddns"
	fi
	# 获得域名ID
	domainID=$(arApiPost "Domain.Info" "domain=$DOMAIN")
	domainID=$(echo $domainID | grep -Eo '"id":"[0-9]+"' | cut -d':' -f2 | tr -d '"')
	
	# 获得记录ID
	recordID=$(arApiPost "Record.List" "domain_id=${domainID}&sub_domain=$HOST")
	recordID=$(echo $recordID | sed -e "s/"'"remark":'"/"' \n '"/g" | grep '"type":"'$domain_type'"' | grep -Eo '"id":"[0-9]+"' | cut -d':' -f2 | tr -d '"' |head -n1)
	
	# 获得最后更新IP
	recordIP=$(arApiPost "Record.Info" "domain_id=${domainID}&record_id=${recordID}")
	recordIP=$(echo $recordIP | grep -Eo '"value":"[^"]*"' | awk -F ':"' '{print $2}' | tr -d '"' |head -n1)

	# Output IP
	if [ "$IPv6" = "1" ]; then
	echo $recordIP
	return 0
	else
	case "$recordIP" in 
	[1-9]*)
		echo $recordIP
		return 0
		;;
	*)
		echo "Get Record Info Failed!"
		#logger -t "【DNSPod动态域名】" "获取记录信息失败！"
		return 1
		;;
	esac
	fi
}

# 查询域名地址
# 参数: 待查询域名
arNslookup() {
mkdir -p /tmp/arNslookup
nslookup $1 | tail -n +3 | grep "Address" | awk '{print $3}'| grep -v ":" | sed -n '1p' > /tmp/arNslookup/$$ &
I=5
while [ ! -s /tmp/arNslookup/$$ ] ; do
		I=$(($I - 1))
		[ $I -lt 0 ] && break
		sleep 1
done
killall nslookup
if [ -s /tmp/arNslookup/$$ ] ; then
cat /tmp/arNslookup/$$ | sort -u | grep -v "^$"
rm -f /tmp/arNslookup/$$
else
	curltest=`which curl`
	if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
		Address="`wget --no-check-certificate --quiet --output-document=- http://119.29.29.29/d?dn=$1`"
		if [ $? -eq 0 ]; then
		echo "$Address" |  sed s/\;/"\n"/g | sed -n '1p' | grep -E -o '([0-9]+\.){3}[0-9]+'
		fi
	else
		Address="`curl -k -s http://119.29.29.29/d?dn=$1`"
		if [ $? -eq 0 ]; then
		echo "$Address" |  sed s/\;/"\n"/g | sed -n '1p' | grep -E -o '([0-9]+\.){3}[0-9]+'
		fi
	fi
fi
}

arNslookup6() {
mkdir -p /tmp/arNslookup
nslookup $1 | tail -n +3 | grep "Address" | awk '{print $3}'| grep ":" | sed -n '1p' > /tmp/arNslookup/$$ &
I=5
while [ ! -s /tmp/arNslookup/$$ ] ; do
		I=$(($I - 1))
		[ $I -lt 0 ] && break
		sleep 1
done
killall nslookup
if [ -s /tmp/arNslookup/$$ ] ; then
	cat /tmp/arNslookup/$$ | sort -u | grep -v "^$"
	rm -f /tmp/arNslookup/$$
fi
}

# 读取接口数据
# 参数: 接口类型 待提交数据
arApiPost() {
	agent="AnripDdns/5.07(mail@anrip.com)"
	inter="https://dnsapi.cn/${1:?'Info.Version'}"
	if [ "x${dnspod_Token}" = "x" ] ; then # undefine token
		param="login_email=${dnspod_username}&login_password=${dnspod_password}&format=json&$2"
	else
		param="login_token=${dnspod_Token}&format=json&$2"
	fi
	
	
	curltest=`which curl`
	if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
		wget --quiet --no-check-certificate --output-document=- --user-agent=$agent --post-data $param $inter
	else
		curl -k -X POST $inter -d $param
	fi
}

# 更新记录信息
# 参数: 主域名 子域名
arDdnsUpdate() {
	#local domainID recordID recordRS recordCD recordIP
I=3
recordID=""
	if [ "$IPv6" = "1" ]; then
		domain_type="AAAA"
		post_type="Record.Modify"
	else
		domain_type="A"
		post_type="Record.Ddns"
	fi
while [ "$recordID" = "" ] ; do
	I=$(($I - 1))
	[ $I -lt 0 ] && break
	# 获得域名ID
	domainID=$(arApiPost "Domain.Info" "domain=$DOMAIN")
	domainID=$(echo $domainID  | grep -Eo '"id":"[0-9]+"' | cut -d':' -f2 | tr -d '"')
	sleep 1
	# 获得记录ID
	recordID=$(arApiPost "Record.List" "domain_id=${domainID}&sub_domain=$HOST")
	recordID=$(echo $recordID | sed -e "s/"'"remark":'"/"' \n '"/g" | grep '"type":"'$domain_type'"' | grep -Eo '"id":"[0-9]+"' | cut -d':' -f2 | tr -d '"' |head -n1)
done
	#echo "更新记录信息 recordID: " $recordID
	if [ "$recordID" = "" ] ; then
		# 添加子域名记录IP
		myIP=$hostIP
		logger -t "【DNSPod动态域名】" "添加子域名 $HOST 记录IP: $myIP"
		recordRS=$(arApiPost "Record.Create" "domain_id=${domainID}&sub_domain=$HOST&record_type=${domain_type}&value=${myIP}&record_line=默认")
	else
		# 更新记录IP
		myIP=$hostIP
		recordRS=$(arApiPost "${post_type}" "domain_id=${domainID}&record_id=${recordID}&sub_domain=$HOST&record_type=${domain_type}&value=${myIP}&record_line=默认")
	fi
	recordCD=$(echo $recordRS | grep -Eo '"code":"[0-9]+"' | cut -d':' -f2 | tr -d '"')
	recordIP=$(echo $recordRS | grep -Eo '"value":"[^"]*"' | awk -F ':"' '{print $2}' | tr -d '"')
	# 输出记录IP
	if [ "$recordIP" = "" ] ; then
		sleep 10
		# 获得记录ID
		recordID=$(arApiPost "Record.List" "domain_id=${domainID}&sub_domain=$HOST")
		recordID=$(echo $recordID | sed -e "s/"'"remark":'"/"' \n '"/g" | grep '"type":"'$domain_type'"' | grep -Eo '"id":"[0-9]+"' | cut -d':' -f2 | tr -d '"' |head -n1)
		
		# 获得最后更新IP
		recordIP=$(arApiPost "Record.Info" "domain_id=${domainID}&record_id=${recordID}")
		recordIP=$(echo $recordIP | grep -Eo '"value":"[^"]*"' | awk -F ':"' '{print $2}' | tr -d '"' |head -n1)
	fi
	if [ "$recordIP" = "$myIP" ]; then
		if [ "$recordCD" = "1" ] ; then
			echo $recordIP
			logger -t "【DNSPod动态域名】" "`echo $recordRS | grep -Eo '"message":"[^"]*"' | cut -d':' -f2 | tr -d '"'`"
			return 0
		fi
		# 输出错误信息
		echo $recordRS | grep -Eo '"message":"[^"]*"' | cut -d':' -f2 | tr -d '"'
		logger -t "【DNSPod动态域名】" "`echo $recordRS | grep -Eo '"message":"[^"]*"' | cut -d':' -f2 | tr -d '"'`"
		return 1
	fi
	# 输出错误信息
	echo "Update Failed! Please check your network."
	logger -t "【DNSPod动态域名】" "`echo $recordRS | grep -Eo '"message":"[^"]*"' | cut -d':' -f2 | tr -d '"'`"
	return 1
}

# 动态检查更新
# 参数: 主域名 子域名
arDdnsCheck() {
	#local postRS
	#local lastIP
	source /etc/storage/ddns_script.sh
	hostIP=$arIpAddress
	hostIP=`echo $hostIP | head -n1 | cut -d' ' -f1`
	if [ -z $(echo "$hostIP" | grep : | grep -v "\.") ] && [ "$IPv6" = "1" ] ; then 
		IPv6=0
		logger -t "【DNSPod动态域名】" "错误！$hostIP 获取目前 IPv6 失败，请在脚本更换其他获取地址，保证取得IPv6地址(例如:ff03:0:0:0:0:0:0:c1)"
		return 1
	fi
	if [ "$hostIP"x = "x"  ] ; then
		curltest=`which curl`
		if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
			[ "$hostIP"x = "x"  ] && hostIP=`wget --no-check-certificate --quiet --output-document=- "ip.6655.com/ip.aspx" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget --no-check-certificate --quiet --output-document=- "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget --no-check-certificate --quiet --output-document=- "ip.3322.net" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget --no-check-certificate --quiet --output-document=- "https://www.ipip.net/" | grep "IP地址" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
		else
			[ "$hostIP"x = "x"  ] && hostIP=`curl -k -s ip.6655.com/ip.aspx | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -k -s "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -k -s ip.3322.net | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L -k -s "https://www.ipip.net" | grep "IP地址" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
		fi
		if [ "$hostIP"x = "x"  ] ; then
			logger -t "【DNSPod动态域名】" "错误！获取目前 IP 失败，请在脚本更换其他获取地址"
			return 1
		fi
	fi
	echo "Updating Domain: $HOST.$DOMAIN"
	echo "hostIP: ${hostIP}"
	#lastIP=$(arNslookup "$HOST.$DOMAIN")
	lastIP=$(arDdnsInfo "$DOMAIN" "$HOST")
	if [ $? -eq 1 ]; then
		[ "$IPv6" != "1" ] && lastIP=$(arNslookup "$HOST.$DOMAIN")
		[ "$IPv6" = "1" ] && lastIP=$(arNslookup6 "$HOST.$DOMAIN")
	fi
	echo "lastIP: ${lastIP}"
	if [ "$lastIP" != "$hostIP" ] ; then
		logger -t "【DNSPod动态域名】" "开始更新 $HOST.$DOMAIN 域名 IP 指向"
		logger -t "【DNSPod动态域名】" "目前 IP: ${hostIP}"
		logger -t "【DNSPod动态域名】" "上次 IP: ${lastIP}"
		sleep 1
		postRS=$(arDdnsUpdate "$DOMAIN" "$HOST")
		if [ $? -eq 0 ]; then
			echo "postRS: ${postRS}"
			logger -t "【DNSPod动态域名】" "更新动态DNS记录成功！提交的IP: ${postRS}"
			return 0
		else
			echo ${postRS}
			logger -t "【DNSPod动态域名】" "更新动态DNS记录失败！请检查您的网络。提交的IP: ${postRS}"
			if [ "$IPv6" = "1" ] ; then 
				IPv6=0
				logger -t "【DNSPod动态域名】" "错误！$hostIP 获取目前 IPv6 失败，请在脚本更换其他获取地址，保证取得IPv6地址(例如:ff03:0:0:0:0:0:0:c1)"
				return 1
			fi
			return 1
		fi
	fi
	echo "Last IP is the same as current IP!"
	return 1

}

initconfig () {

if [ ! -s "/etc/storage/ddns_script.sh" ] ; then
cat > "/etc/storage/ddns_script.sh" <<-\EEE
# 自行测试哪个代码能获取正确的IP，删除前面的#可生效
arIpAddress () {
# IPv4地址获取
# 获得外网地址
curltest=`which curl`
if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
    #wget --no-check-certificate --quiet --output-document=- "https://www.ipip.net" | grep "IP地址" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    wget --no-check-certificate --quiet --output-document=- "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #wget --no-check-certificate --quiet --output-document=- "ip.6655.com/ip.aspx" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #wget --no-check-certificate --quiet --output-document=- "ip.3322.net" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
else
    #curl -L -k -s "https://www.ipip.net" | grep "IP地址" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    curl -k -s "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #curl -k -s ip.6655.com/ip.aspx | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #curl -k -s ip.3322.net | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
fi
}
arIpAddress6 () {
# IPv6地址获取
# 因为一般ipv6没有nat ipv6的获得可以本机获得
ifconfig $(nvram get wan0_ifname_t) | awk '/Global/{print $3}' | awk -F/ '{print $1}'
}
if [ "$IPv6" = "1" ] ; then
arIpAddress=$(arIpAddress6)
else
arIpAddress=$(arIpAddress)
fi
EEE
	chmod 755 "$ddns_script"
fi

}

initconfig

case $ACTION in
start)
	dnspod_close
	dnspod_check
	;;
check)
	dnspod_check
	;;
stop)
	dnspod_close
	;;
keep)
	dnspod_keep
	;;
*)
	dnspod_check
	;;
esac

