#!/bin/bash

set -ue

Region=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed -e 's/.$//')
InstanceId=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
HOST_AND_DATE="$(hostname)_$(date '+%Y%m%d')"

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
TICKET=
echo "TICKET NUMBER?"
read TICKET
Snapshot=$(aws ec2 describe-snapshots \
  --filters "Name=tag:Auto_SS_TG,Values=$InstanceId" \
  --region ap-northeast-1 \
  --output text | head -n1)

if [ -z "$Snapshot" ]; then
    for VolumeId in ${EC2_VolumeIds[@]}; do
      aws ec2 create-snapshot --volume-id ${VolumeId} --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value='$HOST_AND_DATE'},{Key=TICKET,Value='$TICKET'}]'  --description "created by $0" |grep "SnapshotId"
    done
fi
}

del_snapshot() {
    SNAPID=
    echo "snapshotID?"
    read SNAPID
    aws ec2 delete-snapshot --snapshot-id $SNAPID && echo "delete complete"
}

ami() {
TICKET=
echo "TICKET NUMBER?"
read TICKET
aws ec2 create-image \
      --instance-id $(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
      --name ${HOST_AND_DATE} \
      --no-reboot \
      --tag-specifications 'ResourceType=image,Tags=[{Key=Name,Value='$HOST_AND_DATE'},{Key=TICKET,Value='$TICKET'}]' \
     'ResourceType=snapshot,Tags=[{Key=Name,Value='$HOST_AND_DATE'},{Key=TICKET,Value='$TICKET'}]'  \
      --description "created by $0"
}

case "$1" in
  --ss)
    snapshot
    ;;
  --ami)
    ami
    ;;
  --delss)
    del_snapshot
    ;;
  *)
    echo "Error: Invalid option"
    echo "Usage: $0 [--ss|--ami|--delss]"
    exit 1
    ;;
esac
