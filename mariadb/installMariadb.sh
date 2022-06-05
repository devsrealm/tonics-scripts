#
#   installMariadb()
#
#   This Downloads and Configure WordPress or ClassicPress
#
installMariadb() {

  #
  # Let's Install PHP and Mariadb
  #

  if command -v mariadb 2>>"${logfile}" >/dev/null; then
    echo
    echo -e "Mariadb is available\n"

    #
    #   Ask if it should be created
    #
  else
    echo -e "Mariadb Seems To Be Missing\n"
    if yes_no "Install Mariadb"; then

      echo -e "Installing MariaDB Server"

      sudo apt-get -y install software-properties-common dirmngr apt-transport-https 2>>"${logfile}" >/dev/null &
      wait $!

      sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc' 2>>"${logfile}" >/dev/null &
      wait $!

      sudo add-apt-repository "deb [arch=amd64,i386,arm64,ppc64el] https://mirror.marwan.ma/mariadb/repo/10.6/debian $(lsb_release -cs) main"
      wait $!

      sudo apt update 2>>"${logfile}" >/dev/null &
      wait $!
      sudo apt-get -y install mariadb-server 2>>"${logfile}" >/dev/null &
      wait $!
      # Spinning, While the program installs
      spinner

      pause_webserver Mariadb
      echo -e "Let's Secure Your Mariadb Server\n"
      mysql_secure_installation

      sudo systemctl start mariadb 2>>"${logfile}" >/dev/null &
      sudo systemctl enable mariadb 2>>"${logfile}" >/dev/null &
      #
      #   They didn't want to Install PHP
      #

    else
      echo -e "Couldn't Secure Mariadb \n"
      return 1

    fi

    return 0
  fi
}


#
#   This Automate mysql secure installation for debian-based systems
#
#  - You can set a password for root accounts.
#  - You can remove root accounts that are accessible from outside the local host.
#  - You can remove anonymous-user accounts.
#  - You can remove the test database (which by default can be accessed by all users, even anonymous users),
#    and privileges that permit anyone to access databases with names that start with test_.
#
#    Tested on Ubuntu 18.04
#

mysql_secure_installation() {
  echo
  while :; do # Unless Password Matches, Keep Looping

    echo -e "Setup mysql root password: \c"
    read -rs mysqlpass

    echo -e "Enter Password Again: \c"
    read -rs mysqlpass2

    #
    #   Checking if both passwords match
    #

    if [ "$mysqlpass" != "$mysqlpass2" ]; then
      echo
      echo -e "Passwords do not match, Please Try again"
    else
      echo
      echo -e "Passwords Matches, Moving On..."
      echo
      break
    fi

  done # Endwhile loop

  TMPFILE=$(mktemp /tmp/mysql_secure_installation.XXXXXXXXXX.sql) || exit 1
  #
  #   This code was originally cat mysql_secure_installation.sql | sed -e "s/123456789/$mysqlpass/" > "$TMPFILE"
  #   Which is wrong and known as the useless use of cat, It's more efficient and less roundabout to simply use redirection.
  #
  #   So, what I did here was first redirecting the content of < "mysql_secure_installation.sql" to sed program, I then redirect the output
  #   of whatever I get to the > TMPFILE
  #
  sed -e "s/123456789/$mysqlpass/" <mysql_secure_installation.sql >"$TMPFILE"
  sudo cp -f "$TMPFILE" mysql_secure_installation.sql # move the temp to mysql_secure_installation.sql
  # remove the tempfile
  rm "$TMPFILE"

  #
  #   The s silences errors and the f forces the commands to continue even if one chokes.
  #   The u relates to the username that immediately follows it which—in this case—is clearly root.
  #
  mysql -sfu root <"mysql_secure_installation.sql"
}