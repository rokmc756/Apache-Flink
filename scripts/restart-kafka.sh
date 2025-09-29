for i in `echo "1 3"`
do
    ssh root@co7-node0$i 'systemctl stop firewalld'
    ssh root@co7-node0$i 'systemctl restart kafka zookeeper'
    ssh root@co7-node0$i 'systemctl status kafka zookeeper'
done

ssh root@co7-master 'systemctl stop firewalld'
ssh root@co7-master 'systemctl restart kafka-ui'
ssh root@co7-master 'systemctl status kafka-ui'
