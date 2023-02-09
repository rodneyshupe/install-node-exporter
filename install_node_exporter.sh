#!/usr/bin/env bash

# Function to check dependancies
checkfor () {
    command -v $1 >/dev/null 2>&1 || { 
        echo >&2 "ERROR: $1 required. Please install and try again."; 
        exit 1; 
    }
}

# Check dependancies
checkfor "curl"
checkfor "tar"

#Check if script is being run as root
if [ "$(id -u)" != "0" ]; then
   echo "ERROR: This script must be run as root" 1>&2
   exit 1
fi

if /sbin/init --version >/dev/null 2>&1; then
    sudo service node-exporter stop >/dev/null 2>&1
elif /bin/systemd --version >/dev/null 2>&1; then
    sudo systemctl start node_exporter.service >/dev/null 2>&1
elif [ -d /usr/lib/opkg/ ]; then

else
    echo "Unsupported OS."
    #TODO: Ask if docker should be used.
    exit 1
fi

if [ -d /usr/lib/opkg ]; then
    # Install openWRT version.  Note this version the offical version and has a hard coded set of collectors.
    opkg update

    opkg install prometheus-node-exporter-lua \
    prometheus-node-exporter-lua-nat_traffic \
    prometheus-node-exporter-lua-netstat \
    prometheus-node-exporter-lua-openwrt \
    prometheus-node-exporter-lua-wifi \
    prometheus-node-exporter-lua-wifi_stations

    if [ ! -f /etc/config/prometheus-node-exporter-lua ]; then
        curl --insecure --location --silent "https://raw.githubusercontent.com/rodneyshupe/install-node-explorer/main/prometheus-node-exporter-lua" --output /etc/config/prometheus-node-exporter-lua
    fi
    /etc/init.d/prometheus-node-exporter-lua restart
else
    #Download Latest node_exporter
    RELEASE_LINK="$(curl --silent https://github.com/prometheus/node_exporter/releases | grep --basic-regexp '/prometheus/node_exporter/releases/download/v.*/node_exporter.*linux-armv6\.tar\.gz' --only-matching --max-count=1)"
    curl --insecure --location --silent "https://github.com${RELEASE_LINK}" --output node_exporter.tar.gz
    mkdir -p node_exporter
    tar --extract --gunzip --file="node_exporter.tar.gz"  --strip-components=1 -C node_exporter

    sudo cp node_exporter/node_exporter /usr/local/bin/
    sudo chmod +x /usr/local/bin/node_exporter
    rm -R node_exporter
    rm node_exporter.tar.gz

    # Setup Service
    sudo useradd -m -s /bin/bash node_exporter 2>/dev/null
    sudo mkdir -p /var/lib/node_exporter
    sudo chown -R node_exporter:node_exporter /var/lib/node_exporter

fi

if /sbin/init --version >/dev/null 2>&1; then
    # upstart
    curl --insecure --location --silent "https://raw.githubusercontent.com/rodneyshupe/install-node-explorer/main/node_exporter.conf" --output "node-exporter.conf"
    sudo cp node-exporter.conf /etc/init

    rm node-exporter.conf

    sudo initctl reload-configuration

    sudo rm /etc/init/node-exporter.override 2>/dev/null

    sudo service node-exporter start >/dev/null

    status_cmd="service node-exporter status"
elif /bin/systemd --version >/dev/null 2>&1; then
    # systemd
    curl --insecure --location --silent "https://raw.githubusercontent.com/rodneyshupe/install-node-explorer/main/node-exporter.service" --output "node_exporter.service"
    sudo cp node_exporter.service /etc/systemd/system/

    rm node_exporter.service

    sudo systemctl daemon-reload 
    sudo systemctl enable node_exporter.service >/dev/null
    sudo systemctl start node_exporter.service

    status_cmd="systemctl status node_exporter.service"
else
    echo "FATAL ERROR"
    exit 500
fi

echo "node_exporter Installed."
echo
echo "Check service status with: sudo ${status_cmd}"
echo "Test with: curl http://localhost:9100/metrics"