### Create EC2 Instance using Linux AMI
`aws ec2 run-instances --image-id ami-0614680123427b75e --count 1 --instance-type m5.xlarge --key-name MyKeyPair --enclave-options 'Enabled=true' --query "Instances[0].InstanceId" --output text`

### Install nitro cli
Run the script install_nitro_cli.sh

### Build enclave image file
Run the script build_sample_eif.sh

### Run enclave in debug mode
nitro-cli run-enclave --cpu-count 2 --memory 512 --enclave-cid 16 --eif-path hello.eif --debug-mode

### Get enclave Id
ENCLAVE_ID=$(nitro-cli describe-enclaves | jq -r .[].EnclaveID)

### Validate enclave is running
nitro-cli describe-enclaves

### View read-only console
nitro-cli console --enclave-id $ENCLAVE_ID

### Terminate enclave
nitro-cli terminate-enclave --enclave-id $ENCLAVE_ID

### Terminate EC2 instance

`aws ec2 terminate-instances --instance-ids <instance-id>`

##### Get instance Ids, if you have multiple instances
`aws ec2 describe-instances --filters Name=instance-state-name,Values=running --query "Reservations[*].Instances[*].[InstanceId,InstanceType,PublicIpAddress]" --output table`
##### Get instance id with filters
`aws ec2 describe-instances --filters Name=instance-state-name,Values=running --query "Reservations[*].Instances[*].InstanceId" --output text`

## Part 1: Setting up a EC2 Instance role to have permissions to CreateKey from ec2 instance.
-- Setup a trust policy document that defines what AWS services can assume the role.
`aws iam create-role --role-name MyEC2Role --assume-role-policy-document file://trust-policy.json`

-- Create a `trust-policy.json` document on the ec2 instance:
`{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}`

-- Create a policy document `kms-permissions.json` that grants permissions to create keys (and a few other permissions)
`{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kms:CreateAlias",
                "kms:CreateKey",
                "kms:DeleteAlias",
                "kms:Describe*",
                "kms:GenerateRandom",
                "kms:Get*",
                "kms:List*",
                "kms:TagResource",
                "kms:UntagResource",
                "iam:ListGroups",
                "iam:ListRoles",
                "iam:ListUsers"
            ],
            "Resource": "*"
        }
    ]
}`

-- Attach the `kms-permissions` to `MyEC2Role` : `aws iam put-role-policy --role-name MyKMSRole --policy-name CreateKMSKeyPolicy --policy-document file://kms-policy.json`.

-- TODO: there a few more steps here. To be filled

-- 


## Part 2: Creating an Enclave and Decrypting a message

- Git clone the repo on the ec2 instance (you might have to install git)
`git clone https://github.com/aws/aws-nitro-enclaves-sdk-c/tree/main`

- Build Container for kmstool-instance and kmstool-enclave. 
`docker build --target kmstool-instance -t kmstool-instance -f containers/Dockerfile.al2 .` 
`docker build --target kmstool-enclave -t kmstool-enclave -f containers/Dockerfile.al2 .`

- Build EIF using the kmstool-enclave image above
`nitro-cli build-enclave --docker-uri kmstool-enclave --output-file kmstool.eif`

- Copy the PCR0 register value from the output above.

- Create a KMS Customer Managed Key that allows enclave to only decrypt messages.
-- Debug Mode: `test-enclave-policy.json`
`{
  "Version" : "2012-10-17",
  "Id" : "key-default-1",
  "Statement" : [
  {
    "Sid" : "Enable decrypt from enclave",
    "Effect" : "Allow",
    "Principal" : { "AWS" : INSTANCE_ROLE_ARN },
    "Action" : "kms:Decrypt",
    "Resource" : "*",
    "Condition": {
        "StringEqualsIgnoreCase": {
          "kms:RecipientAttestation:ImageSha384": "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        }
    }
  },
  {
    "Sid" : "Enable encrypt from instance",
    "Effect" : "Allow",
    "Principal" : { "AWS" : INSTANCE_ROLE_ARN },
    "Action" : "kms:Encrypt",
    "Resource" : "*"
  },
  {
    "Sid": "Allow access for Key Administrators",
    "Effect": "Allow",
    "Principal": {"AWS": KMS_ADMINISTRATOR_ROLE },
    "Action": [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ],
    "Resource": "*"
  }
 ]
}`


-- Production Mode: `enclave-policy.json`

{
  "Version" : "2012-10-17",
  "Id" : "key-default-1",
  "Statement" : [
  {
    "Sid" : "Enable decrypt from enclave",
    "Effect" : "Allow",
    "Principal" : { "AWS" : INSTANCE_ROLE_ARN },
    "Action" : "kms:Decrypt",
    "Resource" : "*",
    "Condition": {
        "StringEqualsIgnoreCase": {
          "kms:RecipientAttestation:ImageSha384": PCR0_VALUE_FROM_EIF_BUILD
        }
    }
  },
  {
    "Sid" : "Enable encrypt from instance",
    "Effect" : "Allow",
    "Principal" : { "AWS" : INSTANCE_ROLE_ARN },
    "Action" : "kms:Encrypt",
    "Resource" : "*"
  },
  {
    "Sid": "Allow access for Key Administrators",
    "Effect": "Allow",
    "Principal": {"AWS": KMS_ADMINISTRATOR_ROLE },
    "Action": [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ],
    "Resource": "*"
  }
 ]
}

- Create a KMS key
Decide what mode you want to run the enclave in and pick the step accordingly.
-- Debug mode
`KMS_KEY_ARN=$(aws kms create-key --description "Nitro Enclaves Test Key" --policy file://test-enclave-policy.json --query KeyMetadata.Arn --output text)`
`echo $KMS_KEY_ARN`
--Production mode
`KMS_KEY_ARN=$(aws kms create-key --description "Nitro Enclaves Production Key" --policy file://enclave-policy.json --query KeyMetadata.Arn --output text)`

- Encrypt some test data
`MESSAGE="Hello, KMS\!"`
`CIPHERTEXT=$(aws kms encrypt --key-id "$KMS_KEY_ARN" --plaintext "$MESSAGE" --query CiphertextBlob --output text)`
`echo $CIPHERTEXT`

### Part 2a: Debug Mode

### Part 2b: Production Mode

- Setup a new (2nd) terminal session
`nitro-cli run-enclave --eif-path kmstool.eif --memory 1024 --cpu-count 2 --debug-mode`
`ENCLAVE_ID=$(nitro-cli describe-enclaves | jq -r .[0].EnclaveID)`

- Connect to the enclave's terminal
`nitro-cli console --enclave-id $ENCLAVE_ID`

- Setup a new (3rd) terminal session


## Noteworthy Items

- vsock proxy is installed as part of `nitro-enclaves-cli`.

## How to Encrypt and Decrypt Data from a Provider

### 

##### Create Key with a Key policy document
`aws kms create-key --description "Nitro Enclaves Test Key" --policy file://test-enclave-policy.json --query KeyMetadata.Arn --output text`

The key policy can be attached later, too. If skipping the key policy attachment then drop the `--policy` flag above.
`aws kms put-key-policy --key-id <uuid> --policy file://key-policy.json`

##### Attach an Alias to the Key generated above (using the key id)
`aws kms create-alias --alias-name alias/keyFrmConsole --target-key-id <uuid>`

##### Encrypt plaintext.txt using an existing Symmetric key
`aws kms encrypt --key-id <uuid> --plaintext fileb://plaintext.txt --output text --query CiphertextBlob > encrypted.txt`

##### Decrypt encrypted.binary using an existing Symmetric key
`aws kms decrypt --ciphertext-blob fileb://encrypted.binary --output text --query Plaintext | base64 --decode > decrypted.txt`

### With Envelope Encryption
See here for reference: https://docs.aws.amazon.com/kms/latest/developerguide/kms-cryptography.html#enveloping. 

The steps below simulate how a TDP can encrypt and share data to be used within a CCR. (Nitro)


##### Generate a data encryption key (DEK, TDP)
`aws kms generate-data-key --key-id <uuid> --key-spec AES_256 --output json > key.json`

`key.json` contains the following

`{
    "CiphertextBlob": "XXXXX",
    "Plaintext": "XXXX",
    "KeyId": "arn:aws:kms:ap-south-1:111111111111:key/uuid"
}`


##### Encrypt data using DEK (TDP)
- Generate an intialization vector : `iv=$(openssl rand -hex 16) && echo "Random IV: $iv"`
- Save the initialization vector to a file: `echo $iv > iv.txt`
- Encrypt data using the plain text key above: `openssl enc -aes-256-cbc -in plaintext-data.txt -out encrypted-data.enc -K $(jq -r '.Plaintext' key.json | base64 -d | hexdump -e '16/1 "%02x"') -iv $iv`


##### Upload the encrypted data and DEK to S3 (CCR ?)
- Move data to S3: `aws s3 cp encrypted-data.enc s3://<bucket-name>/encrypted-data.enc`
- Move key to S3: `aws s3 cp key.json s3://<bucket-name>/encrypted-key.json`
- Move iv to S3: `aws s3 cp iv.txt s3://<bucket-name>/encrypted-key.json`

These are just illustrative, openssl-specific steps and not required.


##### Download DEK, IV and encrypted data from S3 (CCR ?)
- Run `aws s3 cp` with the params above reversed.


##### Decrypt DEK (CCR)
This is really an optional step for the situation where the encrypted, not the plaintext key, is made available on KMS.

- Use the Encrypted data key to generate the plain text DEK, from the key file downloaded from S3: `aws kms decrypt --ciphertext-blob fileb://<(jq -r '.CiphertextBlob' key.json | base64 -d) --output json > decrypted-key.json`.


##### Use plaintext key to decrypt data (CCR)
- Decrypt data using the plaintext DEK key: `openssl enc -aes-256-cbc -d -in encrypted-data.enc -out decrypted-data.txt -K $(jq -r '.Plaintext' decrypted-key.json | base64 -d | hexdump -e '16/1 "%02x"') -iv $iv`