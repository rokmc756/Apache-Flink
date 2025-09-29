#!/bin/bash

# HOSTS="rk9-master rk9-slave rk9-node01 rk9-node02 rk9-node03"
# HOSTS="rk8-master rk8-slave rk8-node01 rk8-node02 rk8-node03"
HOSTS="co7-master co7-slave co7-node01 co7-node02 co7-node03"
# HOSTS="rh8-master rh8-slave rh8-node01 rh8-node02 rh8-node03"
for i in `echo "$HOSTS"`
do
    ssh root@$i "systemctl stop kafaka-ui"
    ssh root@$i "systemctl stop kafaka"
    ssh root@$i "systemctl stop zookeeper"
    ssh root@$i "systemctl disable kafaka-ui"
    ssh root@$i "systemctl disable kafaka"
    ssh root@$i "systemctl disable zookeeper"
    ssh root@$i "killall java"
done

for i in `echo "$HOSTS"`
do
    ssh root@$i "rm -rf /usr/local/kafka* /usr/local/apache-zookeeper* /var/log/zookeeper /var/lib/zookeeper /var/lib/kafka /tmp/lib/kafka/kafka-logs /tmp/zookeeper"
    ssh root@$i "sync; echo 3 > /proc/sys/vm/drop_caches"
    ssh root@$i "yum remove -y java*"
done
