#!/bin/bash

#=====================================================================
# This scipt parse smbd_audit log file. Experimental variant
# You need to add 
# log level = 0 vfs:2 
# vfs objects = full_audit
# full_audit:facility=LOCAL5
# full_audit:priority=INFO
# full_audit:failure = mkdir rmdir pwrite unlink rename
# full_audit:success = mkdir rmdir pwrite unlink rename
# full_audit:prefix = smbd_audit:%S|%u|%I
# into smb.conf. And
# :msg, contains, "smbd_audit"    /var/log/smbd_audit/smbd_audit.log
# :msg, contains, "smbd_audit"    stop
# into /etc/rsyslog.conf
#=====================================================================

tmp=/tmp/smbcheck
emails="test@exammple.com"
log=/var/log/smbd_audit/smbd_audit.log

#=====================================================================

touch $tmp
while true; do
    curtime=$(date +%T)
    tail -n50 $log | \
    sed -r 's/ ?//g' | \
    awk -F '|' '$4=="rename" && $1~/'$curtime'/ {print $3" "$6" "$7}' | \
    while read ip bef aft; do
        bef=$(dirname $bef)
        aft=$(dirname $aft)
        if [ $bef = $aft ]; then
            echo $ip >> $tmp
        fi
    done
    cat $tmp | sort | uniq -c | \
    while read cnt ip; do
        if [ "$cnt" -ge 3 ]; then
            echo $ip
            isb=$(iptables -L -nv | awk '/'$ip'/ && /445/ {print $NF}')
            if [ -z "$isb" ]; then
                iptables -I INPUT -p tcp -m multiport -s $ip --dports 139,445 -j DROP
                echo "Alert!!! blocked $ip for $cnt renames/sec" | \
                mail -s "[$(hostname -f)] encrypor blocked!!!" $emails
            fi
        fi
    done
    > $tmp
    sleep 0.2
done
