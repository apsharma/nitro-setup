### Create EC2 Instance using Linux AMI
`aws ec2 run-instances --image-id ami-0614680123427b75e --count 1 --instance-type m5.xlarge --key-name MyKeyPair --enclave-options 'Enabled=true' --query "Instances[0].InstanceId" --output text`

### Install nitro cli
Run the script install_nitro_cli.sh

### Build enclave image file
Run the script build_sample_eif.sh

### Get enclave Id
ENCLAVE_ID=$(nitro-cli describe-enclaves | jq -r .[].EnclaveID)

### Run enclave in debug mode
nitro-cli run-enclave --cpu-count 2 --memory 512 --enclave-cid 16 --eif-path hello.eif --debug-mode

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
