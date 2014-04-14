#!/bin/bash 

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/bin

SSHCMD="ssh -o ConnectTimeout=3 -o ServerAliveInterval=5 -o ServerAliveCountMax=3"

getmaster ()
{
   echo $(gnt-cluster getmaster)
}

i_am_master ()
{
   local master=$(getmaster)
   local me=$(hostname)
   if [ x"$master" = x"$me" ] ; then
      echo "true"
   else
      echo ""
   fi
}

mastercmd ()
{
   local cmd=""
   if [ -z $(i_am_master) ] ; then
      local cmd="$SSHCMD $(getmaster)"
   fi    
   echo $cmd
}

add_check_route_flag ()
{
   $(mastercmd) touch /tmp/ganeti.checkroute
}

del_check_route_flag ()
{
   $(mastercmd) rm -f /tmp/ganeti.checkroute
}

get_nodelist ()
{
   echo $(gnt-node list --no-header| awk '{print $1}')
}

get_instances_running_list ()
{
   local nodenames=""
   local nodelist=$(gnt-instance list --no-header)
   export IFS=$'\n'
   for nodeline in $nodelist
   do
      node=$(echo $nodeline | awk '{print $4}')
      nodenames="$node\n$nodenames"
   done
   unset IFS
   nodelist=$(echo -e $nodenames| sort | uniq)
   echo -e $nodelist

}



gettags ()
{
   local cmd=$(mastercmd)
   local res=$(${cmd} gnt-instance list -otags --no-headers $1 | grep "^route")
   echo $res
}

getv6tags ()
{
   local cmd=$(mastercmd)
   local res=$(${cmd} gnt-instance list -otags --no-headers $1 | grep "^v6")
   echo $res
}

i_am_primary ()
{
   local host=$(hostname)
   if [ -z $GANETI_NEW_PRIMARY ] ; then
      if [ x"$GANETI_INSTANCE_PRIMARY" != x"$host" ] ; then
         echo ""
      else
         echo "true"
      fi
   else
      if [ x"$GANETI_NEW_PRIMARY" != x"$host" ] ; then
         echo ""
      else
         echo "true"
      fi
   fi
   #echo $GANETI_NEW_PRIMARY $GANETI_INSTANCE_PRIMARY > /tmp/debug.ganeti2
}

route_exists ()
{
   # $1 => route
   # $2 => (optional) if "loc", apply only to non-zebra routes
   local chkaddr=`echo $1 | awk -F '/' '{print $1}'`
   if [ x"$2" = x"loc" ] ; then
      local check=`ip route | grep $chkaddr | grep -v zebra`
   else
      local check=`ip route | grep $chkaddr`
   fi
   if [ -z "$check" ] ; then
      echo ""
   else
      echo "true"
   fi
}

route6_exists ()
{
   # $1 => route
   # $2 => (optional) if "loc", apply only to non-zebra routes
   local chkaddr=`echo $1 | awk -F '/' '{print $1}'`
   if [ x"$2" = x"loc" ] ; then
      local check=`ip -6 route | grep $chkaddr | grep -v zebra`
   else
      local check=`ip -6 route | grep $chkaddr`
   fi
   if [ -z "$check" ] ; then
      echo ""
   else
      echo "true"
   fi
}


del_route ()
{
   # $1 => route
   # $2 => (optional) if "loc", apply only to non-zebra routes
   if [ $(route_exists $1 $2) ] ; then
      ip route del $1 
      #echo "$(date) del $1" >> /tmp/delroute.debug
   fi
   add_check_route_flag
}

del_v6route ()
{
   # We need to avoid returning != 0 
   setsid ip -6 neigh del proxy $1 dev eth0 > /dev/null 2>&1
   if [ $(route6_exists $1 $2) ] ; then
      ip -6 route del $1 dev $2
   fi
}


add_v6route ()
{
   ip -6 neigh add proxy $1 dev eth0
   if [ $(route6_exists $1) ] ; then
      del_route $1
   fi
   ip -6 route add $1 dev $2
}


add_route ()
{
   # $1 => route
   # $2 => interface
   if [ $(route_exists $1) ] ; then
      del_route $1
   fi
   ip route add $1 dev $2
   add_check_route_flag
}

get_ovh_iplist ()
{
   # $1 => node name
   echo $(/etc/ganeti/scripts/ovh_cmd list $1)
}


move_ovh_ip ()
{
   # $1 => from
   # $2 => to
   # $3 => ip
   echo $(/etc/ganeti/scripts/ovh_cmd move $1 $2 $3)
}

get_node_extip ()
{

   # $1 => node name
   if [ x"$1" != x"$(hostname)" ] ; then
      local cmd="$SSHCMD $1"
   fi
   local extroutes=`${cmd} ip route | grep -v proto | grep "scope link" | \
      grep -v -E "(^192\.168\.)|(^127\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^10\.)|(^169\.254\.)" | \
      awk '{print $1}'`
   
   echo $extroutes
}

