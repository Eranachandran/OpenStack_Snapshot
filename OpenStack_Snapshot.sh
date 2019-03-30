#!/bin/sh

ARGS=$(getopt -o a:b:c:d:e -l "Server_Name:,Snapshot_Name:,Openrc_File:,Snapshot_Location:,Downtime_in_Minutes:" -- "$@");
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
    -b|--Snapshot_Name)
      shift;
      if [ -n "$1" ]; then
        Snapshot_Name=$1;
        shift;
      fi
      ;;
    -c|--Openrc_File)
      shift;
      if [ -n "$1" ]; then
        Openrc_File=$1;
        shift;
      fi
      ;;
    -d|--Snapshot_Location)
      shift;
      if [ -n "$1" ]; then
        Snapshot_Location=$1;
        shift;
      fi
      ;;
    -e|--Downtime_in_Minutes)
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
SNAPSHOT_NAME="${Snapshot_Name}-$(date "+%Y%m%d-%H:%M")-$(hostname)-${Server_Name}"

# Snapshot Creation Message
echo "Instance SnapShot creation is Started"
echo $Snapshot_Name
openstack server image create --name $SNAPSHOT_NAME $Server_Name 
if [[ "$?" != 0 ]]; then
  echo "ERROR: Openstack Image Create  \"${Server_Name}\" \"${SNAPSHOT_NAME}\" failed."
  exit 1
else
  echo "SUCCESS: snapshot is created and pending upload in glance."
fi

#Wait till Snapshot Will get Uploaded
sleep $Downtime_in_Minutes

#Checking Snapshot is uploaded to glance
Snapshot_Status=$(openstack image show DevSever_Snapshot_Mar15_2019 | awk 'NR == 18 {print $4}')

if [[ "$Snapshot_Status" != "active" ]]; then
  echo "ERROR: Glance Image Upload \"${Server_Name}\" \"${SNAPSHOT_NAME}\" failed."
  exit 1
else
  echo "SUCCESS: Glance Image Download is Started."
fi

#Downloading SnapShot from glance
Image_UUID=$(openstack image show $SNAPSHOT_NAME | awk 'NR == 9 {print $4}')
glance image-download --file $Snapshot_Location $Image_UUID

if [[ "$?" != 0 ]]; then
  echo "ERROR: Glance Image Download \"${Server_Name}\" \"${SNAPSHOT_NAME}\" failed."
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
