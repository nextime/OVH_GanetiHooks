To use this you should separe your ip failover ripe in single ip failover /32, and route
every ip to your virtual machines as singular 255.255.255.255 netmask ip.

i also use ospf to manage internal routing.

Put your external ip address as instance tags in this way:

gnt-instance add-tags ${instance_name} route:${ipaddr}/32:${INTERFACE}

for example:

gnt-instance add-tags instance01 route:81.82.83.84/32:br0


1- put all the directory and files of the tarball in /etc/ganeti
2- edit /etc/ganeti/scripts/ovh_cmd and change both $hostmap, $username and $passwd according to your use case
3- put a crontab that touch /tmp/ganeti.checkroute one time every $(choose_your_time, i use 1 hour)
4- put a touch /tmp/ganeti.checkroute in /etc/rc.local
5- put a crontab to execute every minute /etc/ganeti/cron/00-external-routes (look at example crontab)

Every time you migrate, move, failover, start, stop an instance, it should automagically update ovh failover routes.

