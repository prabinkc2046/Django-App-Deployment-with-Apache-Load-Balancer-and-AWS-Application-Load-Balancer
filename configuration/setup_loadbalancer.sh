#!/bin/bash
# This script is to run in ubuntu linux
# Require the list of IP addresses running behind the apacher server
#Provide the list of backend server IP

# Variables
iplist=("192.53.169.242:8000" "192.53.169.154:8000")
service_name="apache2.service"
config_file="lb.conf"
path_to_apache_config_dir="/etc/apache2/sites-available"
path_to_config_file="/etc/apache2/sites-available/$config_file"
server_ip=$(ip add show | grep "inet" | awk 'NR == 3 {print $2}' | awk -F/ '{print $1}')

# function to check if the exit code is greater than 0 in order to  exit and not proceeding further
check_for_err(){
	local success_msg="$1"
	local fail_msg="$2"
	
	if [ "$?" -ne 0 ]; then
		echo ""
		echo "$fail_msg"
		echo "Exiting..."
		echo ""
		exit
	else
		echo ""
		echo "$success_msg"
		echo ""
	fi
}

# Use DEBIAN_FRONTEND non-interactive to prevent the prompts
export DEBIAN_FRONTEND=noninteractive

# Update the linux operating system
apt update -y
check_for_err "System update is complete." "Error while updating the system."

# Install apache and enable it
apt install apache2 -y
if systemctl enable apache2.service; then
	echo "apache service enabled successfully."
else
	echo "Error in enabling apache service. Exiting."
fi

# Enable necessary modules to set up load balancing function
modules=("proxy" "proxy_http" "proxy_balancer" "lbmethod_byrequests")
for mod in "${modules[@]}"; do
	a2enmod "$mod"
	check_for_err "Enabling $mod is successful" "Error while enabling $mod"		
done


# Create configuration to make apache as a load balancing server
cd "$path_to_apache_config_dir"
cat > "$config_file" << EOF
<VirtualHost *:80>
	ServerName $server_ip
	<Proxy balancer://mycluster>
	    #BalancerMemberWillBeListedBelow 
	</Proxy>

	ProxyPass / balancer://mycluster/
	ProxyPassReverse / balancer://mycluster/

	ErrorLog ${APACHE_LOG_DIR}/error.log
	CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
EOF
check_for_err "$config_file created  at $path_to_apache_config_dir successfully." "Error in creating a $config_file at $path_to_apache_config_dir"

# Updating the backend servers IP in the apache config file
for ip_port in "${iplist[@]}"; do
	sed -i "/#BalancerMemberWillBeListedBelow/a \ \ \ \ \ \ \ \BalancerMember http://$ip_port" $path_to_config_file
done

check_for_err "Successfully updating the IPs of backend server" "Error in updating the balancer member ip"

# Enable the config
a2ensite "$config_file"
check_for_err "$config_file is enabled successfully." "Error in enabling the site: $config_file."

# Restart apache service
systemctl restart "$service_name"
check_for_err "$service_name  is enabled successfully." "Error in restarting $service_name"
