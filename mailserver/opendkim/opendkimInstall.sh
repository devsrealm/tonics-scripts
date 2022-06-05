installOpendkim() {
  if command -v opendkim 2>>"${logfile}" >/dev/null; then
    echo
    echo -e "Opendkim is available\n"
  else
    if yes_no "Install Opendkim"; then
      sudo apt-get -y install opendkim opendkim-tools 2>>"${logfile}" >/dev/null &
      spinner
      # Replace websitename.com with actual name and copy relevant opendkim config
      sudo cp -f "mailserver/opendkim/opendkim.conf" "/etc/opendkim.conf"
      sudo cp -f mailserver/opendkim/opendkim.default "/etc/default/opendkim"

      echo -e "Creating Signing Table File and Folders"
      sudo mkdir /etc/opendkim
      sudo mkdir /etc/opendkim/keys
      touch /etc/opendkim/signing.table

      echo -e "Change The Permissions and Role"
      sudo chown -R opendkim:opendkim /etc/opendkim
      sudo chmod go-rw /etc/opendkim/keys

      echo -e "Creating a Key Table File"
      touch /etc/opendkim/key.table

      echo -e "The Trusted Hosts File"
      touch /etc/opendkim/trusted.hosts
      cp -f mailserver/opendkim/trusted.hosts /etc/opendkim/trusted.hosts

      spinner
      pause_webserver Opendkim
    else
      echo
      return 1 # They didn't wanna install Opendkim
    fi
    return 0
  fi
}