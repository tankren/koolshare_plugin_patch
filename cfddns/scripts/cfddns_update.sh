#!/bin/sh

eval `dbus export cfddns_`

if [ "$cfddns_enable" != "1" ]; then
    echo "not enable"
    exit
fi

now=`date '+%Y-%m-%d %H:%M:%S'`
ip=`$cfddns_curl 2>&1` || die "$ip"

[ "$cfddns_curl" = "" ] && cfddns_curl="curl -s whatismyip.akamai.com"
[ "$cfddns_ttl" = "" ] && cfddns_ttl="600"

die() {
    echo $1
    dbus ram cfddns_last_act="$now: failed($1)"
}

update_record() {
    curl -kLsX PUT "https://api.cloudflare.com/client/v4/zones/$cfddns_zone/dns_records/$cfddns_id" \
     -H "X-Auth-Email: $cfddns_email" \
     -H "X-Auth-Key: $cfddns_key" \
     -H "Content-Type: application/json" \
	 --data "{\"type\":\"A\",\"name\":\"$cfddns_domain\",\"content\":\"$ip\",\"ttl\":\"$cfddns_ttl\",\"proxied\":false}"
#	--data '{"type":"A","name":"$cfddns_domain","content":"$ip","ttl":"$cfddns_ttl","proxied":false}'
}

get_record_response() {
	curl -kLsX GET "https://api.cloudflare.com/client/v4/zones/$cfddns_zone/dns_records?type=A&name=$cfddns_domain&order=type&direction=desc&match=all" \
		-H "X-Auth-Email: $cfddns_email" -H "X-Auth-Key: $cfddns_key" -H "Content-type: application/json"
}

if [ "$?" -eq "0" ]; then
    cfddns_id=`get_record_response | awk -F"","" '{print $1}' | sed 's/{.*://g'`
    current_ip=`get_record_response | awk -F"","" '{print $4}' |grep -oE '([0-9]{1,3}\.?){4}'`

    if [ "$ip" = "$current_ip" ]; then
        echo "skipping"
        dbus set cfddns_last_act="$now: 跳过更新,路由器IP:($ip),A记录IP:($current_ip)"
        exit 0
    else
        echo "changing"
        update_record
        new_ip=`get_record_response | awk -F"","" '{print $4}' |grep -oE '([0-9]{1,3}\.?){4}'`
		
		if [ "$new_ip" = "$ip" ]; then
            dbus set cfddns_last_act="$now: 更新成功,路由器IP:($ip),A记录IP:($new_ip)"
        else
            dbus set cfddns_last_act="$now: 更新失败!请检查设置"
        fi
    fi 
fi
