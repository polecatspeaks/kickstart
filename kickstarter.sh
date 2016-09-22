#!/bin/bash -e

# SCRIPT TO GENERATE BASE KICKSTART FILES

# Help Text
function usage {
cat <<EOF
---------------------------------------------------------------------------------------------
This script is designed to create base templated Kickstart Files.
You will have to manually configure the drive partitioning as it may be different per server.
You will also  have to configure any custom packages as necessary.
---------------------------------------------------------------------------------------------

The following options ARE required.
  -e : ETHERNET : Set the nic name (EX: ethc0|em1)
  -i : IPADDR : Sets the IP Address of the Machine
  -s : SUBNETMASK : Sets the Subnetmask for the Network
  -g : GATEWAY : Sets the Gateway for the Network
  -m : HOSTNAME : Sets the hostname of the machine
  -n : NAMESERVER : Nameserver or Nameservers to be added to the /etc/resolve.conf
  -p : Product: app, db or base. This will determine how the partitioning is done.
  -t : Type: This should be phys, vm or aws (AWS is not implimented yet). If selecting vm or aws this will also generate a packer job to deploy the vm/instance
      *** ONLY ONE NAMESERVER IS NECESSARY. The others will be installed by Ansible.***
 
EOF
}

# Set the timezone for each environment.
function set_timezone {
    est5edt='EST5EDT'
    central='US\/Eastern'
    gmt_plus_8='Etc\/GMT\+8'
  }
# Parse Options
while getopts e:i:s:g:m:n:p:t: opts; do

	case $opts in
		e)
			ethernet=$OPTARG
		;;
		i)
			ipaddr=$OPTARG
		;;
		s)
			subnetmask=$OPTARG
		;;
		g)
			gateway=$OPTARG
		;;
		m)
			hostname=$OPTARG
		;;
		n)
			nameserver=$OPTARG
		;;
    	p)
			product=$OPTARG
    	;;
    	t)
			tech=$OPTARG
		;;
			?)
			usage
			exit 0
		;;
	esac
done

# Check for NULL Required Variables

   basefile="centos_base"
   ethernet="eth0"
   IPADDR="ipaddr"
   NETMASK="subnetmask"
   GATEWAY="gateway"
   PRODUCT="product"
   Tech="tech"
   if [[ -z $ipaddr ]]||[[ -z $subnetmask ]]||[[ -z $gateway ]]||[[ -z $hostname ]]||[[ -z $nameserver ]]||[[ -z $ethernet ]]||[[ -z $product ]]||[[ -z $tech ]]; then
     usage
     exit
   fi
   basefile="centos_$product"

# Split $nameserver
ns1=`echo $nameserver | awk -F ',' {'print $1'}`
ns2=`echo $nameserver | awk -F ',' {'print $2'}`

# Update $hostname.cnf

# Create new Kickstart File
echo '#CentOS x86_64 Kickstart File#' > /opt/ks/ks-config/$hostname.cnf
cat $basefile >> /opt/ks/ks-config/$hostname.cnf

# Find and Replace ETHERNET
sed -i "s/ETHERNET/$ethernet/g" /opt/ks/ks-config/$hostname.cnf

# Find and Replace IPADDR
sed -i "s/IPADDR/$ipaddr/g" /opt/ks/ks-config/$hostname.cnf

# Find and Replace SUBNETMASK
sed -i "s/SUBNETMASK/$subnetmask/g" /opt/ks/ks-config/$hostname.cnf

# Find and Replace GATEWAY
sed -i "s/GATEWAY/$gateway/g" /opt/ks/ks-config/$hostname.cnf

# Find and Replace HOSTNAME
sed -i "s/HOSTNAME/$hostname/g" /opt/ks/ks-config/$hostname.cnf

# Find and Replace NAME SERVRS
sed -i "s/NS1/$ns1/" /opt/ks/ks-config/$hostname.cnf

# Find and Replace TIMEZONE
sed -i "s/TIMEZONE/$timezone/g" /opt/ks/ks-config/$hostname.cnf

if [ $tech == "phys" ]
	then 
		echo -e "New Kickstart File is located here: /opt/ks/ks-config/$hostname.cnf\n"
		echo -e "Instructions:\n \nBoot machine from the CentOS 6.7 minimal ISO. At the bootloader screen hit the tab key. Then enter in: \n\nks=http://ks.url.com/ks/ks-config/$hostname.cnf ksdevice=$ethernet ip=$ipaddr netmask=$subnetmask gateway=$gateway nameserver=$ns1.\n\nIf this is a VM make sure to run the vmware-tools playbook from ansible."
	elif [ $tech == "vm" ]
		then 
		cat centos_packer.json >> /opt/ks/ks-config/$hostname.json
		echo -e "Generating packer job for $hostname...\n"
		echo -e "ESX Host Options:\n some.esx.server1: xxx.xxx.xxx.xxx \n some.esx.server2: xxx.xxx.xxx.xxx\n"
		echo -e "Enter the ESX IP address followed by [Enter]:"
		read esx 
		# Find and replace HOSTNAME in the packer json file
		sed -i "s/HOSTNAME/$hostname/g" /opt/ks/ks-config/$hostname.json
		# Find and replace ESX in the packer json file
		sed -i "s/ESX/$esx/g" /opt/ks/ks-config/$hostname.json
		echo -e "Enter the disk size in MB and press [Enter]:"
		read disk
		# Find and replace DISK in the packer json file
		sed -i "s/DISK/$disk/g" /opt/ks/ks-config/$hostname.json
		echo -e "Enter the datastore for the vmdk files followed by [Enter]:"
		read datastore
		# Find and replace DATASTORE in the packer json file
		sed -i "s/DATASTORE/$datastore/g" /opt/ks/ks-config/$hostname.json
		echo -e "Starting packer job to deploy $hostname to $esx on $datastore..."
		./packer build /opt/ks/ks-config/$hostname.json
		echo -e "Packer Build complete. You will need to power on your VM inside of the vSphere console."
		exit 
	elif [ $tech == "aws" ]
		then
		echo -e "Not implemented yet"
	fi
