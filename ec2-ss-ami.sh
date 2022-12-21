#!/bin/bash

set -ue

TICKET=
echo "TICKET NUMBER?"
read TICKET

Region=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed -e 's/.$//')
InstanceId=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
MyInstance=$(hostname)
Target_Date=$(date "+%Y-%m-%dT%H:%M" -u -d '-1 hours')
Delete_Date=$(date "+%Y-%m-%dT%H:%M" -u -d '-1 day')
Now_Date=$(date "+%Y-%m-%dT%H:%M" -u)
Tag_Date=$(date "+%Y-%m-%d-%H-%M")

export AWS_DEFAULT_REGION=${Region}

## 対象インスタンスのボリュームIDを取得
EC2_VolumeId=$( \
  aws ec2 describe-instances \
    --instance-id ${InstanceId} \
    --query 'Reservations[].Instances[].BlockDeviceMappings[].Ebs[].VolumeId' \
    --output text )
## 配列へ格納
EC2_VolumeIds=(`echo $EC2_VolumeId`)

snapshot() {
  ## スナップショットの作成
  Snapshot=$(aws ec2 describe-snapshots \
    --filters "Values=$InstanceId" \
    --query "Snapshots[?(StartTime>='$Target_Date') && (StartTime<='$Now_Date')].[SnapshotId,StartTime]" \
    --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value='$HOST_AND_DATE'},{Key=TICKET,Value='$TICKET'}]' 
}

ami() {
  HOST_AND_DATE="$(hostname)_$(date '+%Y%m%d')"
  aws ec2 create-image \
      --instance-id $(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
      --name ${HOST_AND_DATE} \
      --no-reboot \
      --tag-specifications 'ResourceType=image,Tags=[{Key=Name,Value='$HOST_AND_DATE'},{Key=TICKET,Value='$TICKET'}]' \
      'ResourceType=snapshot,Tags=[{Key=Name,Value='$HOST_AND_DATE'},{Key=TICKET,Value='$TICKET'}]'
}

case "$1" in
  --ss)
    snapshot
    ;;
  --ami)
    ami
    ;;
  *)
    echo "Error: Invalid option"
    echo "Usage: $0 [--ss|--ami]"
    exit 1
    ;;
esac
