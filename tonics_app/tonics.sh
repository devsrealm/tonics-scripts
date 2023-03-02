resetFilePermissions() {
  askForOnlySiteName

  while [[ $websitename == "" ]]; do
    echo
    read -rp "Seems, we lost the websitename, re-enter it: " websitename
  done

  chown -R "$onlysitename:$onlysitename" /var/www/"$websitename"

  #
  #   Change permission of all directory and file under websitename
  #
  find /var/www/"$websitename" -type d -exec chmod 755 {} \;
  find /var/www/"$websitename" -type f -exec chmod 644 {} \;

  #
  #   Change permission of env file
  #
  chmod 660 /var/www/"$websitename"/web/.env

  #
  #   Allow Tonics To Manage private uploads
  #

  find /var/www/"$websitename"/private -type d -exec chmod 775 {} \;
  find /var/www/"$websitename"/private -type f -exec chmod 664 {} \;

  #
  #   Allow Tonics To Manage public contents
  #
  find /var/www/"$websitename"/web/public -type d -exec chmod 775 {} \;
  find /var/www/"$websitename"/web/public -type f -exec chmod 664 {} \;
}

#
#   tonics_app_create()
#
#   Create records for our website
#
tonics_app_create() {

#   This checks if the web server is installed
#   If No, It asks to be installed
  installNginx
  installPhp
  #
#   Check if the filename represents a valid file.
#
if [ ! -e "$site_available/$websitename" ]; then
  echo -e "$websitename does not exist"

  #
  #   Ask if it should be created
  #
  if yes_no "Do you want to create it"; then
    #
    #   Attempt to create it
    #
    touch "$site_available/$websitename"

    #
    #   Check if that succeeded, i.e does user has a permission to create a file
    #
    if [ ! -w "$site_available/$websitename" ]; then
      echo "$websitename" could not be created, check your user permission
      exit 2
    fi
    #
    #   Otherwise we're OK
    #

  else
    #
    #   User doesn't want to create a file
    #
    exit 0
  fi
elif [ ! -w "$site_available/$websitename" ]; then # it exists - check if it can be written to
  echo -e "Could not open $websitename for writing, check your user permission"
  exit 2
fi

  #
  # Get Server IP address that is used to reach the internet
  # We ge the source Ip, we then use sed to match the string source /src/
  # s/             # begin a substitution (match)
  # .*src *      # match anything leading up to and including src and any number of spaces
  #  \([^ ]*\)    # define a group containing any number of non spaces
  #  .*           # match any trailing characters (which will begin with a space because of the previous rule).
  #     /              # begin the substitution replacement
  #  \1           # reference the content in the first defined group
  #
  # Note: This is not useful for now
  ip="$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')"
  #
  #   Remove both occurrences of default_server, servername and point
  #   the root directory to the new website root for your newly copied config.
  #
  #   mktemp will create the file or exit with a non-zero exit status,
  #   this way, you can ensures that the script will exit if mktemp is unable to create the file.
  #

  TMPFILE=$(mktemp /tmp/default.nginx.XXXXXXXX) || exit 1

  #
  #   This code was originally:
  # cat nginx/ngx_serverblock | sudo sed -e "s/domain.tld/$websitename www.$websitename/g" -e "s/\/var\/www\/tonics/\/var\/www\/$websitename/" > "$TMPFILE"
  #   Which is wrong and known as the useless use of cat, It's more efficient and less roundabout to simply use redirection.
  #
  #   So, what I did here was first redirecting the content of < "nginx/ngx_serverblock" to sed program, I then redirect the output
  #   of whatever I get to the > TMPFILE
  #

  sed -e "s/domain.tld/$websitename www.$websitename/g" -e "s/\/var\/www\/tonics/\/var\/www\/$websitename/" <nginx/ngx_serverblock >"$TMPFILE"
  sudo cp -f "$TMPFILE" "$site_available"/"$websitename"

  # remove the tempfile
  rm "$TMPFILE"
  #

  #
  #   Create a directory for the root directory if it doesn't already exist
  #
  if [ ! -d /var/www/"$websitename" ]; then
    sudo mkdir -p /var/www/"$websitename"
  fi

  #
  #   Nginx comes with a default server block enabled (virtual host), let’s remove the symlink, we then add the new one
  #

  if [ -f "$site_enabled"/default ]; then
    sudo unlink "$site_enabled"/default 2>>"${logfile}" >/dev/null &
    wait $!
    handleError $? "Couldn't Unlink $site_enabled/default"
  fi

  #
  #   Check if symbolik link exist already
  #
  if [ ! -f "$site_enabled"/"$websitename" ]; then
    sudo ln -s "$site_available"/"$websitename" /etc/nginx/sites-enabled/ 2>>"${logfile}" >/dev/null &
    # ConfigureNginxSpool
    configureNginxSpool
  fi

  # RELOAD NGINX
  reloadNginx

  #
  #   Install and Configure Mariadb and PHP
  #`
  installMariadb
  installPhp

  # Install tonics
  install_tonics
}

install_tonics() {

  askForOnlySiteName

  #
  # Storing Tonics Variables To Proceed
  #

  TonicsDBName=
  while [[ $TonicsDBName == "" ]]; do
    echo -e "Enter Tonics Database name: \c"
    read -r TonicsDBName
  done

  TonicsUser=
  while [[ $TonicsUser == "" ]]; do
    echo -e "Enter Tonics Mysql user: \c"
    read -r TonicsUser
  done

  TonicsPass=
  while [[ $TonicsPass == "" ]]; do

    while :; do # Unless Password Matches, Keep Looping

      echo -e "Enter Tonics Password For $TonicsUser: \c"
      read -rs TonicsPass # Adding the -s option to read hides the input from being displayed on the screen.
      echo -e "Repeat Password: \c"
      read -rs TonicsPass2 # Adding the -s option to read hides the input from being displayed on the screen.
      #
      #   Checking if both passwords match
      #

      if [ "$TonicsPass" != "$TonicsPass2" ]; then
        echo
        echo -e "Passwords do not match, Please Try again"
      else
        echo
        echo -e "Passwords Matches, Moving On..."
        break
      fi
    done # Endwhile loop

  done

  #
  #   Creating ClassicPress DB User and passwords with privileges.
  #
  echo -e "Creating Tonics DB Users and granting privileges with already collected information...\n"

  #
  #   The s silences errors and the f forces the commands to continue even if one chokes.
  #   The u relates to the username that immediately follows it.
  #
  #

  mysql -sfu root <<MYSQL_SCRIPT
CREATE DATABASE $TonicsDBName DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$TonicsUser'@'localhost' IDENTIFIED BY '$TonicsPass';
GRANT ALL ON $TonicsDBName.* TO '$TonicsUser'@'localhost' IDENTIFIED BY '$TonicsPass';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
  #
  #
  # Preparing Temp Directing for Downloading latest Wordpress/ClassicPress tarball and extraction
  #

  TMPDIR=$(mktemp -d /tmp/tonics.XXXXXXXXXX) || exit 1
  echo
  echo -e "What Do You Wish To Do?\n"
  while :; do
    #
    #   Display the Tonics Decision Menu
    #
    echo "
1.) Install Tonics
2.) Exit

" | boxes -d columns

    #
    #   (Not Relevant Anymore) echo -e "\tType cp For ClassicPress or wp for WordPress: \c"
    #
    echo -e "Choose 1 For New Tonics Installation: \c"
    read -r tonics_decision

    #
    #   Check if User Selected Tonics
    #

    case $tonics_decision in
    1)
      echo -e "Great, You Selected To Install a New App\n"
      if yes_no "Are you sure you want to proceed"; then
        
          TonicsDownloadURL=
          while [[ $TonicsDownloadURL == "" ]]; do
            echo -e "Enter Tonics Download URL: \c"
            read -r TonicsDownloadURL
          done
        
        echo -e "Downloading Tonics To a Temp Directory"

        wget "$TonicsDownloadURL" -O "$TMPDIR"/tonicslatest.zip 2>>"${logfile}" &
        spinner
        #
        #   Extract the file, and extract it into a folder
        #
        sudo apt-get -y install unzip 2>>"${logfile}" >/dev/null &
        wait $! # Wait For the Above Process

        mkdir -p "$TMPDIR"/tonics 2>>"${logfile}" >/dev/null &
        unzip "$TMPDIR"/tonicslatest.zip -d "$TMPDIR"/tonics 2>>"${logfile}" &
        wait $! # Wait For the Above Process
        handleError $? "Couldn't Extract Tonics Into a Temporary Folder"

        cp -f "$TMPDIR"/tonics/web/.env-sample "$TMPDIR"/tonics/web/.env &>/dev/null
        handleError $? "Couldn't Copy Tonics env-sample into a tempdirectory"

        cp -a "$TMPDIR"/tonics/. /var/www/"$websitename" 2>>"${logfile}" &
        wait $!
        handleError $? "Couldn't Copy The Extracted Tonics to the Website Root Folder"

        sudo rm -R "$TMPDIR"
        sudo rm -f /var/www/html/index.nginx-debian.html &
        wait $!
        handleError $? "Couldn't Remove The Temporary Nginx File (/var/www/html/index.nginx-debian.html)"


        echo
        echo -e "Setting Up $websitename SystemD Services..\n"
        # sudo cp -f systemd/service_name.service /etc/systemd/system/"$websitename""_tonics".service
        # sudo cp -f systemd/service_name-watcher.service /etc/systemd/system/"$websitename""_tonics-watcher".service
        # sudo cp -f systemd/service_name-watcher.path /etc/systemd/system/"$websitename""_tonics-watcher".path

        systemd_service_name="${websitename}_tonics"

        # Adjusting The Hard-Coded Name
        TMPFILE=$(mktemp /tmp/spool.XXXXXXXX) || exit 1
        sed -e "s#/path/to/tonics/web#/var/www/$websitename/web#g" -e "s#tonics.log#$websitename.tonics.log" -e "s#tonics.err#$websitename.tonics.err" <systemd/service_name.service >"$TMPFILE"
        sudo cp -f "$TMPFILE" "/etc/systemd/system/$systemd_service_name.service"

        TMPFILE=$(mktemp /tmp/spool.XXXXXXXX) || exit 1
        sed -e "s#service_name.service#$systemd_service_name.service#g" <systemd/service_name-watcher.service >"$TMPFILE"
        sudo cp -f "$TMPFILE" "/etc/systemd/system/$systemd_service_name-watcher.service"

        TMPFILE=$(mktemp /tmp/spool.XXXXXXXX) || exit 1
        sed -e "s#/path/to/tonics/web/bin#/var/www/$websitename/web/bin#g" <systemd/service_name-watcher.path >"$TMPFILE"
        sudo cp -f "$TMPFILE" "/etc/systemd/system/$systemd_service_name-watcher.path"

        echo -e "Restarting $websitename SystemD Services..\n"
        systemctl daemon-reload
        # -- now enable start and enable the service
        systemctl --now enable "$systemd_service_name.service"
        systemctl --now enable "$systemd_service_name-watcher.{path,service}"

        echo
        echo -e "Adjusting file and directory permissions..\n"

        #
        #   check if the websitename still has a variable, if no, ask
        #

        while [[ $websitename == "" ]]; do
          echo
          read -rp "Seems, we lost the websitename, re-enter it: " websitename
        done

        #
        #   Change directory and file user and group to www-data
        #
        resetFilePermissions

        #
        #   Writing Tonics config file with collected config data
        #

        echo -e "Writing Tonics config file with collected config data...\n"

        sed -i "s/db_databasename_here/$TonicsDBName/" /var/www/"$websitename"/web/.env
        sed -i "s/db_username_here/$TonicsUser/" /var/www/"$websitename"/web/.env
        sed -i "s/db_password_here/$TonicsPass/" /var/www/"$websitename"/web/.env

        # Installation Key
        TonicsInstallationKey="$(xxd -l30 -ps /dev/urandom)"
        sed -i "s/install_key_here/$TonicsInstallationKey/" /var/www/"$websitename"/web/.env

        progress_bar
        # reload nginx
        sudo systemctl start nginx 2>>"${logfile}" >/dev/null &
        sudo systemctl enable nginx 2>>"${logfile}" >/dev/null &
        sudo systemctl reload nginx 2>>"${logfile}" >/dev/null &
        echo "
                Tonics Installation Has Been Completed Successfully
                Your Error Log file is at  $logfile
                Please browse to http://$websitename/admin/installer to complete the installation through the web interface
                The information you'll need are as follows:
                1) Tonics Database Name: $TonicsDBName
                2) Tonics Database User: $TonicsUser
                3) Tonics Database User Password: $TonicsPass
                4) Tonics Installation Key: $TonicsInstallationKey
                Save this in a secret place.
                !!
                You can reach me at https://devsrealm.com/
                !!
                Welcome to the Tonics community, if you need support, please head over to forum.tonics.app
                " | boxes -d ian_jones

        exit 0
      else
        return 1
      fi
      ;;
    2)
      return 0
      ;;
    *)
      echo
      echo -e "please enter a number between 1 and 2"
      pause
      echo
      ;;

      #
      # and continue around the loop ....
      #
    esac
  done
  # remove the tempdirectory
  sudo rm -rf "$TMPDIR"

}
