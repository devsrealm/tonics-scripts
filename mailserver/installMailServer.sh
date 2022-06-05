#
# Well, this is a long time coming, and here we are....
# This function would automate a full blown secure mail-server. Ask any sysadmin about building a mailServer from scratch
# and they'll tell you how painful the process is, you don't wanna mess with this sort of stuff if you are no geeky (I am not ;))
#
# So, this function would automate the installation of:
#
# Postfix (used for sending and receiving mails). Source: http://www.postfix.org/
# Dovecot( a POP and IMAP server that manages local mail directories and allows users to log in and download their mail): https://www.dovecot.org/
# Clam Antivirus: For detecting viruses (this tool can be resource hungry). Source: https://www.clamav.net/
# SpamAssassin: For filtering out spam. Source: https://spamassassin.apache.org/
# Postgrey: This cut off spam, the way it works is it require unknown delivers to wait for a while and resend when it detects any non
#           RFC compliant MTAS, it rejects the email with a try again later error, most spam won't bother trying again, this can help in reducing spam
#           Source: https://wiki.centos.org/HowTos/postgrey
#
# Postfix Admin: a web admin panel for administering mail users and domains. https://github.com/postfixadmin/postfixadmin
#
# SSHGUARD: A daemon that protects SSH and other services against brute-force attacks, similar to fail2ban.
#           sshguard works by monitoring /var/log/auth.log, syslog-ng or the systemd journal for failed login attempts.
#           For each failed attempt, the offending host is banned from further communication for a limited amount of time.
#           The default amount of time the offender is banned starts at 120 seconds,
#           and is increases by a factor of 1.5 every time it fails another login.
#           sshguard can be configured to permanently ban a host with too many failed attempts.
#
mail_server() {
  askForOnlySiteName
  mailHostName=$(hostname)
  echo " Your Current Hostname is ${mailHostName}"

  if yes_no "Do You Want To Change It To $websitename"; then
    echo "$websitename" >/etc/hostname
    echo -e " Hostname Changed To $websitename\n"
    # Let's Install PHP and MariaDB if not already installed
    installMariadb
    installPhp
  else
    echo "Keeping ${mailHostName}"
    # Let's Install PHP and MariaDB if not already installed
    installMariadb
    installPhp
  fi # yes_no prompt

  ip="$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')"
  echo "I detected $ip as your server IP address"

  if yes_no "Is That Correct? (Most of The Time, That would Be Your Server IP)"; then
    echo -e "IP identified as $ip\n"
  else
    while :; do # Unless IP is Valid...We Keep Looping
      read -rp "Enter The Correct Server IP Address: " NewIP
      ip="$(ip route get "$NewIP" >/dev/null 2>&1)"
      exit_status=$?
      if [ $exit_status -eq 1 ]; then
        echo "IP Address is Invalid"
      else
        ip=$NewIP
        echo -e "IP identified as $ip\n"
        break
      fi # END --- if [ $exit_status -eq 1 ]; then
    done
  fi # END -- "Is That Correct? (Most of The Time, That would Be Your Server IP)";

  #
  #   Remove both occurrences of default_server, servername and point
  #   the root directory to the new website root for your newly copied config.
  #
  #   mktemp will create the file or exit with a non-zero exit status,
  #   this way, you can ensures that the script will exit if mktemp is unable to create the file.
  #

  TMPFILE=$(mktemp /tmp/default.nginx.XXXXXXXX) || exit 1
  sed -e "s/domain.tld/$websitename www.$websitename/g" -e "s/\/var\/www\/wordpress/\/var\/www\/$websitename/" <mailserver/pfa_ngx_serverblock >"$TMPFILE"
  sudo cp -f "$TMPFILE" "$site_available"/"$websitename"

  # remove the tempfile
  rm "$TMPFILE"

  # Create a directory for the root directory if it doesn't already exist
  if [ ! -d /var/www/"$websitename" ]; then
    sudo mkdir -p /var/www/"$websitename"
  fi

  # Nginx comes with a default server block enabled (virtual host), let’s remove the symlink, we then add the new one
  if [ -f "$site_enabled"/default ]; then
    sudo unlink "$site_enabled"/default 2>>"${logfile}" >/dev/null &
    wait $!
    handleError $? "Couldn't Unlink $site_enabled/default"
  fi

  #   Check if symbolic link exist for the mailserver hostname already
  if [ ! -f "$site_enabled"/"$websitename" ]; then
    sudo ln -s "$site_available"/"$websitename" /etc/nginx/sites-enabled/ 2>>"${logfile}" >/dev/null &
  fi

  # RELOAD NGINX
  reloadNginx

  # Installing Mailserver
  echo -e "Installing Mailserver"
  export DEBIAN_FRONTEND=noninteractive # This disable any interactive options that postfix might bring up
  # So, we set it ourselves Programmatically
  debconf-set-selections <<<"postfix postfix/mailname string $websitename"
  debconf-set-selections <<<"postfix postfix/main_mailer_type string 'Internet Site'"
  #
  # The below installs:
  #
  # bsd-mailx dovecot-core dovecot-imapd dovecot-pop3d libexttextcat-2.0-0
  # libexttextcat-data liblockfile-bin liblockfile1 postfix procmail
  #
  sudo apt-get install -y mail-server^ 2>>"${logfile}" >/dev/null &
  spinner

  echo -e "Installing Additional Package To Control Spam, Enhance Security and database support (It might take a whle)"

  sudo apt-get install -y postfix-mysql dovecot-mysql postgrey amavisd-new \
    clamav clamav-daemon spamassassin libdbi-perl libdbd-mysql-perl \
    postfix-policyd-spf-python libnet-dns-perl libmail-spf-perl \
    pyzor razor arj cabextract lzop nomarch p7zip-full rpm2cpio tnef \
    unzip unrar-free zip 2>>"${logfile}" >/dev/null &
  spinner

  echo -e "Enter MariaDB User (This could be the root user if you haven't created any user): \c"
  read -r mariadbUser
  echo -e "Enter MariaDB Password: \c"
  read -rs mariadbPass

  # Until the user and password is valid in mariadb, keep looping
  until mysql -sfu "$mariadbUser" -p"$mariadbPass" -e ";"; do
    echo "Password or User Incorrect
  " | boxes -d columns
    echo
    echo -e "Enter MariaDB User: \c"
    read -r mariadbUser
    echo -e "Enter MariaDB Password: \c"
    read -rs mariadbPass
  done

  echo -e "\nCreating The 'mail' Database"
  echo -e "Enter a Strong Password for Your 'mail' User: \c"
  read -rs mailUserPassword # This is a password for the mail user

  TMPFILE=$(mktemp /tmp/database_for_mail.XXXXXXXXXX.sql) || exit 1
  sed -e "s/123456789/$mailUserPassword/" <mailserver/database_for_mail.sql >"$TMPFILE"
  mysql -sfu "$mariadbUser" -p"$mariadbPass" <"$TMPFILE"
  # remove the tempfile
  rm "$TMPFILE"
  echo -e "Database 'mail' created \n"

  # INSTALLING POSTFIX ADMIN
  echo -e "Now, Let's Install Postfix Admin, So, You Can Manage Users Virtually"
  PFAVER=3.3.9
  wget -q https://github.com/postfixadmin/postfixadmin/archive/refs/tags/postfixadmin-${PFAVER}.tar.gz
  wait $!
  tar xzf postfixadmin-${PFAVER}.tar.gz

  # Moving PFA and Changing Permission
  echo -e "Moving PFA and Changing Permission"
  sudo mv postfixadmin-postfixadmin-${PFAVER}/* "/var/www/$websitename"
  rm -f postfixadmin-postfixadmin-${PFAVER}.tar.gz
  mkdir "/var/www/$websitename/templates_c"

  sudo useradd postfixadmin
  usermod -a -G "postfixadmin" www-data

  sudo chown -R postfixadmin:postfixadmin "/var/www/$websitename"
  touch "/var/www/$websitename/config.local.php"

  mkdir /run/postfixadmin
  sudo cp -f nginx/pfaspool.conf "/etc/php/8.0/fpm/pool.d/postfixadmin.conf"

  # Creating PFA USER and Importing The New Database
  #  echo -e "Creating The 'mail(Postfix Admin)' Database"
  #  echo -e "Enter a Strong Password for Your 'mail' User: \c"
  #  read -rs pfaPassword # This is a password for the pfa(Postfix Admin) user
  #
  #  TMPFILE=$(mktemp /tmp/postfix_admin_database.XXXXXXXXXX.sql) || exit 1
  #  sed -e "s/123456789/$pfaPassword/" <mailserver/postfix_admin_database.sql >"$TMPFILE"
  #  mysql -sfu "$mariadbUser" -p"$mariadbPass" <"$TMPFILE"
  #  # remove the tempfile
  #  rm "$TMPFILE"
  #  echo -e "Database 'mail' created \n"

  # Overwriting PFA Config
  TMPFILE=$(mktemp /tmp/config.local.XXXXXXXX) || exit 1
  sed -e "s/yourpostfixadminurl/$websitename/g" -e "s/123456789/$mailUserPassword/g" -e "s/devsrealm.com/$websitename/g" <mailserver/config.local.php >"$TMPFILE"
  sudo cp -f "$TMPFILE" "/var/www/$websitename/config.local.php"

  #   Check if symbolic link exist for the mailserver hostname already
  if [ -f "$site_enabled"/"$websitename" ]; then
    # Secure Server Hostname With Certbot
    issueSSLCert
  fi

  systemctl restart nginx
  systemctl restart php8.0-fpm

  echo "Now, Access https://$websitename/setup.php and complete the setup: (Select the address and use CTRL+Insert to copy it, do not use CTRL+C)
Choose a setup password and generate a hash of that password, copy the hash and paste it below
" | boxes -d columns

  read -rs pfaPassHash
  sed -i "s@passwordHash@$pfaPassHash@" "/var/www/$websitename/config.local.php"

  pause
  echo "Once you are done, reload the page and create a super user account" | boxes -d columns
  pause

  echo "Now, create virtual domains, then the users. an example of domian name is example.com.
You can have emails on your domain using the same server. Goto Domains List -> New Domain to add a domain
" | boxes -d columns

  pause

  echo -e "Creating User 'vmail' to Handle Virtual Mail Directories"
  sudo groupadd -g 5050 vmail # The number is the group id, same applies to useradd
  useradd -r -u 5050 -g mail -d /var/mail/vmail -s /sbin/nologin -c "Virtual maildir handler" vmail
  chmod 770 /var/mail/vmail
  chown vmail:mail /var/mail/vmail
  echo -e "User vmail created"

  echo "Configuring Dovecot: Doing This Would Ensure You Can Read Mail From Anywhere, mobile,laptop,etc
" | boxes -d columns

  pause

  echo -e "Setting Postmaster email in dovecot 15-lda.conf"
  TMPFILE=$(mktemp /tmp/15-lda.conf.XXXXXXXX) || exit 1
  sed -e "s/example.com/$websitename/g" <mailserver/dovecot/15-lda.conf >"$TMPFILE"
  sudo cp -f "$TMPFILE" "/etc/dovecot/conf.d/15-lda.conf"

  echo -e "Adding The Postfix User and Group in dovecot 10-master.conf"
  sudo cp -f mailserver/dovecot/10-master.conf /etc/dovecot/conf.d/10-master.conf

  echo -e "Configuring SSL options in dovecot 10-ssl.conf"
  openssl dhparam -out /etc/dovecot/dh.pem 4096
  TMPFILE=$(mktemp /tmp/10-ssl.conf.XXXXXXXX) || exit 1
  sed -e "s/websitename/$websitename/g" <mailserver/dovecot/10-ssl.conf >"$TMPFILE"
  sudo cp -f "$TMPFILE" "/etc/dovecot/conf.d/10-ssl.conf"

  echo -e "Configuring Mail Option in dovecot 10-mail.conf"
  sudo cp -f mailserver/dovecot/10-mail.conf /etc/dovecot/conf.d/10-mail.conf

  echo -e "Copying The Dovecot sql conf file"
  sudo cp -f mailserver/dovecot/dovecot-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext

  echo -e "Adding Mail Password in /etc/dovecot/dovecot-sql.conf.ext"
  sed -i "s/mailpassword/$mailUserPassword/g" /etc/dovecot/dovecot-sql.conf.ext

  echo -e "Finalizing the dovecot configuration by Setting the auth in 10-auth.conf"
  sudo cp -f mailserver/dovecot/10-auth.conf /etc/dovecot/conf.d/10-auth.conf

  chown -R vmail:dovecot /etc/dovecot
  chmod -R o-rwx /etc/dovecot

  echo "Configuring Amavis, ClamAV, and SpamAssassin: This helps in mitigating spam" |
    boxes -d columns
  pause

  sudo adduser clamav amavis
  sudo cp -f mailserver/amavis/15-content_filter_mode /etc/amavis/conf.d/15-content_filter_mode
  sudo cp -f mailserver/spamassassin/default /etc/default/spamassassin
  sudo cp -f mailserver/amavis/50-user /etc/amavis/conf.d/50-user
  sed -i "s@mailpassword@$mailUserPassword@" /etc/amavis/conf.d/50-user


  sudo systemctl stop clamav-freshclam.service
  freshclam # updating ClamAV database
  systemctl restart clamav-daemon
  wait $!
  systemctl restart amavis
  wait $!
  systemctl restart spamassassin
  wait $!
  systemctl enabled spamassassin
  wait $!

  echo "Configuring Postfix: Postfix handles incoming mail via the SMTP protocol
We ensure Postfix pass off incoming mail to the spam/virus checkers before passing it on to Dovecot for delivery,
and to communicate with Dovecot in order to authenticate virtual users who are connecting over SMTP in order to to send mail.
" |
    boxes -d columns

  pause

  echo -e "Generating Unique Diffie-Helman Key\n"
  openssl dhparam -out /etc/ssl/private/dhparams.pem 2048
  chmod 600 /etc/ssl/private/dhparams.pem

  # A directory that would contain the postfix sql and we copy the sql template in there
  mkdir -p /etc/postfix/sql
  cp -f mailserver/postfix/sql* /etc/postfix/sql
  find /etc/postfix/sql/*.cf -type f -exec sed -i "s/mailpassword/$mailUserPassword/g" {} \;

  # Copy the header_check also: Use for removing certain headers when relaying emails
  cp -f mailserver/postfix/header_checks /etc/postfix

  # Now copy the main.cf
  TMPFILE=$(mktemp /tmp/main.cf.XXXXXXXX) || exit 1
  sed -e "s/websitename/$websitename/g" <mailserver/postfix/main.cf >"$TMPFILE"
  sudo cp -f "$TMPFILE" "/etc/postfix/main.cf"

  # Copy the master.cf
  sudo cp -f mailserver/postfix/master.cf "/etc/postfix/master.cf"
  postconf -e 'virtual_mailbox_limit = 0'

  echo "Installing DKIM: DKIM or Domain Keys Identified Mail is an email authentication method
that allows mail services to check that an email was indeed sent and authorized by the owner of that domain.
In order to achieve this, you give the email a digital signature.
This DKIM signature is a header that is added to the message and is secured with encryption.
" | boxes -d columns

  pause

  installOpendkim
  # Add Postfix to opendkim group
  sudo gpasswd -a postfix opendkim

  # Restart Every Every
  echo -e "Restarting Services\n"
  systemctl restart opendkim
  systemctl restart postfix
  systemctl restart spamassassin
  systemctl restart clamav-daemon
  systemctl restart amavis
  systemctl restart dovecot
  systemctl restart nginx
  systemctl restart php8.0-fpm

echo "If No Error Occurred and You got To This Stage, CONGRATULATIONS!!! 😴, It's Has Been A Long Journey
Let's Install SSHGUARD To Protects Hosts From Brute-Force Attacks Against SSH and Other Services
" | boxes -d ian_jones
  apt-get -y install sshguard 2>>"${logfile}" >/dev/null &
  wait $!
  cp -f sshguard/sshguard.conf /etc/sshguard/sshguard.conf
  echo -e "Done...."

  #
  # A NIS (Network Information System) allows "a group of machines within an NIS domain to share a common set of configuration files."
  # Basically, if you're running email servers on more than one box, you can share config files between them.
  #
  # Since we are just running a single server, we can remove the nis:mail.aliases like so:
  postconf -e "alias_maps = hash:/etc/aliases"
  service postfix restart

echo "
#
# Hostname
#
$(hostname)

#
# IP
#
$ip

#
# NGINX ServerBlock File
#
$site_available/$websitename

#
# PostfixAdmin Directory
#
/var/www/$websitename

#
# MariaDB Info
#
Database=mail
User=mail
UserPassword=$mailUserPassword

#
# PostfixAdmin Login Address
#
https://$websitename/login

#
# Virtual Mail Directory
#
/var/mail/vmail

#
# POP3 Settings - To login usin email clients POP3, you first of all need to create a mailbox in Postfixadmin
#
username=mailboxusername
pass=mailboxpass
port=995
POP Server=$(hostname)

#
# SMTP Server Settings
#
username=mailboxusername
pass=mailboxpass
port=465
SMTP Server=$(hostname)
">> installationDetails.txt

echo "LOGIN DETAILS IS IN installationDetails.txt, GoodBye ;)
" | boxes -d ian_jones

  return 0
}