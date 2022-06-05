#
#   installNginx function
#
#   A function check if the web server is installed, if no,
#   we follow by a "(Y/N)?" to install it
#

installNginx() {
  if command -v nginx 2>>"${logfile}" >/dev/null; then
    echo
    echo -e "Nginx is available\n"

  else
    #
    #   Ask if it should be created
    #
    echo
    echo -e "Nginx Seems To Be Missing\n"
    if yes_no "Install Nginx Web Server"; then
      echo -e "Installing Nginx From The Official Nginx Repo"
      sudo wget https://nginx.org/keys/nginx_signing.key 2>>"${logfile}" >/dev/null &
      wait $!
      sudo apt-key add nginx_signing.key 2>>"${logfile}" >/dev/null &
      wait $!

      #   We add the below lines to sources.list to name the repositories
      #   from which the NGINX Open Source source can be obtained:
      #   The lsb_release automatically adds the distro codename
      echo "deb http://nginx.org/packages/mainline/debian $(lsb_release -cs) nginx" |
        sudo tee -a /etc/apt/sources.list >/dev/null &
      wait $!

      echo "deb-src http://nginx.org/packages/mainline/debian $(lsb_release -cs) nginx" |
        sudo tee -a /etc/apt/sources.list >/dev/null &
      wait $!

      sudo apt-get update 2>>"${logfile}" >/dev/null &
      wait $!
      sudo apt-get -y install nginx 2>>"${logfile}" >/dev/null &

      # Spinning, While the program installs
      spinner

      #   Recheck if nginx is installed
      #   Pause to give the user a chance to see what's on the screen
      #
      if command -v nginx 2>>"${logfile}" >/dev/null; then
        echo -e "Configuring Nginx"
        configureNginxWithCaching
        pause_webserver Nginx
      else
        echo -e "Couldn't Install Nginx"
        return 1
      fi
    else

      #
      #   They didn't want to Install Nginx
      #
      return 1
    fi
    return 0
  fi
}

configureNginxWithCaching() {
  # Check if the nginx site-available and site-enabled is created, if no create it
  [ -d "$site_available" ] || sudo mkdir -p "$site_available"
  [ -d "$site_enabled" ] || sudo mkdir -p "$site_enabled"

  #
  #   mktemp will create the file or exit with a non-zero exit status,
  #   this way, you can ensures that the script will exit if mktemp is unable to create the file.
  #
  #   Note: The inclusion of /etc/nginx/sites-enabled/*; is no longer need, I'll leave this for reference
  #
  #   cat nginx/ngx_conf_with_caching | sed '/conf.d/a  \\tinclude /etc/nginx/sites-enabled/*;' | awk '! (/sites-enabled/ && seen[$0]++)' > $TMPFILE
  #
  #   This adds the include /etc/nginx/sites-enabled/*; in the nginx config file if it isn't already there
  #   We also removed any duplicate of /etc/nginx/sites-enabled/*
  #
  #   Note: I added two tabs to make the format of the nginx config consistent
  #    \t is one tab \\t is two tab, if you want three tab, you do \\t\t, yh, sed is crazy
  #

  TMPFILE=$(mktemp /tmp/nginx.conf.XXXXXXXXXX) || exit 1
  cat nginx/ngx_conf_with_caching >"$TMPFILE"
  sudo cp -f "$TMPFILE" /etc/nginx/nginx.conf # move the temp to nginx.conf
  # remove the tempfile
  rm "$TMPFILE"
}

configureNginxSpool() {
  echo -e "Configuring The Spool"
  # CHANGING THE onlysitename to the actual site name in NGINX POOL DIRECTORY
  TMPFILE=$(mktemp /tmp/spool.XXXXXXXX) || exit 1
  sed -e "s/onlysitename/$onlysitename/g" <nginx/spool.conf >"$TMPFILE"
  sudo cp -f "$TMPFILE" "/etc/php/${PHP_VERSION}/fpm/pool.d/$onlysitename.conf"
  # remove the tempfile
  rm "$TMPFILE"

  # CHANGING THE onlysitename to the actual site name in NGINX CONFIG
  TMPFILE=$(mktemp /tmp/default.nginx.XXXXXXXX) || exit 1
  sed -e "s/onlysitename/$onlysitename/g" <"$site_available/$websitename" >"$TMPFILE"
  sudo cp -f "$TMPFILE" "$site_available/$websitename"
  # remove the tempfile
  rm "$TMPFILE"
  systemctl restart nginx
  systemctl restart php"${PHP_VERSION}"-fpm
}

reloadNginx() {
  pids=() # storing all the process ids into an array
  sudo systemctl start nginx 2>>"${logfile}" >/dev/null &
  pids+=($!)
  sudo systemctl enable nginx 2>>"${logfile}" >/dev/null &
  pids+=($!)
  sudo systemctl reload nginx 2>>"${logfile}" >/dev/null &
  pids+=($!)
  # Loop through the pid and exit if one of the above fails
  for pid in ${pids[*]}; do
    if ! wait "$pid"; then
      handleError $? "Something Went Wrong With Either Starting, Enabling or Reloading Nginx"
    fi
  done
}
