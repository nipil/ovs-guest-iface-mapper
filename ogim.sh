#!/usr/bin/env bash

IP=/sbin/ip
VIRSH=/usr/bin/virsh
OVSCTL=/usr/bin/ovs-vsctl

declare -a interfaces
declare -A mac_interface
declare -a guests
declare -A mac_guests

function get_ovs_interfaces() {
	${OVSCTL} list interface | grep ^name|awk -F \" '{ print $2 }'
}

function get_ovs_interface_mac() {
	local __interface=${1}
	${OVSCTL} get interface ${__interface} external_ids | sed -e 's/,/\n/g' | grep attached-mac | awk -F \" '{ print $2 }'
}

function get_virsh_guests() {
	${VIRSH} list --all --name|grep -v '^$'|sort
}

function get_guest_mac_list() {
	local __guest=${1}
	${VIRSH} dumpxml ${__guest} | xmllint --xpath '//interface/mac' - | sed -e 's#/>#/>\n#g' | awk -F \" '{ print $2}'
}

function get_guest_mac_slot() {
	local __guest=${1}
	local __mac=${2}
	${VIRSH} dumpxml ${__guest} | xmllint --xpath '//interface/mac[@address="'"${__mac}"'"]/../address/@slot' -  | awk -F \" '{ print $2 }'
}

# check for permissions
[[ ${UID} -eq 0 ]] || { echo "Should be run as root/sudo" >&2 ; exit 1 ; }

# build list of available interfaces
interfaces=$(get_ovs_interfaces)

# build list of mac address from available OVS interfaces
for interface in ${interfaces[@]}
do
	mac=$(get_ovs_interface_mac ${interface})
	[[ -n "${mac}" ]] || continue
	mac_interface[$mac]="${interface}"
done

# build list of libvirt guests
guests=$(get_virsh_guests)

# fetch mac interface of guests and associated interface slot number
for guest in ${guests[@]}
do
	macs=$(get_guest_mac_list ${guest})
	for mac in ${macs[@]}
	do 
		slot=$(get_guest_mac_slot ${guest} ${mac})
		mac_guests[$mac]="$guest\t$(echo $(($slot)))"
	done
done

# display association
{
	echo -e "HOST_IF\tGUEST\tGUEST_IF" ;
	for mac in "${!mac_interface[@]}"
	do
		echo -e "${mac_interface[$mac]}\t${mac_guests[$mac]}"
	done ;
} | column -t
