#
#   DNS or Domain Name System is a service that is responsible for IP address translation
#   to a domain or hostname. It is much easier to connect and remember domain.com, than it
#   is to remember its IP address. When you connect to the internet, your server will connect
#   to an external DNS server (which we would be configuring below) in order to figure out the
#   IP addresses for the website you want to visit.
#
#   If your domain registrar doesn't provide you a free DNS server, then use this function, this way,
#   you would be able to create a custom DNS record, in other words, you are basically hosting your own DNS server
#

#
# BIND CONFIG LOCATIONS
#

named_local=/etc/bind/named.conf.local
named_conf_options=/etc/bind/named.conf.options
named_conf=/etc/bind/named.conf
db_local=/etc/bind/db.local

installBind() {
  #
  #   Berkeley Internet Name Domain or Bind is a service that allows the publication
  #   of DNS information on the internet, it also facilitate the resolving of DNS queries
  #   Since Bind is the most popular DNS program, this is what we would be using.
  #
  if command -v named 2>>"${logfile}" >/dev/null; then
    echo
    echo -e "Bind9 Okay...."
    return 0
  else
    echo -e "Installing Bind9...."
    sudo apt-get -y install bind9 dnsutils bind9-doc 2>>"${logfile}" >/dev/null &
    wait $!
    handleError $? "Couldn't Install Bind9"
    echo -e "Bind9 Installed"
    pause
    spinner
    return 0
  fi
}

dns() {

  # ress
  clear

  installBind

  while :; do

    #
    #   Display DNS Menu
    #
    echo "
1.) Create Primary DNS Server
2.) Create Secondary DNS Server
3.) Add New Zone to DNS server
4.) Edit DNS Zone
5.) Generate a dkim key
6.) Delete DNS Domain
7.) Remove Bind9 and Configurations
8.) Exit

" | boxes -d columns

    #
    #   Prompt for an answer
    #
    echo -e "Answer (or 'q' to quit): \c?"
    read -r ans junk

    #
    #   Empty answers (pressing ENTER) cause the menu to redisplay,
    #   so, this goes back around the loop
    #   We only make it to the "continue" bit if the "test"
    #   program ("[") returned 0 (True)
    #
    [ "$ans" = "" ] && continue

    #
    #   Decide what to do base on user selection
    #

    case $ans in
    1)
      create_primary_dns
      ;;
    2)
      create_secondary_dns
      ;;
    3)
      zone_add
      ;;
    4)
      zone_edit
      ;;
    5)
      generate_dkim_key
      ;;
    6)
      zone_delete
      ;;
    7)
      remove_bind9
      ;;
    8)
      quit 0
      ;;
    q* | Q*)
      quit 0
      ;;
    *) echo -e "Please Enter a Number Between 1 and 8" ;;
    esac
    #
    #   Pause to give the user a chance to see what's on the screen, this way, we won't lose some infos
    #
    pause

  done
}

create_primary_dns() {
  echo "
Caching name server saves the DNS query results locally for a particular period of time.
It reduces the DNS server's roundtrip by saving the queries locally,
therefore it improves the performance and efficiency of the DNS server
" | boxes -d columns

  if yes_no "Do You Want To Configuring Caching name server"; then

    if [ -f "$named_conf_options" ]; then # If file exist
      sudo cp -f "standalone/bind/named.conf.options" /etc/bind/named.conf.options
      systemctl restart bind9
    else
      echo -e "Bind $named_conf_options doesn't exist, moving on anyway"
      return 0
    fi

  else
    echo -e "You don't wanna Configuring Caching name server"
  fi

  #
  # GET THE NAMESERVER DOMAIN
  #
  while :; do # Unless Password Matches, Keep Looping
    echo -e "Enter nameserver domain name, i.e example.com (don't enter www. even if your nameserver starts with ns1, exclude it) \c: "
    read -r nameserver
    echo -e "Enter Again \c?"
    read -r nameserver2
    if [ "$nameserver" != "$nameserver2" ]; then
      echo -e "nameserver domain doesn't match"
    else
      echo -e "Matches, Moving On..."
      break
    fi
  done

  TMPFILE=$(mktemp /tmp/named.conf.local.XXXXXXXX) || exit 1
  sed -e "s/domainname/$nameserver/g" <standalone/bind/named.conf.local >"$TMPFILE"
  sudo cp -f "$TMPFILE" "/etc/bind/named.conf.local"
  rm -r "$TMPFILE"

  #
  # GET SLAVE IP (SECONDARY DNS SERVER)
  #

  echo "
For the following section, if you enter yes, you can specify the list of DNS server (This ensure you can use a secondary or slave dns server)
that are allowed to transfer the domain, enter the server ip like so when asked '10.1.1.10;' don't include the quotes.
If you wanna add more that one, you do: '10.1.1.10; 10.3.3.10; 10.4.4.10;'
" | boxes -d columns

  if yes_no "Do you want to allow transfer to other DNS server ?"; then
    echo -e "Enter list of DNS servers that are allowed to transfer the zone; \c "
    read -r dnsservers

    TMPFILE=$(mktemp /tmp/named.conf.local.XXXXXXXX) || exit 1
    sed -e "s/slaveIP/$dnsservers/g" </etc/bind/named.conf.local >"$TMPFILE"
    sudo cp -f "$TMPFILE" "/etc/bind/named.conf.local"
    rm -r "$TMPFILE"
    systemctl restart bind9
  else
    echo -e "Since you don't want transfer we delete the config"
    sed -i "s/allow-transfer { slaveIP };//g" /etc/bind/named.conf.local
    sed -i "s/also-notify { slaveIP };//g" /etc/bind/named.conf.local
    echo -e "Done"
    systemctl reload bind9
  fi

  echo "
Creating the Zone File Configuration
" | boxes -d columns

  echo -e "What do you want to use for your primary nameserver i.e ns1.$nameserver \c: "
  read -r ns1
  echo -e "What do you want to use for your secondary nameserver i.e ns2.$nameserver \c: "
  read -r ns2

  zone_file=/etc/bind/db.$nameserver
  echo -e "Preparing Zone File\n"
  TMPFILE=$(mktemp /tmp/zone.conf.XXXXXXX) || exit 1
  sudo cp $db_local "$TMPFILE"

  date=$(date +"%Y%m%d")
  rootemail="root.$nameserver"

  # Get Server IP
  ip="$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')"


  echo ";
; BIND data file for $nameserver
;
\$TTL    300
@       IN      SOA      $ns1.          $rootemail. (
                          $date"00"      ; Serial
                          400         ; Refresh
                          400         ; Retry
                          600         ; Expire
                          300 )       ; Negative Cache TTL
;
@       IN      NS      $ns1.
@       IN      NS      $ns2.
@       IN      A       $ip
ns1     IN      A       $ip
ns2     IN      A       $ip
www     IN      A       $ip
ftp     IN      A       $ip
mail    IN      A       $ip
smtp    IN      A       $ip
pop     IN      A       $ip
imap    IN      A       $ip
@       IN      TXT    \"v=spf1 a mx ip4:$ip ~all\"
_dmarc  IN      TXT     \"v=DMARC1; p=quarantine; pct=100\"" >"$TMPFILE"

  sudo cp -f "$TMPFILE" /etc/bind/db."$nameserver"
  sudo chmod 640 /etc/bind/db."$nameserver"

  # remove the tempfile
  rm "$TMPFILE"

  echo -e "Restarting Services\n"
  systemctl restart bind9
  wait $!
  systemctl restart named
  wait $!
  sudo chown root:bind /etc/bind/rndc.key
  wait $!
  progress_bar
  sudo rndc reload
  wait $!

  if command -v ufw 2>>"${logfile}" >/dev/null; then
    echo -e "Opening TCP and UDP port 53."

    sudo ufw allow 53/tcp
    sudo ufw allow 53/udp

  fi

  echo "
Your Custom NameServer is $ns1 and $ns2
The DNS Server Won't Work Until You Change
Your Domain NameServer Via Your Domain's Registrar Website

Also, You Don't Need To Create a Zone For The Custom Nameserver Domain Name
(i.e $nameserver)
Although, You Can Edit The Zone or Add A New Zone Domain Name.
" | boxes -d columns
  return 0

}

create_secondary_dns() {
  #
  # GET THE NAMESERVER DOMAIN
  #
  while :; do # Unless Password Matches, Keep Looping
    echo -e "Enter nameserver domain name, i.e example.com (don't enter www.) \c: "
    read -r nameserver
    echo -e "Enter Again \c?"
    read -r nameserver2
    if [ "$nameserver" != "$nameserver2" ]; then
      echo -e "nameserver domain doesn't match"
    else
      echo -e "Matches, Moving On..."
      break
    fi
  done

  TMPFILE=$(mktemp /tmp/named.conf.local.XXXXXXXX) || exit 1
  sed -e "s/domainname/$nameserver/g" <bind/named.conf.local >"$TMPFILE"
  sudo cp -f "$TMPFILE" "/etc/bind/named.conf.local"
  rm -r "$TMPFILE"

  #
  # GET MASTER IP (SECONDARY DNS SERVER)
  #

  echo "
In the following section, you enter the master Ip like so: '10.66.66.44;' (make sure the semicolon is included and don't include quote)
" | boxes -d columns

  while :; do # Unless Password Matches, Keep Looping
    echo -e "Enter MASTER IP or Primary DNS address address \c: "
    read -r masterIP
    echo -e "Enter Again \c?"
    read -r masterIP2
    if [ "$masterIP" != "$masterIP2" ]; then
      echo -e "masterIP doesn't match"
    else
      echo -e "Matches, Moving On..."
      break
    fi
  done

  TMPFILE=$(mktemp /tmp/named.conf.local.XXXXXXXX) || exit 1
  sed -e "s/masterIP/$masterIP2/g" <bind/slave.conf.local >"$TMPFILE"
  sudo cp -f "$TMPFILE" "/etc/bind/named.conf.local"
  rm -r "$TMPFILE"

  echo -e "Restarting Services\n"
  systemctl restart bind9
  wait $!
  systemctl restart named
  wait $!
  sudo chown root:bind /etc/bind/rndc.key
  wait $!
  progress_bar
  sudo rndc reload
  wait $!
  return 0
}

zone_add() {
  echo
  #
  #   $'\t' is an ANSI-C quoting, this would make us tab the read prompt, instead of relying on echo
  #   I should probably change the rest of the code to follow this syntax
  #

    read -rp "Enter Domain Name (FQDN), e.g, example.com: " websitename
    read -rp "Enter IP address Of Domain (The IP of the Server Hosting The Domain): " DomainIP

    named_local=/etc/bind/named.conf.local
    db_local=/etc/bind/db.local

    TMPFILE=$(mktemp /tmp/named.conf.XXXXXXX) || exit 1
    cat "$named_local" >"$TMPFILE"

    zoneType=master
    if yes_no "Are you currently adding zone via secondary server? "; then
      zoneType=slave
    fi
    #
    #   A zone is a domain name that is referenced in the DNS server.
    #
    echo "
// Forward Zone File of $websitename
zone \"$websitename\" {
    type $zoneType;
    file \"/etc/bind/db.$websitename\";
};" >>"$TMPFILE"

    sudo cp -f "$TMPFILE" $named_local # move the temp to $named_local
    # remove the tempfile
    rm "$TMPFILE"

    zone_file=/etc/bind/db.$websitename

    echo -e "Preparing Zone File\n"
    TMPFILE=$(mktemp /tmp/zone.conf.XXXXXXX) || exit 1
    sudo cp $db_local "$TMPFILE"

    date=$(date +"%Y%m%d")

    rootemail="root@example.com"

    #
    #   Store The Both Custom NameServers
    #
    echo -e "What do you want to use for your primary nameserver i.e ns1.example.com \c: "
    read -r ns1
    echo -e "What do you want to use for your secondary nameserver i.e ns2.example.com \c: "
    read -r ns2

    #
    #   Get Server IP
    #
    ip="$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')"

    echo ";
; BIND data file for $websitename
;
\$TTL    300
@       IN      SOA      $ns1.          $rootemail. (
                         $date"00"      ; Serial
                          400         ; Refresh
                          400         ; Retry
                          600         ; Expire
                          300 )       ; Negative Cache TTL
;
@       IN      NS      $ns1.
@       IN      NS      $ns2.
@       IN      A       $DomainIP
www     IN      A       $DomainIP
ftp     IN      A       $DomainIP
mail    IN      A       $DomainIP
smtp    IN      A       $DomainIP
pop     IN      A       $DomainIP
imap    IN      A       $DomainIP
@       IN      TXT    \"v=spf1 a mx ip4:$DomainIP ~all\"
_dmarc  IN      TXT     \"v=DMARC1; p=quarantine; pct=100\"" >"$TMPFILE"

    if yes_no "Do You Wanna Add an MX Record (Enter No, If you wanna skip instead)"; then
      echo -e "Your MX mailserver \c: "
      read -r mxMailServer
      # This adds the MX records beneath the imap record (thanks to the sed /a option)
      sed -i "/imap/a @       IN      MX      10      $mxMailServer." $TMPFILE

      echo -e "Let's Also Add $mxMailServer alongside the IP to /etc/hosts"
      sed -i "@127.0.0.1@a$DomainIP  $mxMailServer" /etc/hosts
    fi

    sudo cp -f "$TMPFILE" /etc/bind/db."$websitename"
    sudo chmod 640 /etc/bind/db."$websitename"

    # remove the tempfile
    rm "$TMPFILE"

    echo -e "Restarting Services\n"
    service bind9 restart

    if command -v ufw 2>>"${logfile}" >/dev/null; then
    echo -e "Opening TCP and UDP port 53."

    sudo ufw allow 53/tcp
    sudo ufw allow 53/udp
    fi
}

zone_edit() {
  if yes_no "You Are About To Edit $websitename Zone File, is That Correct "; then
    nano /etc/bind/db."$websitename"
    #
    #   The Serial in the zone file is one of the record that would frustrate you like hell
    #   If you are doing things manually, the reason is because it's not enough to just update the
    #   zone file any time we make a change to it, you also need to remember to increase the serial number by at least one.
    #
    #   Without Doing That, There is no way bind would know you updated anything, well, that is how it works
    #   The below code would extract the serial number, delete the word serial (this is actually a comment, not useful)
    #   and then increment it by 1 anytime we make changes, cool right
    #
    #
    oldserial=$(sed -n '6s/; Serial//p' </etc/bind/db."$websitename")
    newserial=$((oldserial + 1))

    sed -i "s/$oldserial/\\t\t\\t\t\\t\t\\t\t\\t\t\\t\t\\t$newserial\\t\t/" /etc/bind/db."$websitename"
    echo -e "Restarting Services\n"
    service bind9 restart

    return 0

  else

    read -rp "Enter Website You Would Like To Edit Its Zone: " zonewebsite

    if [ ! -f /etc/bind/db."$zonewebsite" ]; then
      echo -e "There is no such zone file"
      return 1
    else

      nano /etc/bind/db."$zonewebsite"

      oldserial=$(sed -n '6s/; Serial//p' </etc/bind/db."$websitename")
      newserial=$((oldserial + 1))

      sed -i "s/$oldserial/\\t\t\\t\t\\t\t\\t\t\\t\t\\t\t\\t$newserial\\t\t/" /etc/bind/db."$websitename"
      echo -e "Restarting Services\n"
      service bind9 restart

      return 0

    fi

  fi
}

zone_delete() {
  read -rp "Enter Website of The Zone You Would Want Deleted: " zonewebsite

  if [ ! -f /etc/bind/db."$zonewebsite" ]; then
    echo -e "There is no such zone file"
    return 1
  else

    if yes_no "Are You Sure About The Zone Deletion of $zonewebsite "; then
      TMPFILE=$(mktemp /tmp/delete."$zonewebsite".XXXXX) || exit 1
      sudo cp $named_local "$TMPFILE"
      sed -nie "/\"$zonewebsite\"/,/^\};"'$/d;p;' "$TMPFILE"

      sudo cp -f "$TMPFILE" $named_local

      rm /etc/bind/db."$zonewebsite"

      # remove the tempfile
      rm "$TMPFILE"

      echo -e "Restarting Services\n"
      service bind9 restart

      pause

      return
    fi
  fi
}

generate_dkim_key() {

  installOpendkim # Check if opendkim is installed, if yes, install, if no, quit

  if [ ! -d /etc/opendkim/keys/"$websitename" ]; then # if directory doesn't already exits, then dkim haven't been created for this domain
    sudo mkdir -p /etc/opendkim/keys/"$websitename"

    echo -e "Adding Domain To Signing Table"
    echo -e "*@$websitename\t\t\t\t\tdefault._domainkey.$websitename" >>/etc/opendkim/signing.table

    echo -e "Adding Domain To Key Table"
    echo -e "default._domainkey.$websitename\t\t\t\t $websitename:default:/etc/opendkim/keys/$websitename/default.private" >>/etc/opendkim/key.table

    echo -e "Adding Domain to Trusted Hosts File"
    echo "*.$websitename" >>/etc/opendkim/trusted.hosts # Any domain that originates from this would be trusted

    echo -e "Generating Public and Private Keys For The Domain"
    sudo opendkim-genkey -b 2048 -d "$websitename" -D /etc/opendkim/keys/"$websitename" -s default -v
    sudo chown opendkim:opendkim /etc/opendkim/keys/"$websitename"/default.private

    echo "
Two files have been generated: The first is /etc/opendkim/keys/$websitename/default.private
and the second is /etc/opendkim/keys/$websitename/default.txt
" | boxes -d ian_jones

    pause
    # sed -n '/p=/,$ p' default.txt           --- This extract the key starting from p=
    # sed 's/"//g'                            --- This removes any quotes
    # sed s/'\s'//g''                         --- This removes any spaces
    # sed '\~^[[:blank:]]*//~d; s~);.*~~'     --- Deletes character -> ");" all the way down the file ;)
    # tr -d '[:space:]'                       --- Just so we are sure, this deletes remove space characters, form feeds, new-lines, carriage returns, horizontal tabs, and vertical tabs.
    dkimKey="\"v=DKIM1;k=rsa;$(sed -n '/p=/,$ p' /etc/opendkim/keys/$websitename/default.txt | sed 's/"//g' | sed s/'\s'//g'' | sed '\~^[[:blank:]]*//~d; s~);.*~~' | tr -d '[:space:]')\""
    dkim_zone="default._domainkey\t\tIN\t\tTXT\t\t$dkimKey"

    echo "
The dkim key is: $dkimKey
" | boxes -d columns

    if yes_no "Add dkim to zone file (Enter Yes, if dns is hosted on this server or No, to copy the dkim key)"; then
      if [ ! -f /etc/bind/db."$websitename" ]; then
        echo -e "There is no such zone file"
        return 1
      else
        oldserial=$(sed -n '6s/; Serial//p' </etc/bind/db."$websitename")
        newserial=$((oldserial + 1))
        sed -i "s/$oldserial/\\t\t\\t\t\\t\t\\t\t\\t\t\\t\t\\t$newserial\\t\t/" /etc/bind/db."$websitename"
        echo -e "$dkim_zone" >>/etc/bind/db."$websitename"
        echo -e "Restarting bind9 Services\n"
        service bind9 restart
        return 0
      fi

    else
      echo "
The key is: $dkimKey
Add it to your dns settings like so:
$dkim_zone
" | boxes -d ian_jones
      return 0
    fi
    return 0
  fi
}

remove_bind9() {
  if yes_no "Are You Sure You Want To Remove Bind9"; then
    echo -e "Getting Ready To Remove Bind9..."
    if yes_no "Do You Want To Keep Bind9 Configuration? "; then
      sudo apt-get -y remove bind9* 2>>"${logfile}" >/dev/null &
      wait $!
      handleError $? "Couldn't Remove Bind9"
      echo -e "Bind9 Removed But Configurations is left intact in /etc/bind"
      exit 1
    else
      echo -e "Removing Bind9 and Its Configurations"
      pids=() # storing all the process ids into an array
      sudo apt-get -y remove bind9* 2>>"${logfile}" >/dev/null &
      pids+=($!)
      sudo apt-get -y autoremove bind9 2>>"${logfile}" >/dev/null &
      pids+=($!)
      sudo apt-get -y purge bind9 2>>"${logfile}" >/dev/null &
      pids+=($!)
      # Loop through the pid and exit if one of the above fails
      for pid in ${pids[*]}; do
        if ! wait "$pid"; then
          handleError $? "Couldn't Completely Remove bind9"
        fi
      done
      echo -e "Bind9 and Configurations Removed"
      exit 1
    fi
  fi
}
