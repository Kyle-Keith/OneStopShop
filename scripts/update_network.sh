#!/bin/bash

dashmachine_config="/opt/DashMachine/config.ini"

# Function to detect the first three octets of the primary non-loopback, non-docker IP address
get_primary_ip_octets() {
    # Try to get IP address with `ip`
    if command -v ip &> /dev/null; then
        ip_addr=$(ip -4 -o addr show up primary scope global | grep -v -E "docker|virbr0" | awk '{print $4}' | cut -d/ -f1)
    # Fall back to `ifconfig` if `ip` isn't available
    elif command -v ifconfig &> /dev/null; then
        ip_addr=$(ifconfig | grep -A1 -v -E "docker|lo" | grep -w "inet" | awk '{print $2}' | head -1)
    else
        echo "Neither 'ip' nor 'ifconfig' commands are available. Unable to detect IP address."
        return 1
    fi

    # Extract the first three octets
    first_three_octets=$(echo "$ip_addr" | cut -d. -f1-3)
    echo "$first_three_octets"
}


# Fetch the first three octets of the primary IP address
primary_octets=$(get_primary_ip_octets)
if [ -z "$primary_octets" ]; then
    echo "Unable to determine the primary IP address."
    exit 1
fi

# Fetch the current octets
URL_LINE=$(grep -m 1 -E 'url = [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$dashmachine_config")

if [ -n "$URL_LINE" ]; then
    # Extract the IP address from the URL line
    IP=$(echo "$URL_LINE" | grep -oP '\d+\.\d+\.\d+\.\d+')

    if [ -n "$IP" ]; then
        # Extract the first three octets
        CURRENT_THREE_OCTETS=$(echo "$IP" | awk -F. '{print $1 "." $2 "." $3}')
    fi
fi

# Declare variables for modifying files
current_octet="${CURRENT_THREE_OCTETS}"  # Adjust this to the actual value if different
new_octet="${primary_octets}" 


# Log file to record errors or skipped files
declare -A logs
logs[download_log]="download_errors.log"


# Check if current and new octets are different
if [ "$current_octet" != "$new_octet" ]; then

    if [ -f "$dashmachine_config" ]; then
        echo "Processing file: $dashmachine_config"
        # Replace all occurrences of current_octet with new_octet in the file
        sed -i -E "s/${current_octet}/${new_octet}/g" "$dashmachine_config"
        docker 
        echo "Updated IP addresses in $dashmachine_config"
    else
        echo "File not found: $dashmachine_config. Exiting."
        exit 1
    fi
else
    echo "Current octet is the same as the new octet. No replacement needed."
fi
