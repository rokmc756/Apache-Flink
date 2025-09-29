NET_RANGE="192.168.2"
for i in `seq 1 5`
do

    sudo ping -c 1 $_NET_RANGE.19$i
    nc -vz $NET_RANGE.19$i 22
    ssh-keyscan $NET_RANGE.19$i
    # ssh-keyscan $NET_RANGE.19$i >/dev/null 2>&1

done

