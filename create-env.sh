#!/bin/bash
#COLORS
MAGENTA='\033[1;35m'
NONE='\033[0m'
#VARIABLES
PORTS_TO_ENABLE=( 22 4000 80 )
CIDR="0.0.0.0/0"
PROTOCOL="tcp"
AVAILABILITY_ZONE1="us-west-2b"
BUCKET_REGION="us-east-1"
PERMISSIONS="public-read"
AVAILABILITY_ZONE2="us-west-2a"
clear
echo "*********************************************************************"
echo -e "${MAGENTA}This script performs all the MP1 requirements. "
echo -e "Script written by Pablo Jusue Fernandez for the ITMO 544 class at the IIT"
echo -e "E-mail: pjusue@hawk.iit.edu ${NONE}"
echo "*********************************************************************"


echo "Are you going to create a new security group(Y/N)?"
read OPTION
OPTION=$(echo $OPTION|tr '[:lower:]' '[:upper:]')
if	[ "$OPTION" == "Y" ]
then
	echo "Introduce your security group name"
	read NAME
	echo "Creating a new security group..."
	SECURITY_GROUP_ID=$(aws ec2 create-security-group --description "This is for ITMO 544" --group-name $NAME)
	for PORT in "${PORTS_TO_ENABLE[@]}"
	do
	echo -e "${MAGENTA}Port ${PORT} opened ${NONE}"
	aws ec2 authorize-security-group-ingress --group-name $NAME --protocol $PROTOCOL --port $PORT --cidr $CIDR
	done
elif	[ "$OPTION" == "N" ]
then
	echo "Introduce your security group name"
	read NAME
	SECURITY_GROUP_ID=$(aws ec2 describe-security-groups|grep $NAME|cut -f2 -d'-'|awk -F ${NAME} '{print $1}')
	SECURITY_GROUP_ID=sg-$SECURITY_GROUP_ID
	for PORT in "${PORTS_TO_ENABLE[@]}"
	do
	aws ec2 authorize-security-group-ingress --group-name $NAME --protocol $PROTOCOL --port $PORT --cidr $CIDR 2>>/dev/null 1>>/dev/null
	done
fi
echo "Are you going to create a new key (Y/N)?"
read OPTION
OPTION=$(echo $OPTION |tr '[:lower:]' '[:upper:]')
if	[ "$OPTION" == "N" ]
then
	echo "Introduce your old key file name"
	read KEY
elif	[ "$OPTION" == "Y" ];
then
	echo "Introduce your new key file name "
	read KEY
	echo "Creating the key..."
	aws ec2 create-key-pair --key-name $KEY --query 'KeyMaterial' --output text >$KEY.priv
	echo -e "${MAGENTA} Key created succesfully ${NONE}"
	chmod 400 $KEY.priv
fi
echo "Introduce the number of instances"
read COUNT
INSTANCES_IDS=$(aws ec2 run-instances --image-id $1  --count $COUNT --instance-type t2.micro --key-name $KEY  --security-groups $NAME  --placement "AvailabilityZone=us-west-2b" --user-data file://create-app.sh |grep -i instances|awk '{print $7}')
echo -e "${MAGENTA} The IDs od the instances created are: $INSTANCES_IDS ${NONE}"
echo "Waiting to the instance to initialize..."
aws ec2 wait instance-status-ok --instance-id $INSTANCES_IDS
echo "Introduce the load balancer name"
read LOAD_BALANCER_NAME
aws elb create-load-balancer --load-balancer-name $LOAD_BALANCER_NAME --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" "Protocol=HTTP,LoadBalancerPort=4000,InstanceProtocol=HTTP,InstancePort=4000" --availability-zones $AVAILABILITY_ZONE1  --security-groups $SECURITY_GROUP_ID
aws elb register-instances-with-load-balancer --load-balancer-name $LOAD_BALANCER_NAME --instances  $INSTANCES_IDS
aws elb create-lb-cookie-stickiness-policy --load-balancer-name $LOAD_BALANCER_NAME --policy-name stickiness-policy
echo -e "${MAGENTA} Load Balancer $LOAD_BALANCER_NAME created and stickiness-policy attached ${NONE}"
for INSTANCE in $INSTANCES_IDS
do
VOLUME_ID=$(aws ec2 create-volume --size 10  --availability-zone $AVAILABILITY_ZONE1)
VOLUME_ID=$(echo $VOLUME_ID|awk '{print $6}')
echo -e "Waiting for the ${VOLUME_ID}"
aws ec2 wait volume-available --volume-id $VOLUME_ID
aws ec2 attach-volume --volume-id $VOLUME_ID --instance-id $INSTANCE --device /dev/sdf
echo -e "${MAGENTA} Volumen ${VOLUME_ID} attached to the instance ${INSTANCE} ${NONE}"
done
wget http://cs.iit.edu/~lee/cs115/images/iitlogo.jpg
cp iitlogo.jpg image.jpg
rm iitlogo.jpg
echo "Introduce the bucket name"
read BUCKET_NAME
aws s3api create-bucket --bucket $BUCKET_NAME --region $BUCKET_REGION
aws s3 cp image.jpg s3://$BUCKET_NAME/images --acl $PERMISSIONS
