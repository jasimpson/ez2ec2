# Easy to EC2 (ez2ec2)

ez2ec2 is a collection of scripts for creating cheap ec2 spot instances easily and working with them.

## Note
**Alternatives**
> This script was written for the unique use case of easily creating a single Ubuntu spot instance on the cheapest availability zone on EC2 and also as a personal exercise in *bashing*. For other use cases, please use the highly extensible and actively developed AWS SDK [Boto](http://aws.amazon.com/sdk-for-python/).

**Credentials**
> This script uses `aws configure` to manage your aws credentials as detailed [here](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html) and does not ask or use for them directly. Always read the code thoroughly before randomly executing scripts off the internet.

**SSH private keys**
> This script can run from any folder, but creates a new SSH key pair in your home folder.


## Prerequisites

1. Create a new IAM user for ez2ec2 and get access and secret keys. You do not have to create a new user if you would like to use an existing IAM user. See [here](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-set-up.html) for instructions on how to do this. Download the `credentials.csv` file and keep it secure. You will need the access key and secret key later to configure `aws`.
    - Log in to your AWS account: https://aws.amazon.com/
    - Open your IAM console at: https://console.aws.amazon.com/iam
    - From the navigation menu, click ***Users***
    - Click button for ***Create New Users***

2. Allow the IAM user access to EC2 Role.
    - On your AWS web console, click on the newly created user name
    - Scroll down to ***Permissions***
    -  Click ***Attach Policy***
    - Search, select, and attach the ***AmazonEC2FullAccess*** policy

2. Install `aws cli` if you do not have it already. See more details [here](http://docs.aws.amazon.com/cli/latest/userguide/installing.html).
    `pip install awscli`


## Instructions

Once you have an IAM user created and have their access key and secret access key, given the IAM user EC2 priviledges, and installed aws cli, to create a new EC2 instance:

 1. Set spot instance settings (at the top of the ez2ec2.sh script)
    ```
    # Spot instance settings
    SPOT_PRICE=0.071
    IMAGE_ID=ami-9a562df2
    INSTANCE_TYPE=m3.medium
    VOLUME_SIZE=16
    ```
    - Spot Price: Maximum spot price bid
        - Max bid of $0.071/hr
    - Image ID: AMI ID of instance to use
        - Ubuntu Server 14.04 LTS (HVM), SSD Volume Type - ami-9a562df2
    - Instance Type: HW type from [here](http://aws.amazon.com/ec2/instance-types/)
        - Intel Xeon E5-2670, 1 vCPU, 3.75 GiB RAM, 4 GB SSD
    - Volume Size: Size in GiB of the EBS volume
        - 16 GiB

 2. Execute the script
    ```bash
    bash ez2ec2.sh
    ```


## What the script does

These are the different steps taken by the script

 1. Check if `aws cli` is installed
 2. Check if IAM credentials are already configured (or configure)
 3. Check if key pair already exists (or create)
 4. Check if key pair .pem file exists in home folder
 5. Check if security group exists (or create)
 6. Find cheapest spot instance availability zone
     1. Get pricing and subnet id for us-east-1a
     2. Get pricing and subnet id for us-east-1b
     3. Get pricing and subnet id for us-east-1d
     4. Get pricing and subnet id for us-east-1e
     5. Make sure cheapest option is less than limit set
 7. Allow SSH in security group from current IP address
 8. Request spot instance
 9. Poll to check if instance is ready to use
 10. Get and display instance details to connect


## Expected Output

Sample initial output should look like

```ini
jim$ bash ez2ec2.sh
Checking if AWS CLI is installed
Using AWS CLI found at /Users/jim/anaconda/bin/aws

Checking aws iam credentials for ez2ec2usr
Using aws iam credentials for ez2ec2usr

Checking key pairs for ez2ec2key
Using existing key pair ez2ec2key

Checking home folder for ez2ec2key.pem
Using key pair file /Users/jim/ez2ec2key.pem

Checking security groups for ez2ec2grp
Using existing security group ez2ec2grp

Checking cheapest spot instance availability zone
Cheapest spot instance is in us-east-1d

Cheapest spot instance has price 0.008100
Cheapest spot instance is in subet subnet-b2854c99

Allowing SSH access from current IP address [hidden]

Creating spot request
Created spot request successfully

Spot request id is [hidden]

Polling to check if request has been fulfilled
This could take around 5 mins...

Use ctrl-c to stop polling and check aws console
Polling will automatically timeout in 10 mins
.
.
.
.
.
.
.

Instance id is [hidden]

Request has been fulfilled
Waiting to complete status checks
.
.
.
.
.
.
.

Instance has been initialized
Instance is ready to use

Connect to the instance using:
ssh -i ~/ez2ec2key.pem ubuntu@54.152.170.[hidden]

jim$
```
