#!/bin/bash

# Global variables
debug=1
HOME="$PWD"
DOMAIN="cpt.local"
INSTALL_USER="xadministrator"
PASSWORD="P@ssw0rd!@"
soar_package="splunk_soar-unpriv-6.2.1.305-7c40b403-el7-x86_64.tgz"
install_dir="/opt"
GITLAB_USERNAME="kyle.keith"
GITLAB_URL="https://code.levelup.cce.af.mil/651-cpt/"

# Log files
declare -A logs=(
    [install_info]="${install_dir}/install_info.log"
    [install_status]="${install_dir}/install_status.log"
    [ERROR_LOG]="${install_dir}/errors.log"
    [download_log]="${install_dir}/download.log"
)

# Management ports
declare -A ports=( 
    [dashmachine_port]="5000" 
    [velociraptor_port1]="8005" 
    [velociraptor_port2]="8001"
    [velociraptor_port3]="9000"
    [MM_PORT]="8065" 
    [soar_port]="8445" 
    [squidfunk_port]="8002"
)
# OFFLimit Ports, 8889=soar proxy, 5121=soar HEC, 5122=Soar UFW Mgmt, 8888=WebSocket server

# Github Links
declare -A links=(
  [rita]="https://github.com/activecm/rita.git"
  [dashmachine]="https://github.com/rmountjoy92/DashMachine"
  [velociraptor]="https://github.com/weslambert/velociraptor-docker.git"
  [volatility]="https://github.com/volatilityfoundation/volatility.git"
  [mattermost]="https://github.com/mattermost/docker"
  [splunk_soar]="https://download.splunk.com/products/splunk_soar-unpriv/releases/6.2.1/linux/splunk_soar-unpriv-6.2.1.305-7c40b403-el7-x86_64.tgz"
  [hayabusa]="https://github.com/Yamato-Security/hayabusa.git"
)

# Docker Images
declare -A images=(
    [dashmachine]="rmountjoy/dashmachine:latest"
    [velociraptor]="wlambert/velociraptor"
    [postgres]="postgres:13-alpine"
    [mattermost]="mattermost/mattermost-enterprise-edition:8.1.9"
    [nginx]="nginx":alpine
    [mongo]="mongo:4.2"
    [rita]="quay.io/activecm/rita:latest"
    [centos]="centos:7"
    [squidfunk]="squidfunk/mkdocs-material"
)

# Confluence Gitlab repositories to download
declare -A gitlab=(
    [SOPs]="SOPs"
    [OneStopShop]="One-Stop-Shop"
)
#r2d2-kzW5nZUvbAjFjCC583gY
############################ Suppoorting Functions ####################################

install_supporting_tools() {
    if ! command -v docker >/dev/null 2>&1 || ! docker plugin ls | grep -q "compose"; then
        check_and_install_docker
    fi
    echo "Installing support tools..." 
    echo "Installing development and build tools..."
    if [[ $DISTRO == "ubuntu" || $DISTRO == "debian" ]]; then
        sudo apt update -y
        sudo apt upgrade -y
        sudo apt install -y build-essential autoconf automake libtool wget git default-jdk libssl-dev
        sudo apt install -y python3 python3-pip
    elif [[ $DISTRO == "rhel" || $DISTRO == "centos" || $DISTRO == "ol" ]]; then
        sudo yum update -y
        sudo yum upgrade -y
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y autoconf automake libtool git wget java-1.8.0-openjdk-devel openssl openssl-devel
        sudo yum install -y python3 python3-pip python-pip
        sudo yum install -y firewalld 
        sudo systemctl start firewalld
        sudo systemctl enable firewalld
        sudo yum clean all
        sudo yum update -y
        clear
    else
        echo "Unsupported Linux distribution" >&2
        return 1
    fi
    
    echo "Installing additional programs and libraries..."
    if [[ $DISTRO == "ubuntu" || $DISTRO == "debian" ]]; then
        sudo apt install -y libafflib-dev
        clear
    elif [[ $DISTRO == "rhel" || $DISTRO == "centos" || $DISTRO == "ol" ]]; then
        echo "Enabling EPEL repository for AFFLIB installation..."
        sudo yum install -y epel-release
        echo "Installing AFFLIB from EPEL..."
        sudo yum install -y afflib afflib-devel
        clear
    fi

    # LibEWF
    mkdir -p "${install_dir}/libewf"
    cd "${install_dir}"
    git clone "https://github.com/libyal/libewf.git" 
    cd "${install_dir}/libewf"
    "sudo ./synclibs.sh"
    "sudo ./autogen.sh"
    "sudo ./configure.ac"
    sudo make
    sudo make install 
    
    echo "Development tools and optional libraries installed successfully."
    if cat "${logs[download_log]}" | grep supporting_tools; then
        sed  -E "s/^(supporting_tools: )1/\10/" "$log"
    else
        echo "supporting_tools: 0" >> "${logs[download_log]}"
    fi
}

check_and_install_docker() {
    echo "Checking and installing Docker..."
    if ! command -v docker &> /dev/null; then
        case "$DISTRO" in
            ubuntu|debian)
                echo "Using APT package manager..."
                sudo apt-get update -y
                sudo apt-get install -y docker.io
                sudo curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
                sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
                ;;
            centos|ol)
                echo "Using YUM package manager..."
                sudo yum install -y yum-utils device-mapper-persistent-data lvm2
                sudo yum-config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
                sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                sudo chmod +x /usr/local/bin/docker-compose
                ;;
            ol)
                echo "Using dnf package manager..."
                sudo dnf install -y dnf-utils zip unzip
                sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
                sudo dnf remove -y runc
                sudo dnf install -y docker-ce --nobest --allowerasing
                sudo systemctl enable docker.service
                sudo systemctl start docker.service
                dnf install -y curl
                curl -L https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
                chmod +x /usr/local/bin/docker-compose
                ;;
            *)
                echo "Unsupported Linux distribution" >&2
                return 1
                ;;
        esac
    else
        echo "Docker is already installed."
    fi
}

update_download_status() {
    local check=$1
    local instance=$2
    local log=$3
    local type=${4:-""}

    if [ $debug -eq 0 ]; then
        echo "Debug: update_download_status called with"
        echo "  check: $check"
        echo "  instance: $instance"
        echo "  log: $log"
        echo "  type: $type"
    fi

    if [ -z "$instance" ] || [ -z "$log" ]; then
        echo "Error: Instance or log file not provided."
        return 1
    fi

    if [ -z "$type" ]; then
        type=""
    fi

    if [ "$check" -eq 0 ]; then
        # Check if the instance exists in the log file
        if grep -q "^${instance}_${type}:" "${log}"; then
            # Update status from 1 to 0 if the instance exists
            sed -i -E "s/^(${instance}_${type}: )1/\10/" "${log}"
        else
            # If the instance doesn't exist, set status to 0
            echo "${instance}_${type}: 0" >> "${log}"
        fi
    else
        if grep -q "^${instance}_${type}:" "${log}"; then
            # Update status from 0 to 1 if the instance exists
            sed -i -E "s/^(${instance}_${type}: )0/\11/" "${log}"
        else
            # If the instance doesn't exist or failed, set status to 1
            echo "${instance}_${type}: 1" >> "${log}"
        fi
    fi
    if [ $debug -eq 0 ]; then
        echo "Debug: update_download_status completed"
    fi
    cat "${log}"
}

check_tools() {
    # Initialize variables for each switch
    local instance=""
    local log=""
    local type=""
    local update_log=""
    local port=""
    local opt_check=1
    local port_check=1

    # Reset OPTIND
    OPTIND=1

    # Parse the options
    while getopts ":i:l:t:u:p:" opt; do
        case ${opt} in
            i )
                instance=$OPTARG
                ;;
            l )
                log=$OPTARG
                ;;
            t )
                type=$OPTARG
                ;;
            u )
                update_log=$OPTARG
                ;;
            p )
                port=$OPTARG
                ;;
            \? )
                echo "Invalid option: -$OPTARG" 1>&2
                ;;
            : )
                echo "Invalid option: -$OPTARG requires an argument" 1>&2
                ;;
        esac
    done
    shift $((OPTIND -1))

    if [ $debug -eq 0 ]; then
        echo "Debug: check_tools called with"
        echo "  instance: ${instance:-No value provided}"
        echo "  log: ${log:-No value provided}"
        echo "  type: ${type:-No value provided}"
        echo "  update_log: ${update_log:-No value provided}"
        echo "  port: ${port:-No value provided}"
    fi

    if [ -z "$instance" ] || [ -z "$log" ]; then
        echo "Error: Instance or log file not provided."
        return 1
    fi

    if [ "${type}" = "links" ] || [ "${type}" = "gitlab" ]; then
        # Check if download is located on the local system
        test=$(ls "${install_dir}" | grep "${instance}")
        if [ "${test}" ]; then
            opt_check=0
        fi
    elif [ "${type}" = "images" ]; then
        # Check if image exists on local system
        test=$(docker images | awk '{print $1}' | grep "${instance}")
        if [ "${test}" ]; then
            opt_check=0
        fi
    elif [ "$type" = "container" ]; then
        # Check if container is running
        test=$(docker ps | grep "${instance}")
        if [ "${test}" ]; then
            opt_check=0
        fi
    elif [ "${type}" = "" ]; then
        # Check log file for instance
        test=$(grep "${instance}" "${log}")
        if [ "${test}" ]; then
            opt_check=0
        fi
    else
        echo "Error: Invalid type."
        return 1
    fi

    if [ $debug -eq 0 ]; then
        echo "Debug: opt_check: $opt_check"
    fi

    if [ -n "${port}" ]; then
        if ss -ntpl | grep -q "${port}"; then
            port_check=0
        fi
    fi
    if [ $debug -eq 0 ]; then
        echo "Debug: port_check: $port_check"
    fi
    # Corrected logic for the conditions
    if [ "${opt_check}" -eq 0 ] && { [ -z "$port" ] || [ "${port_check}" -eq 0 ]; }; then
        if [ -n "${update_log}" ]; then
            if [ $debug -eq 0 ]; then
                echo "Debug: Calling update_download_status with"
                echo "  opt_check: ${opt_check}"
                echo "  instance: ${instance}"
                echo "  update_log: ${update_log}"
                echo "  type: ${type}"
            fi
            update_download_status "${opt_check}" "${instance}" "${update_log}" "${type}"
            return 0
        else
            echo "${instance} ${opt_check} should be 0"
            return 0
        fi
    else
        if [ -n "${update_log}" ]; then
            if [ $debug -eq 0 ]; then
                echo "Debug: Calling update_download_status with"
                echo "  opt_check: ${opt_check}"
                echo "  instance: ${instance}"
                echo "  update_log: ${update_log}"
                echo "  type: ${type}"
            fi
            update_download_status "${opt_check}" "${instance}" "${update_log}" "${type}"
            return 1
        else
            echo "${instance} ${opt_check} should be 1"
            return 1
        fi
    fi
}


# Function to check Git installation and clone GitLab repositories
clone_gitlab_projects() {
    # Check if Git is installed
    if ! command -v git &> /dev/null; then
        echo "Git is not installed. Please install Git and try again."
        return 1
    fi

    # Store the credentials in Git's cache for a short duration (1 hour)
    echo "Storing username credentials for 1 hour..."
    git init
    git config --add user.name "${GITLAB_USERNAME}"
    git config --global credential.helper "cache --timeout=3600"

    # Clone each specified repository from the associative array
    cd ${install_dir}

    for repo_key in "${!gitlab[@]}"; do
        local opt_check=1
        local REPO_NAME="${gitlab[$repo_key]}"
        local REPO_URL="${GITLAB_URL}${REPO_NAME}.git"
        echo "Cloning $REPO_URL..."
        if [ -d "${install_dir}/$repo_key" ]; then
            rm -rf "${install_dir}/${name}"
            git clone "$url" "${install_dir}/$repo_key" 2>> "${logs[ERROR_LOG]}"
        else
            git clone "$url" "${install_dir}/$repo_key" 2>> "${logs[ERROR_LOG]}"
        fi
        echo "Use your Access Token as the password"
        if git -c http.sslVerify=false clone "$REPO_URL" 2>> "${logs[ERROR_LOG]}"; then
            check_tools  "$repo_key"  "${logs[download_log]}" "gitlab"
        fi
    done
}

install_as_service() {
    # Variables for file paths
    service_name="update_network"
    service_file="/etc/systemd/system/${service_name}.service"
    script_path="/usr/local/bin/${service_name}.sh"

    # Copy the actual script to /usr/local/bin (adjust accordingly)
    cp "$HOME/scripts/update_network.sh" "$script_path"  # Replace with your actual script file name

    # Ensure the script is executable
    chmod +x "$script_path"

    # Create the systemd service file
    cat <<EOF | tee "$service_file"
[Unit]
Description=IP Octet Update Service
After=network.target

[Service]
Type=simple
ExecStart=$script_path

[Install]
WantedBy=multi-user.target
EOF

    # Add cron jobs
    echo "0 9 * * * $SCRIPT_PATH" >> /etc/crontab
    echo "0 18 * * * $SCRIPT_PATH" >> /etc/crontab


    # Reload systemd daemon, enable and start the timer
    systemctl daemon-reload
    systemctl enable "${service_name}"
    systemctl start "${service_name}"

    echo "Service installed successfully and is scheduled to run twice a day."
}

############################ Install Functions ####################################

install_offline_tools() {
    if [ "${r2d2_answer,,}" = 'y' ]; then
        clone_gitlab_projects
    fi

    for key in "${!links[@]}"; do
        echo "Current key: $key"
        OPTIND=1
        if ! check_tools -i "$key" -l "${logs[download_log]}" -t "images"; then
            url="${links[$key]}"
            echo "URL for key $key: $url"
            if [[ $url == *"github"* ]]; then
                echo "Cloning $url..."
                rm -rf "${install_dir}/$key"
                if git clone "$url" "${install_dir}/$key" 2>> "${logs[ERROR_LOG]}"; then
                    OPTIND=1
                    check_tools -i "$key" -l "${logs[download_log]}" -t "links" -u "${logs[download_log]}"
                fi
            elif [[ $url == *"splunk_soar"* ]]; then
                echo "Downloading $url as $soar_package..."
                rm -f "${install_dir}/splunk_soar-*"
                if wget -P "${install_dir}" "$url" 2>> "${logs[ERROR_LOG]}"; then
                    soar_package_file=$(ls "${install_dir}" | grep splunk_soar-unpriv)
                    if [ -n "${soar_package_file}" ]; then
                        mkdir -p "${install_dir}/splunk-soar"
                        tar -xzvf "${install_dir}/$name"*.tgz -C "${install_dir}/"
                        if [ $? -eq 0 ]; then
                            OPTIND=1
                            check_tools -i "splunk_soar" -l "${logs[download_log]}" -t "links" -u "${logs[download_log]}"
                        else
                            echo "Error: Failed to extract $soar_package_file"
                        fi
                    else
                        echo "Error: $soar_package_file not found after download"
                    fi
                fi
            else
                echo "Downloading $url..."
                if wget -P "${install_dir}" "$url" 2>> "${logs[ERROR_LOG]}"; then
                    OPTIND=1
                    check_tools -i "$key" -l "${logs[download_log]}" -t "links" -u "${logs[download_log]}"
                fi
            fi
        fi
    done

    for key in "${!images[@]}"; do
        local image="${images[$key]}"
        OPTIND=1
        if ! check_tools -i "$key" -l "${logs[download_log]}" -t "images"; then
            if docker image inspect "$image" &> /dev/null; then
                echo "Docker image $image is already present."
            else
                echo "Pulling Docker image $image..."
                if docker pull "$image" 2>> "${logs[ERROR_LOG]}"; then
                    OPTIND=1
                    check_tools -i "$key" -l "${logs[download_log]}" -t "images" -u "${logs[download_log]}"
                fi
            fi
        fi
    done

    cat "${logs[download_log]}"
}

install_dashmachine() {
    local CONFIG_FILE="$HOME/configs/dashmachine/config.ini"
    local loop=0
    local installed=false
    local name="dashmachine"

    if [ $debug -eq 0 ]; then
        echo "Debug: Starting install_dashmachine"
        echo "  name: ${name}"
        echo "  install_status log: ${logs[install_status]}"
        echo "  download_log log: ${logs[download_log]}"
        echo "  port: ${ports[${name}_port]}"
    fi

    OPTIND=1
    if check_tools -i "${name}" -l "${logs[install_status]}" -t "container" -p "${ports[${name}_port]}"; then
        echo "${name} has already been installed"
        return 0
    fi

    echo "Installing ${name}..."

    while [ $loop -lt 2 ]; do

        # Check the status of ${name} git repo download
        OPTIND=1
        if ! check_tools -i "${name}" -l "${logs[download_log]}" -t "links"; then
            echo "Cloning ${name} repository..."
            rm -rf "${install_dir}/${name}"
            if git clone "${links[${name}]}" "${install_dir}/${name}"; then
                OPTIND=1
                check_tools -i "${name}" -l "${logs[download_log]}" -t "links" -u "${logs[download_log]}"
            fi
        fi

        # Check if ${name} docker image has been downloaded
        OPTIND=1
        if ! check_tools -i "${name}" -l "${logs[download_log]}" -t "images"; then
            echo "Pulling Docker image for ${name}..."
            if docker pull "${images[${name}]}"; then
                OPTIND=1
                check_tools -i "${name}" -l "${logs[download_log]}" -t "images" -u "${logs[download_log]}"
            fi
        fi

        # If all has been downloaded then begin install
        OPTIND=1
        if check_tools -i "${name}" -l "${logs[download_log]}" -t "links" && \
           check_tools -i "${name}" -l "${logs[download_log]}" -t "images"; then
            cd "${install_dir}/${name}/"

            # Change configurations
            sed -i "s/^password = .*/password = ${PASSWORD}/" "${CONFIG_FILE}" >/dev/null 2>&1
            sed -i "s/^confirm_password = .*/confirm_password = ${PASSWORD}/" "${CONFIG_FILE}" >/dev/null 2>&1
            cp -rf "$HOME/configs/dashmachine/"* "${install_dir}/${name}"

            # Create container in detached mode
            cd "${install_dir}/${name}/"
            docker run -d \
                --name=${name} \
                -p "${ports[dashmachine_port]}:5000" \
                -v "${install_dir}/${name}:/dashmachine/user_data" \
                --restart unless-stopped \
                "${images[${name}]}"
            
            docker cp "${CONFIG_FILE}" "${name}:/dashmachine/dashmachine/user_data/config.ini"

            OPTIND=1
            if check_tools -i "${name}" -l "${logs[download_log]}" -t "container" -u "${logs[install_status]}" -p "${ports[dashmachine_port]}"; then
                install_as_service
                installed=true
                break
            fi
        fi

        # Loop twice if checks fail
        ((loop++))
    done

    if [ "$installed" == true ]; then
        message="${name} installed successfully.
        ${name} Username: admin
        ${name} Password: ${PASSWORD}
        ${name} is located at http://localhost:${ports[dashmachine_port]}"
        echo "$message"
        echo "$message" >> "${logs[install_info]}"

        # Add firewall rules
        echo "Adding Firewall exceptions..."
        if command -v ufw > /dev/null; then
            echo "Using UFW to add exceptions..."
            ufw allow "${ports[dashmachine_port]}/tcp"
        elif command -v iptables > /dev/null; then
            echo "Using iptables to add exceptions..."
            iptables -A INPUT -p tcp --dport "${ports[dashmachine_port]}" -j ACCEPT
        else
            echo "No recognized firewall tool installed (ufw or iptables)."
        fi
    else
        echo "An error has occurred."
        echo "${name} has not been installed. Check ${logs[ERROR_LOG]}"
    fi
}


install_velociraptor() {
    local CONFIG_FILE="${install_dir}/velociraptor/.env"
    local DOCKER_FILE="${install_dir}/velociraptor/docker-compose.yaml"
    local loop=0
    local installed=false
    local name="velociraptor"
    local port="${ports[velociraptor_port1]}"  # Using velociraptor_port1 as the main port for the container

    if [ $debug -eq 0 ]; then
        echo "Debug: Starting install_velociraptor"
        echo "  name: ${name}"
        echo "  install_status log: ${logs[install_status]}"
        echo "  download_log log: ${logs[download_log]}"
        echo "  install_info log: ${logs[install_info]}"
        echo "  error log: ${logs[ERROR_LOG]}"
        echo "  port: ${port}"
    fi

    if [ -z "$port" ]; then
        echo "Error: Port for ${name} is not set."
        return 1
    fi

    OPTIND=1
    if check_tools -i "${name}" -l "${logs[install_status]}" -t "container" -p "${port}"; then
        echo "${name} has already been installed"
        return 0
    fi

    echo "Installing ${name}..."

    while [ $loop -lt 2 ]; do
        
        # Check the status of the ${name} github repo download
        if [ $debug -eq 0 ]; then
            echo "Debug: Calling check_tools for download_log (links) with parameters"
            echo "  instance: ${name}"
            echo "  log: ${logs[download_log]}"
            echo "  port: ${port}"
        fi
        OPTIND=1
        if ! check_tools -i "${name}" -l "${logs[download_log]}" -t "links"; then 
            rm -rf "${install_dir}/${name}"*
            if git clone "${links[${name}]}" "${install_dir}/${name}"; then
                if [ $debug -eq 0 ]; then
                    echo "Debug: Calling check_tools to update download_log (links) with parameters"
                    echo "  instance: ${name}"
                    echo "  log: ${logs[download_log]}"
                    echo "  port: ${port}"
                fi
                OPTIND=1
                check_tools -i "${name}" -l "${logs[download_log]}" -t "links" -u "${logs[download_log]}"
            fi
        fi

        # Check the status of the ${name} docker image download
        if [ $debug -eq 0 ]; then
            echo "Debug: Calling check_tools for download_log (images) with parameters"
            echo "  instance: ${name}"
            echo "  log: ${logs[download_log]}"
            echo "  port: ${port}"
        fi
        OPTIND=1
        if ! check_tools -i "${name}" -l "${logs[download_log]}" -t "images"; then
            if docker pull "${images[${name}]}"; then
                if [ $debug -eq 0 ]; then
                    echo "Debug: Calling check_tools to update download_log (images) with parameters"
                    echo "  instance: ${name}"
                    echo "  log: ${logs[download_log]}"
                    echo "  port: ${port}"
                fi
                OPTIND=1
                check_tools -i "${name}" -l "${logs[download_log]}" -t "images" -u "${logs[download_log]}"
            fi
        fi

        # Check the status of all downloads
        if [ $debug -eq 0 ]; then
            echo "Debug: Checking status of all downloads"
            echo "  instance: ${name}"
            echo "  log: ${logs[download_log]}"
            echo "  port: ${port}"
        fi
        OPTIND=1
        if check_tools -i "${name}" -l "${logs[download_log]}" -t "links" && check_tools -i "${name}" -l "${logs[download_log]}" -t "images"; then
            echo "${name} packages have been downloaded. Proceeding with ${name} installation..."

            # Update the Docker Compose file version
            sed -i 's/^version: .*/version: "2.4"/' "${DOCKER_FILE}"
            
            # Change default user information
            sed -i "s/^VELOX_USER=.*/VELOX_USER=${INSTALL_USER}/" ${CONFIG_FILE}
            sed -i "s/^VELOX_PASSWORD=.*/VELOX_PASSWORD=${PASSWORD}/" ${CONFIG_FILE}
            sed -i "s|^VELOX_SERVER_URL=https://VelociraptorServer.*|VELOX_SERVER_URL=https://VelociraptorServer:${ports[velociraptor_port1]}/|" ${CONFIG_FILE}
            sed -i "s/- \"8000:8000\"/- \"${ports[velociraptor_port1]}:8000\"/" ${DOCKER_FILE}
            sed -i "s/- \"8001:8001\"/- \"${ports[velociraptor_port2]}:8001\"/" ${DOCKER_FILE}
            sed -i "s/- \"8889:8889\"/- \"${ports[velociraptor_port3]}:8889\"/" ${DOCKER_FILE}

            # Run install
            cd "${install_dir}/velociraptor" && docker compose up -d
            if [ $? -eq 0 ]; then
                if [ $debug -eq 0 ]; then
                    echo "Debug: Calling check_tools to update install_status with parameters"
                    echo "  instance: ${name}"
                    echo "  log: ${logs[download_log]}"
                    echo "  update_log: ${logs[install_status]}"
                    echo "  port: ${port}"
                fi
                OPTIND=1
                check_tools -i "${name}" -l "${logs[download_log]}" -t "container" -u "${logs[install_status]}" -p "${port}"
            fi

            if [ $debug -eq 0 ]; then
                echo "Debug: Calling check_tools for install_status with parameters"
                echo "  instance: ${name}"
                echo "  log: ${logs[install_status]}"
                echo "  port: ${port}"
            fi
            OPTIND=1
            if check_tools -i "${name}" -l "${logs[install_status]}" -t "container" -p "${port}"; then
                installed=true
                break
            fi
        fi

        ((loop++))
    done

    if [ "$installed" == true ]; then
        message=" ${name} installed successfully.
        ${name} Username: $INSTALL_USER
        ${name} Password: ${PASSWORD}
        ${name} is located at https://localhost:${port}"
        echo $message >> "${logs[install_info]}"

        # Adding Firewall exceptions...
        if command -v ufw > /dev/null; then
            echo "Using UFW to add exceptions..."
            ufw allow "${port}/tcp"
        elif command -v iptables > /dev/null; then
            echo "Using iptables to add exceptions..."
            iptables -A INPUT -p tcp --dport "${ports[velociraptor_port3]}" -j ACCEPT
        else
            echo "No recognized firewall tool installed (ufw or iptables)."
        fi
    else
        echo "Failed to install ${name}, see ${logs[ERROR_LOG]} for details."
    fi
}

install_volatility() {
    local loop=0
    local installed=false
    local name="volatility"
    
    if [ $debug -eq 0 ]; then
        echo "Debug: Starting install_volatility"
        echo "  name: ${name}"
        echo "  install_status log: ${logs[install_status]}"
        echo "  download_log log: ${logs[download_log]}"
        echo "  install_info log: ${logs[install_info]}"
        echo "  error log: ${logs[ERROR_LOG]}"
    fi
    
    OPTIND=1
    if check_tools -i "${name}" -l "${logs[install_status]}" -t "links"; then
        echo "${name} has already been installed"
        return 0
    fi

    echo "Installing ${name}..."

    while [ $loop -lt 2 ]; do
        
        # Check the status of the ${name} github repo download
        if [ $debug -eq 0 ]; then
            echo "Debug: Calling check_tools for download_log with parameters"
            echo "  instance: ${name}"
            echo "  log: ${logs[download_log]}"
        fi
        OPTIND=1
        if ! check_tools -i "${name}" -l "${logs[download_log]}" -t "links"; then
            rm -rf "${install_dir}/${name}"
            if git clone "${links[${name}]}" "${install_dir}/${name}"; then
                if [ $debug -eq 0 ]; then
                    echo "Debug: Calling check_tools to update download_log with parameters"
                    echo "  instance: ${name}"
                    echo "  log: ${logs[download_log]}"
                fi
                OPTIND=1
                check_tools -i "${name}" -l "${logs[download_log]}" -t "links" -u "${logs[download_log]}"
            fi
        else
            sudo chmod +x ${install_dir}/${name}/setup.py
            sudo python ${install_dir}/${name}/setup.py install --disable-zeek --disable-mongo
            sudo chmod u+x ${install_dir}/${name}/vol.py
            sudo ln -s ${install_dir}/${name}/vol.py /usr/local/bin/vol.py
            if vol.py ; then
                if [ $debug -eq 0 ]; then
                    echo "Debug: Calling check_tools to update install_status with parameters"
                    echo "  instance: ${name}"
                    echo "  log: ${logs[download_log]}"
                    echo "  update_log: ${logs[install_status]}"
                fi
                OPTIND=1
                check_tools -i "${name}" -l "${logs[download_log]}" -t "links" -u "${logs[install_status]}"
                check_tools -i "${name}" -l "${logs[download_log]}" -t "links" -u "${logs[download_log]}"
            fi
        fi
        if [ $debug -eq 0 ]; then
            echo "Debug: Calling check_tools for install_status with parameters"
            echo "  instance: ${name}"
            echo "  log: ${logs[install_status]}"
        fi
        OPTIND=1
        if check_tools -i "${name}" -l "${logs[install_status]}" -t "links"; then
            installed=true
            break
        fi
        ((loop++))
    done

    if [ "$installed" == true ]; then
        message=" ${name} installed successfully.
        echo ${name} is located at ${install_dir}/${name}" 
        echo $message >> "${logs[install_info]}"
    else
        echo "Failed to install ${name}, see ${logs[ERROR_LOG]} for details."
    fi
}

install_hayabusa() { 
    local loop=0
    local installed=false
    local name="hayabusa"
    
    if [ $debug -eq 0 ]; then
        echo "Debug: Starting install_hayabusa"
        echo "  name: ${name}"
        echo "  install_status log: ${logs[install_status]}"
        echo "  download_log log: ${logs[download_log]}"
        echo "  install_info log: ${logs[install_info]}"
        echo "  error log: ${logs[ERROR_LOG]}"
    fi
    
    OPTIND=1
    if check_tools -i "${name}" -l "${logs[install_status]}" -t "links"; then
        echo "${name} has already been installed"
        return 0
    fi

    echo "Installing ${name}..."

    while [ $loop -lt 2 ]; do
        
        # Check the status of the Volatility github repo download
        if [ $debug -eq 0 ]; then
            echo "Debug: Calling check_tools for download_log with parameters"
            echo "  instance: ${name}"
            echo "  log: ${logs[download_log]}"
        fi
        OPTIND=1
        if ! check_tools -i "${name}" -l "${logs[download_log]}" -t "links"; then
            rm -rf "${install_dir}/${name}"
            if git clone "${links[${name}]}" "${install_dir}/${name}"; then
                if [ $debug -eq 0 ]; then
                    echo "Debug: Calling check_tools to update install_status with parameters"
                    echo "  instance: ${name}"
                    echo "  log: ${logs[download_log]}"
                    echo "  update_log: ${logs[install_status]}"
                fi
                OPTIND=1
                check_tools -i "${name}" -l "${logs[download_log]}" -t "links" -u "${logs[install_status]}"
                check_tools -i "${name}" -l "${logs[download_log]}" -t "links" -u "${logs[download_log]}"
            fi
        fi
        if [ $debug -eq 0 ]; then
            echo "Debug: Calling check_tools for install_status with parameters"
            echo "  instance: ${name}"
            echo "  log: ${logs[install_status]}"
        fi
        OPTIND=1
        if check_tools -i "${name}" -l "${logs[install_status]}" -t "links"; then
            installed=true
            break
        fi
        ((loop++))
    done

    if [ "$installed" == true ]; then
        message="${name} is installed successfully.
        ${name} is located at ${install_dir}/${name}"
        echo $message >> "${logs[install_info]}"
    else
        echo "Failed to install ${name}, see ${logs[ERROR_LOG]} for details."
    fi
}

install_mattermost() {
    local loop=0
    local installed=false
    local name="mattermost"
    local CONFIG_FILE="${install_dir}/${name}/.env"

    if [ $debug -eq 0 ]; then
        echo "Debug: Starting install_mattermost"
        echo "  name: ${name}"
        echo "  install_status log: ${logs[install_status]}"
        echo "  download_log log: ${logs[download_log]}"
        echo "  port: ${ports[MM_port]}"
    fi

    OPTIND=1
    if check_tools -i "${name}" -l "${logs[install_status]}" -t "container" -p "${ports[MM_port]}"; then
        echo "${name} has already been installed"
        return 0
    fi

    echo "Installing ${name}..."

    while [ $loop -lt 2 ]; do
        
        # Check status of docker image download
        OPTIND=1
        if ! check_tools -i "postgres" -l "${logs[download_log]}" -t "images"; then
            echo "Pulling Docker image for postgres..."
            if docker pull "${images[postgres]}"; then
                OPTIND=1
                check_tools -i "postgres" -l "${logs[download_log]}" -t "images" -u "${logs[download_log]}"
            fi
        fi
        
        OPTIND=1
        if ! check_tools -i "nginx" -l "${logs[download_log]}" -t "images"; then
            echo "Pulling Docker image for nginx..."
            if docker pull "${images[nginx]}"; then
                OPTIND=1
                check_tools -i "nginx" -l "${logs[download_log]}" -t "images" -u "${logs[download_log]}"
            fi
        fi
        
        OPTIND=1
        if ! check_tools -i "${name}" -l "${logs[download_log]}" -t "links"; then
            echo "Cloning Mattermost repository..."
            rm -rf "${install_dir}/${name}"
            if git clone "${links[${name}]}" "${install_dir}/${name}"; then
                OPTIND=1
                check_tools -i "${name}" -l "${logs[download_log]}" -t "links" -u "${logs[download_log]}"
            fi
        fi
        
        OPTIND=1
        if check_tools -i "postgres" -l "${logs[download_log]}" -t "images" && \
           check_tools -i "nginx" -l "${logs[download_log]}" -t "images" && \
           check_tools -i "${name}" -l "${logs[download_log]}" -t "links"; then
            echo "Mattermost has been downloaded. Beginning installation"

            # Set Environmental variables 
            cd "${install_dir}/${name}" && cp "${install_dir}/${name}/env.example" "${install_dir}/${name}/.env"
            
            # Update configuration file with new values
            sed -i "s/^DOMAIN=.*/DOMAIN=$DOMAIN/" ${CONFIG_FILE}
            sed -i "s/^POSTGRES_USER=.*/POSTGRES_USER=$INSTALL_USER/" ${CONFIG_FILE}
            sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${PASSWORD}/" ${CONFIG_FILE}
            sed -i "s/^APP_PORT=.*/APP_PORT=${ports[MM_PORT]}/" ${CONFIG_FILE}
            sed -i "s/8443/${ports[MM_PORT]}/g" ${CONFIG_FILE}

            # Creating required directories
            mkdir -p ${install_dir}/${name}/volumes/app/mattermost/{config,data,logs,plugins,client/plugins,bleve-indexes}
            sudo chown -R 2000:2000 ./volumes/app/mattermost

            # Starting docker image 
            cd "${install_dir}/${name}"
            if sudo docker compose -f docker-compose.yml -f docker-compose.without-nginx.yml up -d; then
                OPTIND=1
                check_tools -i "${name}" -l "${logs[download_log]}" -t "container" -u "${logs[install_status]}" -p "${ports[MM_port]}"
            fi
            
            OPTIND=1
            if check_tools -i "${name}" -l "${logs[install_status]}" -t "container" -p "${ports[MM_port]}"; then
                installed=true
                break
            fi
        fi

        ((loop++))
    done

    if [ "$installed" == true ]; then
        message="${name} installed successfully.
        ${name} Username: $INSTALL_USER
        ${name} Password: ${PASSWORD}
        ${name} is located at http://localhost:${ports[MM_PORT]}"
        echo "$message"
        echo "$message" >> "${logs[install_info]}"

        # Firewall Rules
        echo "Adding Firewall exceptions..." 
        if command -v ufw > /dev/null; then
            echo "Using UFW to add exceptions..."
            ufw allow "${ports[MM_PORT]}/tcp"
        elif command -v iptables > /dev/null; then
            echo "Using iptables to add exceptions..."
            iptables -A INPUT -p tcp --dport "${ports[MM_PORT]}" -j ACCEPT
        else
            echo "No recognized firewall tool installed (ufw or iptables)."
        fi
    else
        echo "Failed to install ${name}, see ${logs[ERROR_LOG]} for details."
    fi
}

enable_fips_mode() {
    local name="fips_mode"
    local install_log="${logs[install_status]}"
    local fips
    local aes

    if [ $debug -eq 0 ]; then
        echo "Debug: Starting enable_fips_mode"
        echo "  name: ${name}"
        echo "  install_status log: ${install_log}"
    fi

    # Check FIPS status using check_tools
    OPTIND=1
    if check_tools -i "${name}_fips" -l "${install_log}" -t "status"; then
        echo "FIPS mode is already enabled."
    else
        echo "FIPS mode is not enabled. Installing necessary packages..."
        sudo yum install -y dracut-fips dracut-aesni
        echo "FIPS mode is now enabled."
        echo "${name}_fips: 1" >> "${install_log}"
    fi

    # Check AES status using check_tools
    OPTIND=1
    if check_tools -i "${name}_aes" -l "${install_log}" -t "status"; then
        echo "AES is already installed."
    else
        echo "AES is not installed. Installing necessary package..."
        sudo yum install -y dracut-aesni
        echo "AES is now installed."
        echo "${name}_aes: 1" >> "${install_log}"
    fi

    # Backup initramfs
    cp "/boot/initramfs-$(uname -r).img" "/boot/initramfs-$(uname -r).backup"

    # Edit grub config
    UUID=$(lsblk -fp | grep "boot" | awk '{print $3}')
    grub_entry="GRUB_CMDLINE_LINUX=\"boot=$UUID nofb splash=quiet crashkernel=auto rd.lvm.lv=VolGroup00/lv_root rd.lvm.lv=VolGroup00/lv_swap rhgb quiet fips=1\""
    sudo sed -i "s/^GRUB_CMDLINE_LINUX=.*/$grub_entry/" /etc/default/grub

    # Update grub configuration based on system firmware
    if [ -d /sys/firmware/efi ]; then
        echo "System is in UEFI mode."
        sudo grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
    else
        echo "System is in Legacy BIOS mode."
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    fi

    # Add log entry to install_status
    if [[ "$fips" -eq 1 ]] && [[ "$aes" -gt 0 ]]; then
        echo "${name}_installed: 1" >> "$install_log"
    else
        echo "${name}_installed: 0" >> "$install_log"
    fi

    # Restart system
    echo "Rebooting system to apply changes..."
    /sbin/shutdown -r now
}

install_soar() {
    local loop=0
    local installed=false
    local storage
    local USER="phantom"
    local name="splunk_soar"
    local soar_dir="${install_dir}/splunk-soar"
    local port="${ports[soar_port]}"

    if [ $debug -eq 0 ]; then
        echo "Debug: Starting install_soar"
        echo "  name: ${name}"
        echo "  install_status log: ${logs[install_status]}"
        echo "  download_log log: ${logs[download_log]}"
        echo "  install_info log: ${logs[install_info]}"
        echo "  error log: ${logs[ERROR_LOG]}"
        echo "  port: ${port}"
    fi

    # Directly run the storage calculation command for debugging
    storage=$(sudo fdisk -l | awk '/Disk \/dev/{total += $5} END {print int((total / 1024 / 1024 / 1024) + 0.5) " GB"}' | cut -d ' ' -f1)
    echo "Calculated storage: ${storage} GB"

    # Print the storage value for debugging
    if [ -z "$storage" ]; then
        echo "Error: Failed to calculate storage."
        exit 1
    fi

    if [ -z "$port" ]; then
        echo "Error: Port for ${name} is not set."
        return 1
    fi

    OPTIND=1
    if check_tools -i "${name}" -l "${logs[install_status]}" -t "links" -p "${port}"; then
        echo "${name} has already been installed"
        return 0
    fi

    echo "Installing ${name}..."

    if [[ "$DISTRO" =~ (ol|centos) ]]; then
        echo "This is a RHEL Linux system, version $DISTRO_VERSION"
        sudo firewall-cmd --permanent --zone=public --add-port=22/tcp
        sudo firewall-cmd --permanent --zone=public --add-port=2222/tcp
        sudo firewall-cmd --permanent --zone=public --add-port="${port}/tcp"
        sudo firewall-cmd --reload  
    else
        echo "SOAR can only be installed on RHEL based systems (CentOS, Oracle)"
        exit 1
    fi 

    while [ $loop -lt 2 ]; do
        
        # Check the status of the SOAR package download
        soar_package_file=$(ls "${install_dir}" | grep splunk_soar-unpriv)
        if [ -z "${soar_package_file}" ]; then
            echo "Downloading SOAR package..."
            rm -f "${install_dir}"/splunk_soar-unpriv*
            wget -P "${install_dir}" "${links[splunk_soar]}" 2>> "${logs[ERROR_LOG]}"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to download SOAR package."
                exit 1
            fi
            soar_package_file=$(ls "${install_dir}" | grep splunk_soar-unpriv)
            if [ -z "${soar_package_file}" ]; then
                echo "Error: SOAR package not found after download."
                exit 1
            fi
            mkdir -p "${install_dir}/splunk-soar"
            tar -xzvf "${install_dir}/$name"*.tgz -C "${install_dir}"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to extract SOAR package."
                exit 1
            fi
            if [ $debug -eq 0 ]; then
                echo "Debug: Calling check_tools to update download_log (links) with parameters"
                echo "  instance: ${name}"
                echo "  log: ${logs[download_log]}"
                echo "  port: ${port}"
            fi
            OPTIND=1
            check_tools -i "${name}" -l "${logs[download_log]}" -t "links" -u "${logs[download_log]}"
        fi

        # Install SOAR
        if check_tools -i "${name}" -l "${logs[download_log]}" -t "links"; then
            # Create User
            sudo adduser phantom
            mkdir -p "${install_dir}/soar"
            chown -R $USER:$USER "${install_dir}/soar"
            chown -R $USER:$USER "$soar_dir"
            cd "$soar_dir"

            # Prep system
            ./soar-prepare-system --splunk-soar-home "${install_dir}/soar" --https-port "${port}" --splunk-soar-user "$USER" -y

            if [ "$storage" -lt 500 ]; then
                if sudo su -c "./soar-install --splunk-soar-home ${install_dir}/soar --https-port ${port} -y --ignore-warnings" $USER; then
                    if [ $debug -eq 0 ]; then
                        echo "Debug: Calling check_tools to update install_status with parameters"
                        echo "  instance: ${name}"
                        echo "  log: ${logs[download_log]}"
                        echo "  update_log: ${logs[install_status]}"
                        echo "  port: ${port}"
                    fi
                    OPTIND=1
                    check_tools -i "${name}" -l "${logs[download_log]}" -t "links" -u "${logs[install_status]}" -p "${port}"
                fi
            else
                if sudo su -c "./soar-install --splunk-soar-home ${install_dir}/soar --https-port ${port} -y" $USER; then
                    if [ $debug -eq 0 ]; then
                        echo "Debug: Calling check_tools to update install_status with parameters"
                        echo "  instance: ${name}"
                        echo "  log: ${logs[download_log]}"
                        echo "  update_log: ${logs[install_status]}"
                        echo "  port: ${port}"
                    fi
                    OPTIND=1
                    check_tools -i "${name}" -l "${logs[download_log]}" -t "links" -u "${logs[install_status]}" -p "${port}"
                fi
            fi

            if check_tools -i "${name}" -l "${logs[install_status]}" -t "links" -p "${port}"; then
                installed=true
                break
            fi
        fi

        ((loop++))
    done

    if [ "$installed" == true ]; then
        message="SOAR installed successfully.
        SOAR Username: $USER
        SOAR Password: ${PASSWORD}
        SOAR Port: ${port}
        ${name} is located at http://localhost:${port}"
        echo "$message"
        echo "$message" >> "${logs[install_info]}"
    else
        echo "Failed to install SOAR, see ${logs[ERROR_LOG]} for details."
    fi
}

install_hunt_handbook() {
    local CONFIG_FILE="${install_dir}/hunt_handbook/docker-compose.yaml"
    local loop=0
    local installed=false
    local name="hunt_handbook"
    local squidfunk_port="${ports[squidfunk_port]}"

    if [ $debug -eq 0 ]; then
        echo "Debug: Starting install_hunt_handbook"
        echo "  name: ${name}"
        echo "  install_status log: ${logs[install_status]}"
        echo "  download_log log: ${logs[download_log]}"
        echo "  install_info log: ${logs[install_info]}"
        echo "  error log: ${logs[ERROR_LOG]}"
        echo "  port: ${squidfunk_port}"
    fi

    if [ -z "$squidfunk_port" ]; then
        echo "Error: Port for squidfunk is not set."
        return 1
    fi

    OPTIND=1
    if check_tools -i "squidfunk" -l "${logs[install_status]}" -t "container" -p "${squidfunk_port}"; then
        echo "${name} has already been installed"
        return 0
    fi

    echo "Installing ${name}..."

    while [ $loop -lt 2 ]; do
        
        # Check the status of the SOPs git repo download
        if [ $debug -eq 0 ]; then
            echo "Debug: Calling check_tools for download_log (gitlab) with parameters"
            echo "  instance: SOPs"
            echo "  log: ${logs[download_log]}"
        fi
        OPTIND=1
        if ! check_tools -i "SOPs" -l "${logs[download_log]}" -t "gitlab"; then
            rm -rf "${install_dir}/SOPs"
            if clone_gitlab_projects; then
                if [ $debug -eq 0 ]; then
                    echo "Debug: Calling check_tools to update download_log (gitlab) with parameters"
                    echo "  instance: ${name}"
                    echo "  log: ${logs[download_log]}"
                fi
                OPTIND=1
                check_tools -i "${name}" -l "${logs[download_log]}" -t "gitlab" -u "${logs[download_log]}"
            fi
        fi

        # Check if squidfunk docker image has been downloaded
        if [ $debug -eq 0 ]; then
            echo "Debug: Calling check_tools for download_log (images) with parameters"
            echo "  instance: squidfunk"
            echo "  log: ${logs[download_log]}"
        fi
        OPTIND=1
        if ! check_tools -i "squidfunk" -l "${logs[download_log]}" -t "images"; then
            if docker pull "${images[squidfunk]}"; then
                if [ $debug -eq 0 ]; then
                    echo "Debug: Calling check_tools to update download_log (images) with parameters"
                    echo "  instance: squidfunk"
                    echo "  log: ${logs[download_log]}"
                fi
                OPTIND=1
                check_tools -i "squidfunk" -l "${logs[download_log]}" -t "images" -u "${logs[download_log]}"
            fi
        fi

        # If all has been downloaded then begin install
        if [ $debug -eq 0 ]; then
            echo "Debug: Checking status of all downloads"
            echo "  instance: SOPs"
            echo "  log: ${logs[download_log]}"
        fi
        OPTIND=1
        if check_tools -i "SOPs" -l "${logs[download_log]}" -t "gitlab" && check_tools -i "squidfunk" -l "${logs[download_log]}" -t "images"; then
            echo "${name} packages have been downloaded. Proceeding with ${name} installation..."

            # Copy stored configs to hunt_handbook
            echo "Copying hunt_handbook configs to ${install_dir}/hunt_handbook"
            cp -rf "${HOME}/configs/hunt_handbook" "${install_dir}/"
            cp -rf "${install_dir}/SOPs/"* "${install_dir}/${name}/mkdocs/docs/"
            cp -f "${install_dir}/One-Stop-Shop/configs/${name}/mkdocs/mkdocs.yml" "${install_dir}/${name}/mkdocs/"
            
            # Change configurations
            sed -i "s/- \"8000:8000\"/- \"${squidfunk_port}:8000\"/" "${CONFIG_FILE}"

            # Create container in detached mode
            cd "${install_dir}/${name}"
            if docker-compose up -d; then
                if [ $debug -eq 0 ]; then
                    echo "Debug: Calling check_tools to update install_status with parameters"
                    echo "  instance: squidfunk"
                    echo "  log: ${logs[download_log]}"
                    echo "  update_log: ${logs[install_status]}"
                    echo "  port: ${squidfunk_port}"
                fi
                OPTIND=1
                check_tools -i "squidfunk" -l "${logs[download_log]}" -t "container" -u "${logs[install_status]}" -p "${squidfunk_port}"
            fi

            if check_tools -i "squidfunk" -l "${logs[install_status]}" -t "container" -p "${squidfunk_port}"; then
                installed=true
                break
            fi
        fi

        ((loop++))
    done

    if [ "$installed" == true ]; then
        message=" ${name} installed successfully.
        ${name} is located at http://localhost:${squidfunk_port}"
        echo "$message"
        echo "$message" >> "${logs[install_info]}"

        # Add firewall rules
        echo "Adding Firewall exceptions..."
        if command -v ufw > /dev/null; then
            echo "Using UFW to add exceptions..."
            ufw allow "${squidfunk_port}/tcp"
        elif command -v iptables > /dev/null; then
            echo "Using iptables to add exceptions..."
            iptables -A INPUT -p tcp --dport "${squidfunk_port}" -j ACCEPT
        else
            echo "No recognized firewall tool installed (ufw or iptables)."
        fi
    else
        echo "An error has occurred."
        echo "${name} has not been installed. Check ${logs[ERROR_LOG]}"
    fi
}


####################################### MAIN ################################################

function onestopshop() {
    # Check if script is run as root
    if [ "$EUID" -ne 0 ]; then 
        echo "Please run as root or sudo"
        exit
    fi

    echo "Detecting Linux distribution..." 
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=${ID,,} # Convert to lowercase for case-insensitive comparison
        DISTRO_VERSION=$VERSION_ID

        echo "Distribution ID: $DISTRO"
        echo "Version: $DISTRO_VERSION"

        # Handling distributions like Oracle Linux which might be identified more generally
        if [[ "${ID_LIKE,,}" == *"rhel"* ]] && [[ "$DISTRO" == "ol" ]]; then
            echo "This is Oracle Linux, version $DISTRO_VERSION"
            setenforce 0
        elif [[ "$DISTRO" == "centos" ]]; then
            echo "This is CentOS, version $DISTRO_VERSION"
            setenforce 0
        elif [[ "$DISTRO" == "ubuntu" ]]; then
            echo "This is Ubuntu, version $DISTRO_VERSION"
        else
            echo "Unsupported or unrecognized distribution."
        fi
    else
        echo "The /etc/os-release file does not exist. Unable to determine distribution."
    fi
    
    for log_file in "${logs[@]}"; do
        if [ ! -f "$log_file" ]; then
            echo "Creating $log_file because it does not exist."
            touch "$log_file"
            if [ $? -ne 0 ]; then
                echo "Unable to create $log_file."
            else
                echo "$log_file created successfully."
            fi
        else
            echo "$log_file already exists."
        fi
    done

    echo "Are you planning on downloading projects from R2D2?"
    echo "This requires username and personal access token"
    read -p "(y/n):" r2d2_answer

    echo "Do you want to replace the default password?"
    read -p "(y/n):" pass_answer
    if [ "${pass_answer,}" = "y" ]; then
        read -s "Enter Password:" pass1
        read -s "Enter Password again:" pass2
        if [ "$pass1" = "$pass2" ]; then
            PASSWORD=$pass1
        fi
    fi


    choices=()  # Array to store user selections

    while true; do
        echo "The installation of any of these tools requires an internet connection. Use a whiteline."
        echo "Select which applications to install (type 'done' when finished):"
        echo "0. Enable FIPS Mode (Required by SOAR and will restart system)"
        echo "1. Download Tools for offline installation"
        echo "2. DashMachine"
        echo "3. Velociraptor"
        echo "4. Volatility"
        echo "5. Hayabusa"
        echo "6. SOAR (MUST be installed on the interwebs)"
        echo "7. Mattermost"
        echo "8. Hunt handbook"
        echo "9. All"
        echo "10. Done with selection or exit"

        read -p "Enter choice [0-10] or 'done': " input
        if [[ "$input" =~ ^(0?[0-9]|1[01])$ ]] && [ "$input" -ge 0 ] && [ "$input" -le 10 ]; then
            if [ "$input" -eq 10 ]; then
                break
            elif [ "$input" -eq 9 ]; then
                
                OPTIND=1
                if ! check_tools -i "supporting_tools" -l "${logs[download_log]}"; then 
                    install_supporting_tools 2>> "${logs[ERROR_LOG]}"
                fi
                install_offline_tools
                install_dashmachine
                install_velociraptor
                install_volatility
                install_hayabusa
                install_soar
                install_mattermost
                install_hunt_handbook ;  2>> "${logs[ERROR_LOG]}"
                if [ $? -ne 0 ]; then
                    echo "One or more installations failed. See ${logs[ERROR_LOG]} for details."
                else
                    echo "All selected tools have been installed successfully."
                fi
                choices+=("$input")
                break
            elif [ "$input" -eq 0 ]; then
                # Enable FIPS mode
                OPTIND=1
                if ! check_tools -i "supporting_tools" -l "${logs[download_log]}"; then 
                    install_supporting_tools 2>> "${logs[ERROR_LOG]}"
                fi
                if check_tools -i "enable_fips_mode" -l "${install_log}" -t "status"; then
                    echo "FIPS mode is already enabled."
                else
                    enable_fips_mode 2>> "${logs[ERROR_LOG]}"
                    echo "FIPS mode enabled. System will restart."
                    exit 0
                fi
            elif [ "$input" -eq 1 ]; then
                # Download tools for offline installation
                OPTIND=1
                if ! check_tools  "supporting_tools" "${logs[download_log]}"; then 
                    install_supporting_tools 2>> "${logs[ERROR_LOG]}"
                fi
                install_offline_tools 2>> "${logs[ERROR_LOG]}"
                echo "Offline tools downloaded."
                exit 0
            else
                choices+=("$input")
            fi
        elif [ "$input" == "done" ]; then
            break
        else
            echo "Invalid choice. Try again."
        fi
        # Remove duplicate choices if any
        choices=($(echo "${choices[@]}" | tr ' ' '\n' | sort | tr '\n' ' '))

    done

    # Execute selected installations
    if ! check_tools -i "supporting_tools" -l "${logs[download_log]}"; then 
        install_supporting_tools 2>> "${logs[ERROR_LOG]}"
    fi
    for choice in "${choices[@]}"; do
        case $choice in
            2) install_dashmachine 2>> "${logs[ERROR_LOG]}";;
            3) install_velociraptor 2>> "${logs[ERROR_LOG]}";;
            4) install_volatility 2>> "${logs[ERROR_LOG]}";;
            5) install_hayabusa 2>> "${logs[ERROR_LOG]}";;
            6) install_soar 2>> "${logs[ERROR_LOG]}";;
            7) install_mattermost 2>> "${logs[ERROR_LOG]}";;
            8) install_hunt_handbook 2>> "${logs[ERROR_LOG]}";;
        esac
    done

    cat "${logs[install_info]}" 
}

onestopshop
