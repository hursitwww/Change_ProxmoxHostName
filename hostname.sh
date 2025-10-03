#!/bin/bash

# Proxmox Hostname Change Script
# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Proxmox Hostname Change ===${NC}\n"

# Auto-detect current hostname
current_hostname=$(hostname)
echo -e "${YELLOW}Current hostname:${NC} $current_hostname"

# Confirm current hostname
read -p "Is this current hostname correct? (Y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    read -p "Please enter the current hostname: " current_hostname
fi

# Get new hostname
echo ""
read -p "Enter new hostname: " new_hostname

# Empty value check
if [ -z "$new_hostname" ]; then
    echo -e "${RED}Error: New hostname cannot be empty!${NC}"
    exit 1
fi

# Same name check
if [ "$current_hostname" == "$new_hostname" ]; then
    echo -e "${RED}Error: New hostname is the same as current hostname!${NC}"
    exit 1
fi

# Final confirmation
echo -e "\n${YELLOW}Summary:${NC}"
echo "Current hostname: $current_hostname"
echo "New hostname: $new_hostname"
echo ""
read -p "Are you sure you want to continue? (Y/N): " final_confirm

if [[ ! $final_confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Operation cancelled.${NC}"
    exit 0
fi

echo -e "\n${GREEN}Starting process...${NC}\n"

# Backup VM config files
echo "1. Backing up VM config files..."
mkdir -p /tmp/qemu
if [ -d "/etc/pve/nodes/$current_hostname/qemu-server" ]; then
    cp /etc/pve/nodes/$current_hostname/qemu-server/* /tmp/qemu/ 2>/dev/null
    echo -e "${GREEN}✓ VM config files backed up${NC}"
else
    echo -e "${YELLOW}! No VM config files found to backup${NC}"
fi

# Change hostname
echo "2. Changing hostname..."
hostnamectl set-hostname "$new_hostname"
echo -e "${GREEN}✓ Hostname changed${NC}"

# Update /etc/hosts
echo "3. Updating /etc/hosts file..."
sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
echo -e "${GREEN}✓ /etc/hosts updated${NC}"

# Restart services
echo "4. Restarting Proxmox services..."
services=("pveproxy.service" "pvebanner.service" "pve-cluster.service" "pvestatd.service" "pvedaemon.service")
for service in "${services[@]}"; do
    systemctl restart "$service"
    echo -e "${GREEN}✓ $service restarted${NC}"
done

# Remove old node directory
echo "5. Cleaning up old node directory..."
rm -rf "/etc/pve/nodes/$current_hostname"
echo -e "${GREEN}✓ Old node directory removed${NC}"

# Restore VM config files
echo "6. Restoring VM config files..."
if [ "$(ls -A /tmp/qemu 2>/dev/null)" ]; then
    mkdir -p "/etc/pve/nodes/$new_hostname/qemu-server"
    cp /tmp/qemu/* "/etc/pve/nodes/$new_hostname/qemu-server/"
    echo -e "${GREEN}✓ VM config files restored${NC}"
fi

# Cleanup
rm -rf /tmp/qemu

echo -e "\n${GREEN}=== Process completed! ===${NC}"
echo -e "${YELLOW}New hostname:${NC} $new_hostname"
echo -e "\n${YELLOW}Note:${NC} It is recommended to reboot the system for changes to take full effect."
read -p "Would you like to reboot now? (Y/N): " reboot_confirm

if [[ $reboot_confirm =~ ^[Yy]$ ]]; then
    echo "System will reboot in 5 seconds..."
    sleep 5
    reboot
fi
