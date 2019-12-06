#!/bin/sh

ARGS=$(getopt -o a:b:c:d -l "Server_Name:,Openrc_File:,Image_Location:,Downtime_in_Minutes:" -- "$@");
eval set -- "$ARGS";
while true; do
  case "$1" in
    -a|--Server_Name)
      shift;
      if [ -n "$1" ]; then
        Server_Name=$1;
        shift;
      fi
      ;;
    -b|--Openrc_File)
      shift;
      if [ -n "$1" ]; then
        Openrc_File=$1;
        shift;
      fi
      ;;
    -c|--Image_Location)
      shift;
      if [ -n "$1" ]; then
        Image_Location=$1;
        shift;
      fi
      ;;
    -d|--Downtime_in_Minutes)
      shift;
      if [ -n "$1" ]; then
        Downtime_in_Minutes=$1;
        shift;
      fi
      ;;
 --)
      shift;
      break;
      ;;
  esac
done

#Sourcing Credentials
if [[ ! -f "$Openrc_File" ]]; then
  echo "Openrc file required."
  exit 1
else
  source "$Openrc_File"
fi

#Stopping OpenStack Server
openstack server stop $Server_Name

#Waiting for Server Shutdown
sleep 30s

# Snapshot Name
Snapshot_Name="${Server_Name}-$(date "+%Y%m%d-%H:%M")-$(hostname)"

# Snapshot Creation Message
echo "Instance SnapShot creation is Started"
echo $Snapshot_Name
openstack server image create --name $Snapshot_Name $Server_Name
if [[ "$?" != 0 ]]; then
  echo "ERROR: Openstack Image Create  \"${Server_Name}\" \"${Snapshot_Name}\" failed."
  exit 1
else
  echo "SUCCESS: snapshot is created and pending upload in glance."
fi

#Wait till Snapshot Will get Uploaded
sleep $Downtime_in_Minutes

#Checking Snapshot is uploaded to glance
Snapshot_Status=$(openstack image show $Snapshot_Name | awk 'NR == 18 {print $4}')

if [[ "$Snapshot_Status" != "active" ]]; then
  echo "ERROR: Glance Image Upload \"${Server_Name}\" \"${Snapshot_Name}\" failed."
  exit 1
else
  echo "SUCCESS: Glance Image upload is done."
fi

#Downloading SnapShot from glance
Image_UUID=$(openstack image show $Snapshot_Name | awk 'NR == 9 {print $4}')
glance image-download --file $Image_Location/$Snapshot_Name $Image_UUID

if [[ "$?" != 0 ]]; then
  echo "ERROR: Glance Image Download \"${Server_Name}\" \"${Snapshot_Name}\" failed."
  exit 1
else
  echo "SUCCESS: Glance Image Download is done."
fi

#Starting OpenStack Server
openstack server start $Server_Name

if [[ "$?" != 0 ]]; then
  echo "ERROR: Instance Not Started."
  exit 1
else
  echo "SUCCESS: Instance Started."
fi
