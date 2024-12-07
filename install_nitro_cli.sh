#!/bin/bash

# Function for error handling
handle_error() {
    echo -e "Error: $1"
    exit 1
}

# Step 1: Install aws-nitro-enclaves-cli
echo -e "INSTALLING AWS-NITRO-ENCLAVES-CLI...\n"
sudo dnf install aws-nitro-enclaves-cli -y || handle_error "Failed to install aws-nitro-enclaves-cli."

# Step 2: Install aws-nitro-enclaves-cli-devel
echo -e "INSTALLING AWS-NITRO-ENCLAVES-CLI-DEVEL..."
sudo dnf install aws-nitro-enclaves-cli-devel -y || handle_error "Failed to install aws-nitro-enclaves-cli-devel."

# Step 3: Add the current user to multiple groups
echo -e "ADDING $USER TO 'NE' AND 'DOCKER' GROUPS...\n"
sudo usermod -aG ne,docker $USER || handle_error "Failed to add $USER to 'ne' and 'docker' groups."

# Step 4: Apply new group memberships without logout/login
echo -e "APPLYING NEW GROUP MEMBERSHIPS..."
newgrp docker <<EONG 
# Step 5: Verify Nitro CLI installation
echo -e "VERIFYING NITRO CLI INSTALLATION...\n"
nitro-cli --version || handle_error "Nitro CLI is not installed or not working correctly."

# Step 6: Stop the Nitro Enclaves Allocator service
echo -e "STOPPING NITRO-ENCLAVES-ALLOCATOR.SERVICE...\n"
sudo systemctl stop nitro-enclaves-allocator.service || handle_error "Failed to stop nitro-enclaves-allocator.service."

sudo systemctl status nitro-enclaves-allocator.service

# Step 7: Configure memory in the allocator.yaml file
ALLOCATOR_YAML="/etc/nitro_enclaves/allocator.yaml"
MEM_KEY="memory_mib"
DEFAULT_MEM=1024
echo -e "CONFIGURING MEMORY ALLOCATION IN \$ALLOCATOR_YAML...\n"
sudo sed -r "s/^(\s*\${MEM_KEY}\s*:\s*).*/\1\${DEFAULT_MEM}/" -i "\${ALLOCATOR_YAML}" || handle_error "Failed to update memory allocation in \$ALLOCATOR_YAML."

# Step 8: Start and enable the Nitro Enclaves Allocator service
echo -e "STARTING AND ENABLING NITRO-ENCLAVES-ALLOCATOR.SERVICE...\n"
sudo systemctl start nitro-enclaves-allocator.service || handle_error "Failed to start nitro-enclaves-allocator.service."
sudo systemctl enable nitro-enclaves-allocator.service || handle_error "Failed to enable nitro-enclaves-allocator.service."

# Step 9: Enable and start Docker service
echo -e "ENABLING AND STARTING DOCKER SERVICE...\n"
sudo systemctl enable --now docker || handle_error "Failed to enable and start Docker service."

echo -e "SCRIPT EXECUTION COMPLETED SUCCESSFULLY. GROUP MEMBERSHIP CHANGES HAVE BEEN APPLIED.\n"
EONG
