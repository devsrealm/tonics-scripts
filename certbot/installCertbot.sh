#
#   install_certbot()
#
#   The certbot automation function
#
install_certbot() {
  if command -v certbot 2>>"${logfile}" >/dev/null; then
    echo
    echo -e "certbot is available\n" "\xE2\x9C\x94\n"
    return 0
  else
    #
    #   Ask if it should be Installed
    #
    echo -e "Certbot Seems To Be Missing\n"
    if yes_no "Install Certbot"; then
      sudo apt-get update 2>>"${logfile}" >/dev/null &
      sudo apt-get -y install certbot python3-certbot-nginx 2>>"${logfile}" >/dev/null &
      wait $!

      # Spinning, While the program installs
      spinner
      # reload nginx
      sudo systemctl enable nginx 2>>"${logfile}" >/dev/null &
      sudo systemctl reload nginx 2>>"${logfile}" >/dev/null &
    #
    #   Pause to give the user a chance to see what's on the screen
    #
    else
      echo
      echo -e "Couldn't Install certbot, check error log"
      return 1
    fi
    return 0
  fi
}

issueSSLCert() {
  install_certbot
  echo -e "Your Email Address For Certbot Certificate: \c"
  read -r email
  certbot --nginx -d "*.$websitename" -d "$websitename" -m "$email" --preferred-challenges=dns --server https://acme-v02.api.letsencrypt.org/directory --agree-tos --redirect --hsts --staple-ocsp --non-interactive 2>>"${logfile}" >/dev/null &
  handleError $? "Couldn't Issue $websitename a Free Let's Encrypt Certificate"
  echo -e "Done\n"
  systemctl restart nginx
}

#
#   website_secure()
#
#   Secure website using Let’s Encrypt SSL
#
website_secure() {
  if yes_no "Do you want to secure another website"; then
    read -rp "The Name of New Website You want to secure e.g example.com: " websitename
    #
    # Call The install_certbot function
    #
    issueSSLCert
  fi
}
