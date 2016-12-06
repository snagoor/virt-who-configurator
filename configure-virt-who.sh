function read_user_inputs()
{
read -p "Provide Satellite Admin Username : " SAT_USER
read -s -p "Provide Satellite Admin Password : " SAT_PASSWD
echo -e "\nPlease provide the details below to configure VIRT-WHO on your Red Hat Satellite 6 Server\n"
detect_virt-who_installation
echo -e "Select the Hypervisor backend to configure VIRT-WHO\n"
echo -e "\t(1). VMware vSphere"
echo -e "\t(2). RHEV (Red Hat Enterprise Virtualization)"
echo -e "\t(3). LibVirt (KVM)\n"
echo -e "\t(3). Microsoft Hyper-V\n"
read -p "Answer : " VW_BACKEND

if [ $VW_BACKEND -gt 0 ] && [ $VW_BACKEND -lt 5 ]; then
   case $VW_BACKEND in
     1)
        VW_BACKEND_SELECTED="esx"
        read -p "Provide VMware vSphere FQDN / IP Address : " $SERVER_FQDN
        ;;
     2)
        VW_BACKEND_SELECTED="rhevm"
        read -p "Provide RHEV-M Server FQDN / IP Address : " $SERVER_FQDN
        $SERVER_FQDN="https://$SERVER_FQDN:443"
        ;;
     3)
        VW_BACKEND_SELECTED="libvirt"
        # read -p "Provide VMware vSphere FQDN : " $VMWARE_FQDN
        ;;
     4)
        VW_BACKEND_SELECTED="hyperv"
        read -p "Provide Hyper-V Server FQDN / IP Address : " $SERVER_FQDN
        ;;
   esac
fi
org_listing
lifecycle_env_listing
read -p "Would you like to encrypt the passwords in virt-who configuration files ? [Y/N] : " VW_ENCRYPT_ANS
if [ "$VM_ENCRYPT_ANS" == "Y" ] || [ "$VM_ENCRYPT_ANS" == "y" ]; then
   encrypt_passwords
else
   read -p "Please provide UserName for $VW_BACKEND_SELECTED : " VW_USERNAME
   read -s "Please provide Password for $VW_BACKEND_SELECTED : " VW_PASSWORD
fi

write_virt-who_config_file

#[[ -z "$ORG" ]] && echo -e "\nYou didn't provide any input for Organization, setting default value" && ORG="Default Organization"
#[[ -z "$LOCATION" ]] && echo -e "\nYou didn't provide any input for Location, setting default value" && LOCATION="Default Location"
#[[ -z "$ADMIN_USER" ]] && echo -e "\nYou didn't provide any input for Admin Username, setting default value" && ADMIN_USER="admin"
#[[ -z "$ADMIN_PASS" ]] && echo -e "\nYou didn't provide any input for Admin Password, setting default value\n" && ADMIN_PASS="redhat"

echo -e "VIRT-WHO would be configured with the following values"
echo -e "\n===================================================================="
echo "Initial Organization : $ORG"
echo "Initial Location     : $LOCATION"
echo "Admin User           : $ADMIN_USER"
echo "Admin Password       : $ADMIN_PASS"
echo -e "\n====================================================================\n"
}

function write_virt-who_config_file
{
cat > /etc/virt-who.d/virt-who-config.conf << EOF
[virt-who]
type=$VW_BACKEND_SELECTED
server=$SERVER_FQDN
owner=$ORG_SELECTED
env=$LCE
username=admin
password=password
rhsm_username=admin
rhsm_password=password
EOF
}

function encrypt_passwords()
{
read -p "Please provide UserName for the $VW_BACKEND_SELECTED : " VW_USERNAME
echo -e "Please provide password for $VW_BACKEND_SELECTED for encrypting"
VW_EPASS_BACKEND=$(virt-who-password) 2>&1
echo -e "Please provide password for $SAT_USER for encypting, when prompted"
VW_EPASS_SAT=$(virt-who-password) 2>&1
}

function detect_virt-who_installation()
{
VW_AVAILABLE=0
VW_AVAIALABLE=$(rpm -qa | grep virt-who | wc -l)
if [ $VW_AVAILABLE -eq 0 ]; then
   read -p "virt-who package is not installed on the system. Would you like to install it ? [Y / N] : " VW_INSTALL_ANS
   if [ "$VW_INSTALL_ANS" == "Y" ] || [ "$VW_INSTALL_ANS" == "y" ]; then
      yum install virt-who -y
   else
      echo -e "\nvirt-who package installation is mandatory for configuration. Please install the package manually or re-run the script and select Y when prompted for installation"
      echo -e "\nExiting without any changes\n"
      exit 9
   fi
fi
}
function lifecycle_env_listing()
{
LCE_NAMES=($(hammer --csv -u admin -p redhat lifecycle-environment list --organization-label "$ORG_SELECTED" | grep -v Name | cut -d, -f2))
j=1
echo -e "\n"
for LCE_DATA in "${LCE_NAMES[@]}"
do
  echo -e "\t\t\t$j. $LCE_DATA"
  j=$(($j + 1))
done
echo -e "\n"
read -p "Select the Lifecycle Environment from above : " LCE_SELECTED
if [ $LCE_SELECTED -lt 1 ] && [ $LCE_SELECTED -ge $j ]; then
   read -p "Invalid Selection, Would you like to re-select the correct Lifecycle Environment ? [Y/N] : " LCE_CORRECT
   if [ "$LCE_CORRECT" == "Y" ] || [ "$LCE_SELECT" == "y" ]; then
      lifecycle_env_listing
   else
      echo -e "\nWrong Option Selected, Exiting \n"
      exit 98
   fi
fi
}

function org_listing()
{
#ORG_NAMES=$(curl -k -s -u "$SAT_USER":"$SAT_PASSWD" https://$(hostname -f)/api/organizations | python -mjson.tool | grep '"name"' | cut -d ":" -f2| tr -d , | tr -d '"')
ORG_NAMES=($(hammer --csv -u admin -p redhat organization list | grep -v Name | cut -d, -f3))
i=1
echo -e "\n"
for ORG_DATA in "${ORG_NAMES[@]}"
do
  echo -e "\t\t\t$i. $ORG_DATA"
  i=$(($i + 1))
done
echo -e "\n"
read -p "Select the Organization that you wish VIRT-WHO to report Host-Guest mappings from above : " ORG_SELECT
if [ $ORG_SELECT -lt 1 ] && [ $ORG_SELECT -ge $i ]; then
   read -p "Invalid Selection, Would you like to re-select the correct Organization ? [Y/N] : " ORG_CORRECT
   if [ "$ORG_CORRECT" == "Y" ] || [ "$ORG_SELECT" == "y" ]; then
      org_listing
   else
      echo -e "\nWrong Option Selected, Exiting \n"
      exit 99
   fi
fi
}
read_user_inputs
