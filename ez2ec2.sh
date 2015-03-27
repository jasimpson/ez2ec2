#!/bin/sh

# Script to easily create cheapest Amazon AWS EC2 spot instance

#################################################
# EZ2EC2 settings                               #

# Spot instance settings
SPOT_PRICE=0.071
IMAGE_ID=ami-9a562df2
INSTANCE_TYPE=m3.medium
VOLUME_SIZE=8

# AWS settings
IAMNAME=ez2ec2usr
KEYNAME=ez2ec2key
GRPNAME=ez2ec2grp

# User settings
MYEXTIP="`curl -s http://checkip.amazonaws.com`"
MYEXTIP="$MYEXTIP/32"

#################################################


#################################################
# Check prerequisites and environment settings  #

# Check if aws cli is installed
echo "Checking if AWS CLI is installed"
AWS_CLI=`which aws`
if [ $? -eq 0 ]; then
    # aws cli is installed
    echo "Using AWS CLI found at $AWS_CLI"
else
    # aws cli is not installed
    echo "AWS CLI not found. Do _pip install awscli_ and try again"
    exit 1
fi

echo

# Check if IAM credentials are already configured
echo "Checking aws iam credentials for $IAMNAME"
aws ec2 describe-instances --profile $IAMNAME > /dev/null 2> /dev/null
if [ $? -eq 0 ]; then
    # aws is configured; move on
    echo "Using aws iam credentials for $IAMNAME"
else
    # aws is not configured; ask for IAM credentials to configure aws cli
    echo "Credentials not configured."
    echo "Required AWS Access Key ID: from credentials.csv"
    echo "Required AWS Secret Access Key: from credentials.csv"
    echo "Default region name: us-east-1"
    echo "Default output format: json"
    while true; do
        read -p "Configure aws using your credentials? (y/n): " yn
        case $yn in
            [Yy]* ) aws configure --profile $IAMNAME; break;;
            [Nn]* ) echo "Try again after creating IAM user"; exit 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

echo

# Check if key pair already exists
echo "Checking key pairs for $KEYNAME"
aws ec2 describe-key-pairs \
--profile $IAMNAME \
--key-name $KEYNAME > /dev/null 2> /dev/null
if [ $? -eq 0 ]; then
    # key pair exists, move on
    echo "Using existing key pair $KEYNAME"
else
    # key pair does not exist, create new key pair
    echo "Create SSH key pair"
    # Create SSH key pair to access EC2
    aws ec2 create-key-pair \
    --profile $IAMNAME \
    --key-name $KEYNAME \
    --query 'KeyMaterial' \
    --output text > ./${KEYNAME}.pem \
    && chmod 600 ./${KEYNAME}.pem \
    && mv ./${KEYNAME}.pem ${HOME}/${KEYNAME}.pem \
    && export keypair=./${KEYNAME}.pem
    if [ $? -eq 0 ]; then
         echo "Creating SSH key and saving to ${HOME}/${KEYNAME}.pem"
    else
        echo "Key pair could not be created"
        exit 1
    fi
fi

echo

# Check if key pair .pem file exits in home folder
echo "Checking home folder for ${KEYNAME}.pem"
if [ -e "${HOME}/${KEYNAME}.pem" ];then
    # key pair file is in home folder, move on
    echo "Using key pair file ${HOME}/${KEYNAME}.pem"
else
    # key pair file not found in home folder
    echo "The key pair ${KEYNAME} exits, but ${KEYNAME}.pem not found in home"
    echo "Please download from aws console & copy to home folder and try again"
    exit 1
fi

echo

# Check if security group exists
echo "Checking security groups for $GRPNAME"
aws ec2 describe-security-groups \
--profile $IAMNAME \
--group-names $GRPNAME > /dev/null 2> /dev/null
if [ $? -eq 0 ]; then
    # security group exists, move on
    echo "Using existing security group $GRPNAME"
else
    # create new security group
    aws ec2 create-security-group \
    --profile $IAMNAME \
    --group-name $GRPNAME --description "SSH from specified IP"
    if [ $? -eq 0 ]; then
         echo "Creating new security group $GRPNAME"
    else
        echo "Security group could not be created"
        exit 1
    fi
fi

echo

#################################################


#################################################
# Find cheapest spot instance availability zone #

US_E_1H=$SPOT_PRICE
BEST_AZ="us-east-1x"
current_time=$(date -u +%FT%TZ)

echo "Checking cheapest spot instance availability zone"

# Get subnet for a given AZ as first argument
function get_subnet() {
    # get json for subnet details
    # | get line
    # | remove all spaces
    # | get value in key "SubnetId": ""
    SN_E_1X=$(aws ec2 describe-subnets \
        --profile $IAMNAME \
        --filters "Name=availabilityZone,Values=$1" \
        | grep SubnetId \
        | sed -e 's/^[ \t]*//' \
        | sed 's/"SubnetId": "\(.*\)",/\1/g')
    echo $SN_E_1X
}

# Get subnet for us-east-1a
SN_E_1A=$(get_subnet "us-east-1a")
# Get subnet for us-east-1b
SN_E_1B=$(get_subnet "us-east-1b")
# Get subnet for us-east-1d
SN_E_1D=$(get_subnet "us-east-1d")
# Get subnet for us-east-1e
SN_E_1E=$(get_subnet "us-east-1e")

SN_E_1H=SN_E_1A


# Get pricing for a given AZ as first argument
function get_pricing() {
    # get json for prices
    # | get line
    # | remove all spaces
    # | remove all newlines
    # | get value in key "SpotPriceHistory": ["SpotPrice": ""]"
    US_E_1X=$(aws ec2 describe-spot-price-history \
        --profile $IAMNAME \
        --instance-types $INSTANCE_TYPE \
        --product-description "Linux/UNIX (Amazon VPC)" \
        --availability-zone "$1" \
        --start-time $current_time \
        --end-time $current_time \
        | grep SpotPrice \
        | sed -e 's/^[ \t]*//' \
        | sed -e :a -e '$!N;s/\n//;ta' \
        | sed 's/"SpotPriceHistory": \["SpotPrice": "\(.*\)",/\1/g')
    echo $US_E_1X
}


# Get pricing for us-east-1a
US_E_1A=$(get_pricing "us-east-1a")
if [ $(echo " $US_E_1A > $US_E_1H " | bc) -eq 1 ]; then
    BEST_AZ="us-east-1x"
    US_E_1L=$US_E_1H
    SN_E_1L=$SN_E_1H
else
    BEST_AZ="us-east-1a"
    US_E_1L=$US_E_1A
    SN_E_1L=$SN_E_1A
fi

# Get pricing for us-east-1b
US_E_1B=$(get_pricing "us-east-1b")
if [ $(echo " $US_E_1B > $US_E_1A " | bc) -eq 1 ]; then
    BEST_AZ="us-east-1a"
    US_E_1L=$US_E_1A
    SN_E_1L=$SN_E_1A
else
    BEST_AZ="us-east-1b"
    US_E_1L=$US_E_1B
    SN_E_1L=$SN_E_1B
fi

# Get pricing for us-east-1d
US_E_1D=$(get_pricing "us-east-1d")
if [ $(echo " $US_E_1D > $US_E_1B " | bc) -eq 1 ]; then
    BEST_AZ="us-east-1b"
    US_E_1L=$US_E_1B
    SN_E_1L=$SN_E_1B
else
    BEST_AZ="us-east-1d"
    US_E_1L=$US_E_1D
    SN_E_1L=$SN_E_1D
fi

# Get pricing for us-east-1e
US_E_1E=$(get_pricing "us-east-1e")
if [ $(echo " $US_E_1E > $US_E_1D " | bc) -eq 1 ]; then
    BEST_AZ="us-east-1d"
    US_E_1L=$US_E_1D
    SN_E_1L=$SN_E_1D
else
    BEST_AZ="us-east-1e"
    US_E_1L=$US_E_1E
    SN_E_1L=$SN_E_1E
fi

# Make sure cheapest option is less than limit set
if [ $(echo " $US_E_1L > $US_E_1H " | bc) -eq 1 ]; then
    BEST_AZ="us-east-1x"
    US_E_1L=$US_E_1H
    SN_E_1L=$SN_E_1H
fi

# Continue if pricing less than limit is available
if [ "$BEST_AZ" = "us-east-1x" ]; then
    echo "There are no spot instances cheaper than limit specified"
    echo "Change price limit and try again"
    exit 1
else
    echo "Cheapest spot instance is in $BEST_AZ"
fi

echo
echo "Cheapest spot instance has price $US_E_1L"
echo "Cheapest spot instance is in subet $SN_E_1L"

#################################################


#################################################
# Create spot instance request and poll status  #

# Get the Security Group ID for the given Group Name
GRPID=$(aws ec2 describe-security-groups \
    --profile $IAMNAME \
    --filters "Name=group-name,Values=$GRPNAME" \
    | grep GroupId \
    | sed -e 's/^[ \t]*//' \
    | sed 's/"GroupId": "\(.*\)"/\1/g')

echo
# Allow SSH from current IP address
echo "Allowing SSH access from current IP address $MYEXTIP"
aws ec2 authorize-security-group-ingress \
--profile $IAMNAME \
--group-name $GRPNAME \
--protocol tcp --port 22 \
--cidr $MYEXTIP > /dev/null 2> /dev/null

echo
# Request spot instance
echo "Creating spot request"
aws ec2 request-spot-instances \
--profile $IAMNAME \
--spot-price $SPOT_PRICE \
--instance-count 1 \
--type "one-time" \
--launch-specification "{ \
\"ImageId\":\"$IMAGE_ID\", \
\"KeyName\":\"$KEYNAME\", \
\"InstanceType\":\"$INSTANCE_TYPE\", \
\"BlockDeviceMappings\":[ {
\"DeviceName\":\"/dev/sda1\",
\"Ebs\": {
\"VolumeSize\":$VOLUME_SIZE,
\"VolumeType\":\"gp2\" } } ], \
\"SubnetId\":\"$SN_E_1L\", \
\"SecurityGroupIds\":[\"$GRPID\"]}" 1> request.info
if [ $? -eq 0 ]; then
    # spot instance created
    echo "Created spot request successfully"
else
    # error in creating spot instance
    echo "Error in creating spot request; check parameters"
    exit 1
fi

# Get spot instance request (SIR) ID
# get line with "SpotInstanceRequestId" key      \
# | remove all spaces    \
# | get value in "SpotInstanceRequestId" key
SIR_ID=$(grep SpotInstanceRequestId request.info \
    | sed -e 's/^[ \t]*//' \
    | sed 's/"SpotInstanceRequestId": "\(.*\)",/\1/g')

echo
echo "Spot request id is $SIR_ID"

#################################################


#################################################
# Poll to check if instance is ready to use     #

echo
echo "Polling to check if request has been fulfilled"
echo "This could take around 5 mins..."
echo
echo "Use ctrl-c to stop polling and check aws console"
echo "Polling will automatically timeout in 10 mins"

# Wait for instance to be fulfilled
check_length=$(aws ec2 describe-instances \
    --profile $IAMNAME \
    --filters "Name=spot-instance-request-id,Values=$SIR_ID" | wc -l)
timeout=20
while [ "$check_length" -lt 5 ]
do
    # check if there are any instances with the current SIR ID
    check_length=$(aws ec2 describe-instances \
        --profile $IAMNAME \
        --filters "Name=spot-instance-request-id,Values=$SIR_ID" | wc -l)
    # check every 30 seconds
    sleep 30
    # timeout in 10 mins
    timeout=$((timeout - 1))
    echo "."
    if [ "$timeout" -eq 0 ]; then
        echo "Polling timed out; check aws console for status"
        exit 1
    fi
done


# Get instance id (INST_ID)
INST_ID=$(aws ec2 describe-instances \
    --profile $IAMNAME \
    --filters "Name=spot-instance-request-id,Values=$SIR_ID" \
    | grep InstanceId \
    | sed -e 's/^[ \t]*//' \
    | sed 's/"InstanceId": "\(.*\)",/\1/g')

echo
echo "Instance id is $INST_ID"

echo
echo "Request has been fulfilled"
echo "Waiting to complete status checks"


# Wait for status checks to finish
check_state=$(aws ec2 describe-instance-status \
    --profile $IAMNAME \
    --instance-id $INST_ID \
    | grep \"Status\" \
    | tail -n1 \
    | sed -e 's/^[ \t]*//' \
    | sed 's/"Status": "\(.*\)",/\1/g')
timeout=20
while [ $check_state != passed ]
do
    # check if state is passed
    check_state=$(aws ec2 describe-instance-status \
        --profile $IAMNAME \
        --instance-id $INST_ID \
        | grep \"Status\" \
        | tail -n1 \
        | sed -e 's/^[ \t]*//' \
        | sed 's/"Status": "\(.*\)",/\1/g')

    # check every 30 seconds
    sleep 30
    # timeout in 10 mins
    timeout=$((timeout - 1))
    echo "."
    if [ "$timeout" -eq 0 ]; then
        echo "Polling timed out; check aws console for status"
        exit 1
    fi
done

echo
echo "Instance has been initialized"
echo "Instance is ready to use"

#################################################


#################################################
# Get instance details to connect               #

# Save instance details to file
aws ec2 describe-instances \
    --profile $IAMNAME \
    --filters "Name=spot-instance-request-id,Values=$SIR_ID" \
    1> instance.info

# Get instance IP address
I_IP=$(aws ec2 describe-instances \
    --profile $IAMNAME \
    --filters "Name=spot-instance-request-id,Values=$SIR_ID" \
    | grep PublicIpAddress \
    | sed -e 's/^[ \t]*//' \
    | sed 's/"PublicIpAddress": "\(.*\)",/\1/g')

echo
echo "Connect to the instance using:"
echo "ssh -i ~/${KEYNAME}.pem ubuntu@$I_IP"
echo

#################################################
