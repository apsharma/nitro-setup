#!/bin/bash

# Function for error handling
handle_error() {
    echo -e "Error: $1 \n"
    exit 1
}

# Step 1: Verify the default application directory exists
default_app_dir="/usr/share/nitro_enclaves/examples/hello"
if [ ! -d "$default_app_dir" ]; then
    handle_error "Default application directory not found: $default_app_dir \n"
fi

# Step 2: Build a Docker image from the sample application
echo -e "Building Docker image from sample application...\n"
docker build "$default_app_dir" -t hello || handle_error "Failed to build Docker image."

# Step 3: Check that the Docker image has been built
echo -e "Checking if Docker image has been built...\n"
docker image ls | grep -q "hello" || handle_error "Docker image 'hello' not found."

# Step 4: Build the enclave file
echo -e "Building enclave file...\n"
nitro-cli build-enclave --docker-uri hello:latest --output-file hello.eif || handle_error "Failed to build enclave file."

echo -e "Script completed successfully.\n"
