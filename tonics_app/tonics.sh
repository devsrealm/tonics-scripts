#
#   tonics_app_create()
#
#   Create records for our website
#
tonics_app_create() {

#   This checks if the web server is installed
#   If No, It asks to be installed
  installNginx
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

  # Install CP or WP
  install_cp_wp
}

install_cp_wp() {

  askForOnlySiteName

  #
  # Storing ClassicPress Mariabdb Variables To Proceed
  #

  echo "
Note: If You are Planning To Migrate or Move an Existing Website To This Server,
Please Make Sure The Database Name, User and Password You are Inputing
Corresponds To What is in your wp-config,
Check The wp-config of The Old Website File To Cross Check The Details.
If This is a New Website, Then Create a New Details, Good luck!
" | boxes -d columns

  CpDBName=
  while [[ $CpDBName == "" ]]; do
    echo -e "Enter ClassicPress or WordPress Database name: \c"
    read -r CpDBName
  done

  CpDBUser=
  while [[ $CpDBUser == "" ]]; do
    echo -e "Enter ClassicPress or WordPress Mysql user: \c"
    read -r CpDBUser
  done

  CpDBPass=
  while [[ $CpDBPass == "" ]]; do

    while :; do # Unless Password Matches, Keep Looping

      echo -e "Enter ClassicPress or Wordpress Password For $CpDBUser: \c"
      read -rs CpDBPass # Adding the -s option to read hides the input from being displayed on the screen.
      echo -e "Repeat Password: \c"
      read -rs CpDBPass2 # Adding the -s option to read hides the input from being displayed on the screen.
      #
      #   Checking if both passwords match
      #

      if [ "$CpDBPass" != "$CpDBPass2" ]; then
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
  echo -e "Creating ClassicPress or WordPress DB Users and granting privileges with already collected information...\n"

  #
  #   The s silences errors and the f forces the commands to continue even if one chokes.
  #   The u relates to the username that immediately follows it.
  #
  #

  mysql -sfu root <<MYSQL_SCRIPT
CREATE DATABASE $CpDBName DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER '$CpDBUser'@'localhost' IDENTIFIED BY '$CpDBPass';
GRANT ALL ON $CpDBName.* TO '$CpDBUser'@'localhost' IDENTIFIED BY '$CpDBPass';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
  #
  #
  # Preparing Temp Directing for Downloading latest Wordpress/ClassicPress tarball and extraction
  #

  TMPDIR=$(mktemp -d /tmp/cp_wp.XXXXXXXXXX) || exit 1
  echo
  echo -e "What Do You Wish To Do?\n"
  while :; do
    #
    #   Display the ClassicPress or WordPress Decision Menu
    #
    echo "
1.) Install Tonics
2.) Restore Website
3.) Exit

" | boxes -d columns

    #
    #   (Not Relevant Anymore) echo -e "\tType cp For ClassicPress or wp for WordPress: \c"
    #
    echo -e "Choose 1 For New Tonics Installation, or 2 to Restore an existing website: \c"
    read -r cp_wp_decision

    #
    #   Check if User Selected ClassicPress or Wordpress
    #

    case $cp_wp_decision in
    1)
      echo -e "Great, You Selected To Install a New App\n"
      if yes_no "Are you sure you want to proceed"; then
        echo -e "Downloading Latest ClassicPress To a Temp Directory"

        wget https://www.classicpress.net/latest.tar.gz -O "$TMPDIR"/cplatest.tar.gz 2>>"${logfile}" &
        spinner
        #
        #   Extract the file, and extract it into a folder
        #
        mkdir -p "$TMPDIR"/classicpress && tar -zxf "$TMPDIR"/cplatest.tar.gz -C "$TMPDIR"/classicpress --strip-components 1 2>>"${logfile}" &
        wait $! # Wait For the Above Process
        handleError $? "Couldn't Extract ClassicPress Into a Temporary Folder"

        cp -f "$TMPDIR"/classicpress/wp-config-sample.php "$TMPDIR"/classicpress/wp-config.php &>/dev/null
        handleError $? "Couldn't Copy classicpress wp-config-sample.php into a tempdirectory"

        cp -a "$TMPDIR"/classicpress/. /var/www/"$websitename" 2>>"${logfile}" &
        wait $!
        handleError $? "Couldn't Copy The Extracted ClassicPress to the Website Root Folder"

        sudo rm -R "$TMPDIR"
        sudo rm -f /var/www/html/index.nginx-debian.html &
        wait $!
        handleError $? "Couldn't Remove The Temporary Nginx File (/var/www/html/index.nginx-debian.html)"
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

        chown -R "$onlysitename:$onlysitename" /var/www/"$websitename"

        #
        #   Change permission of all directory and file under websitename
        #
        find /var/www/"$websitename" -type d -exec chmod 755 {} \;
        find /var/www/"$websitename" -type f -exec chmod 644 {} \;

        #
        #   Change permission of wp-config
        #

        chmod 660 /var/www/"$websitename"/wp-config.php

        #
        #   Allow ClassicPress To Manage Wp-content
        #

        find /var/www/"$websitename"/wp-content -type d -exec chmod 775 {} \;
        find /var/www/"$websitename"/wp-content -type f -exec chmod 664 {} \;

        #
        #   Writing ClassicPress config file with collected config data
        #

        echo -e "Writing ClassicPress config file with collected config data...\n"

        sed -i "s/database_name_here/$CpDBName/" /var/www/"$websitename"/wp-config.php
        sed -i "s/username_here/$CpDBUser/" /var/www/"$websitename"/wp-config.php
        sed -i "s/password_here/$CpDBPass/" /var/www/"$websitename"/wp-config.php

        progress_bar
        # reload nginx
        sudo systemctl start nginx 2>>"${logfile}" >/dev/null &
        sudo systemctl enable nginx 2>>"${logfile}" >/dev/null &
        sudo systemctl reload nginx 2>>"${logfile}" >/dev/null &
        echo "
                ClassicPress Installation Has Been Completed Successfully
                Your Error Log file is at  $logfile
                Please browse to http://$websitename/wp-admin/install.php to complete the installation through the web interface
                The information you'll need are as follows:
                1) ClassicPress Database Name: $CpDBName
                2) ClassicPress Database User: $CpDBUser
                3) ClassicPress Database User Password: $CpDBPass
                Save this in a secret place.
                !!
                You can reach me at https://devsrealm.com/
                !!
                Welcome to the ClassicPress communtity, if you need support, please head over to forum.classicpress.net
                " | boxes -d ian_jones

        exit 0
      else
        return 1
      fi
      ;;
    2)
      echo
      echo -e "Good, You Selected Restore\n"
      echo
      if yes_no "Do You Want to Proceed With Restoring an Existing Website "; then
        #
        #   We would be using atool for the extraction, I chose this external program
        #   because sometimes user might want to extract format other than tar.gz. So,
        #   even if you want to extract a rar file, it still works, even .7z, cool right :)
        #
        if command -v atool 2>>"${logfile}" >/dev/null; then # Checking if the atool package is installed
          echo
          echo -e "atool dependency Okay...."

        else

          echo -e "Installing Dependencies...."
          sudo apt-get -y install atool 2>>"${logfile}" >/dev/null &
          spinner
          echo -e "atool dependency Installed, Moving On...."

        fi # End Checking if the atool package is installed

        TMPDIR=$(mktemp -d /tmp/website_restore_XXXXX) || exit 1

        while :; do

          echo "
Note: You Can Either Pass a Filename Located in The Current Directory,
e.g file.zip or Specify The Directory In Which The File is Located,
and Point To it, e.g /path/to/directory/file.zip
    " | boxes -d columns

          read -rp "The Name of Your Compressed File: " website_restore

          echo "
Note: You Can Either Pass a Database Located in The Current Directory,
e.g database.sql or Specify The Directory In Which The Database is Located,
and Point To it, e.g /path/to/directory/database.sql
    " | boxes -d columns

          read -rp "The Name of Your Database File (This should be in .sql): " db_file

          #
          #   Getting The Extension of the db_file, in order to run a test if it is in .sql
          #

          stripfilename=$(basename -- "$db_file") # This gets the filename without the path
          extension="${stripfilename##*.}"        # This Extracts the extension, in which case, we are looking for .sql
          #
          #   Checking if the both file exist and the db extension ends in sql
          #

          if [[ ! -f $website_restore && ! -f $website_restore && $extension != "sql" ]]; then
            echo -e "You are either not referencing a correct archive or not referencing an actual sql file, Please Point To an Actual File"
          else

            echo -e "Great, Directory and Database file Exist... Moving On"
            echo
            break

          fi # END [[ ! -f $website_restore && ! -f $website_restore && $extension != "sql" ]]
        done # Endwhile loop

        echo -e "Extracting Into a Temp Directory"
        aunpack "$website_restore" -X "$TMPDIR" 2>>"${logfile}" >/dev/null
        echo -e "Checking if You Have Unnecessary folder"

        #
        #   Some Users Would Have Their Archive File Contain Another Folder, e.g If The Folder is archive.zip
        #   when extracted, it might turn out that their is another folder in the folder, e.g /archive/public_html
        #   In this case, the below code would check if there is any folder at all, if there is none, we break out of the loop
        #
        #   If there is one, we copy everything recursively into the main folder, and we delete the empty folder
        #

        cd "$TMPDIR" || {
          echo -e "Couldn't Change into Temp Directory...Exiting"
          return 1
        }

        #
        #   This code was originally for i in $(ls), which should be avoidable since
        #   Using command expansion causes word splitting and glob expansion e.g a file with spaces, and other weird file naming
        #
        #   I changed this to for i in $TMPDIR, but really it really doesn't matter in this case as I have already handle the cases of no
        #   matches in the code below
        #

        for i in $TMPDIR; do

          if [ ! -d "$i" ]; then # If there is no folder, break out
            echo -e "You Don't Have an Unnecessary Folder, Moving On."
            break

          else # If there is a folder, copy all of its content into the main root folder

            echo -e "You have an unnecessary folder, next time, make sure you are not archiving a folder along your files, \nLet me take care of that for you..."
            \cp -a "$i"/. "$TMPDIR"/

          fi

        done

        #
        # Go back into the script directory
        #
        SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
        cd "$SCRIPT_DIR"

        spinner

        if yes_no "Before We Move On, Would You Like To Check If The wp-config data Contains The Actual DB Details "; then

          if [ ! -f "$TMPDIR"/wp-config.php ]; then
            echo -e "wp-config.php is missing, Looks like you extracted the wrong file!"
            return 1
          else

            nano "$TMPDIR"/wp-config.php
            echo -e "Moving Into The Real Directory"
            cp -a "$TMPDIR"/. /var/www/"$websitename" 2>>"${logfile}" >/dev/null

            sudo rm -R "$TMPDIR"

            echo

            echo -e "Adjusting file and directory permissions..\n"

            #
            #   Change directory and file user and group to www-data
            #

            chown -R "$onlysitename:$onlysitename" /var/www/"$websitename"

            #
            #   Chnage permission of all directroy and file under websitename
            #

            find /var/www/"$websitename" -type d -exec chmod 755 {} \;
            find /var/www/"$websitename" -type f -exec chmod 644 {} \;

            #
            #   Chnage permission of wp-config
            #

            chmod 660 /var/www/"$websitename"/wp-config.php

            #
            #   Allow ClassicPress To Manage Wp-content
            #

            find /var/www/"$websitename"/wp-content -type d -exec chmod 775 {} \;
            find /var/www/"$websitename"/wp-content -type f -exec chmod 664 {} \;

            echo -e "Finalizing Restoration...\n"

            mysql --user="$CpDBUser" --password="$CpDBPass" "$CpDBName" <"$db_file"

            progress_bar
            # reload nginx
            sudo systemctl reload nginx &>/dev/null

            echo "
$websitename restored, Check if you can access the website,
and you might also want to secure it using the Free Let's Encrypt SSL
    " | boxes -d columns

            return 0

          fi
          # END [ ! -f "$TMPDIR"/wp-config.php ]

        #
        #   They didn't want to open wp-config, so, we move on...
        #

        else
          echo -e "Moving Into The Real Directory"
          cp -a "$TMPDIR"/. /var/www/"$websitename" 2>>"${logfile}" >/dev/null
          handleError $? "Can't Move $websitename Into The Real Directory"

          sudo rm -R "$TMPDIR"
          echo -e "Adjusting file and directory permissions..\n"

          #
          #   Change directory and file user and group to www-data
          #

          chown -R "$onlysitename:$onlysitename" /var/www/"$websitename"

          #
          #   Chnage permission of all directroy and file under websitename
          #

          find /var/www/"$websitename" -type d -exec chmod 755 {} \;
          find /var/www/"$websitename" -type f -exec chmod 644 {} \;
          #
          #   Chnage permission of wp-config
          #

          chmod 660 /var/www/"$websitename"/wp-config.php

          #
          #   Allow ClassicPress To Manage Wp-content
          #

          find /var/www/"$websitename"/wp-content -type d -exec chmod 775 {} \;
          find /var/www/"$websitename"/wp-content -type f -exec chmod 664 {} \;

          echo -e "Finalizing Restoration...\n"

          mysql --user="$CpDBUser" --password="$CpDBPass" "$CpDBName" <"$db_file"

          progress_bar
          # reload nginx
          sudo systemctl reload nginx 2>>"${logfile}" >/dev/null &

          echo "
$websitename restored, Check if you can access the website,
and you might also want to secure it using the Free Let's Encrypt SSL
" | boxes -d columns

        fi # END "Before We Move On, Would You Like To Check If The wp-config data Contains The Actual DB Details "

        return 0

      fi # END Do You Want to Proceed With Restoring an Existing Website
      ;;
    3)
      return 0
      ;;
    *)
      echo
      echo -e "please enter a number between 1 and 3"
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
