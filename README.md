# Standard Operating Procedure (SOP) for Running the Installation Script

## Purpose
This Standard Operating Procedure (SOP) outlines the steps required to execute the provided Bash script for installing and configuring various tools and services on a Linux system.

## Scope
This SOP applies to all users who need to set up and configure the specified tools and services using the provided script.

## Responsibilities
- Ensure you have the necessary permissions to execute the script (root or sudo access).
- Verify that the system meets the prerequisites for the installations.
- Follow the procedure outlined in this SOP to successfully complete the installation.

## Prerequisites
- Root or sudo access to the Linux system.
- Internet connection for downloading necessary packages and tools.
- Ensure the system is running a supported Linux distribution (Ubuntu, CentOS, or Oracle Linux).

## Global Variables
The script uses several global variables for configuration:
- `debug`: Enable debug mode (set to 1 for debug).
- `HOME`: Set to the current working directory.
- `DOMAIN`: Domain name.
- `INSTALL_USER`: Username for installation.
- `PASSWORD`: Password for installation.
- `soar_package`: SOAR package filename.
- `install_dir`: Directory for installations.
- `GITLAB_USERNAME`: GitLab username.
- `GITLAB_URL`: URL for GitLab repository.

## Log Files
The script generates log files for various operations:
- `install_info`: Logs installation information.
- `install_status`: Logs the status of installations.
- `ERROR_LOG`: Logs errors encountered during execution.
- `download_log`: Logs download activities.

## Procedure

### Step 1: Prepare the System
1. **Run the Script as Root or Sudo:**
   ```bash
   sudo ./script_name.sh
   ```
   Ensure you have root or sudo access before running the script.

2. **Detect Linux Distribution:**
   The script automatically detects the Linux distribution and version.

3. **Create Log Files:**
   The script checks and creates log files if they do not exist.

### Step 2: Installation Options
The script provides several options for installation:
1. **Enable FIPS Mode:**
   - This option enables FIPS mode, which is required by some tools.
   - Note: Enabling FIPS mode will restart the system.

2. **Download Tools for Offline Installation:**
   - This option downloads necessary tools and packages for offline installation.

3. **Install Individual Tools:**
   - The script allows you to select and install individual tools, including:
     - DashMachine
     - Velociraptor
     - Volatility
     - Hayabusa
     - SOAR
     - Mattermost
     - Hunt Handbook

4. **Install All Tools:**
   - This option installs all the tools listed above.

### Step 3: Execute Selected Installations
1. **Select Installation Options:**
   - You will be prompted to select which tools to install.
   - Type the number corresponding to your choice and press Enter.

2. **Confirm Password Replacement:**
   - If you choose to replace the default password, you will be prompted to enter and confirm the new password.

3. **Install Selected Tools:**
   - The script executes the installation of the selected tools.
   - Follow the on-screen prompts and messages for further instructions.

4. **Review Installation Logs:**
   - After the installation, review the `install_info` log for details of the installed tools.

## Post-Installation
1. **Firewall Configuration:**
   - The script adds necessary firewall rules for the installed services.
   - Ensure the firewall rules are correctly applied.

2. **Service Configuration:**
   - Some tools may require additional configuration. Refer to the respective tool's documentation for further instructions.

3. **System Restart:**
   - If FIPS mode is enabled, the system will restart. Ensure to save all your work before proceeding.

## Troubleshooting
- **Check Logs:**
  - Review the `ERROR_LOG` for any errors encountered during the installation.
  - Check the `install_status` log for the status of each installation step.

- **Debug Mode:**
  - Enable debug mode by setting `debug=1` in the script for more detailed output.

## Maintenance
- Periodically review and update the script to ensure compatibility with new versions of the tools and Linux distributions.
- Maintain the log files for future reference and troubleshooting.

By following this SOP, you can effectively use the provided script to install and configure the necessary tools and services on your Linux system.
