installPhp() {
  if command -v php 2>>"${logfile}" >/dev/null; then
    echo
    echo -e "PHP is available\n"
  else
    echo
    echo -e "PHP Seems To Be Missing"
    if yes_no "Install PHP"; then
      echo -e "This might take a little while (Sit Back and Relax)"
      sudo apt install software-properties-common 2>>"${logfile}" >/dev/null &
      wait $!
      sudo add-apt-repository ppa:ondrej/php -y 2>>"${logfile}" >/dev/null &
      wait $!
      sudo add-apt-repository ppa:ondrej/nginx -y 2>>"${logfile}" >/dev/null &
      wait $!
      sudo apt update 2>>"${logfile}" >/dev/null &
      wait $!
      spinner

      echo -e "Installing PHP\n"
      sudo apt-get -y install php${PHP_VERSION} php${PHP_VERSION}-gmp php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-xml php${PHP_VERSION}-curl php${PHP_VERSION}-gd \
        php${PHP_VERSION}-bcmath php${PHP_VERSION}-cli php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-apcu php${PHP_VERSION}-mbstring php${PHP_VERSION}-readline php${PHP_VERSION}-intl php${PHP_VERSION}-zip 2>>"${logfile}" >/dev/null &
      wait $!
      # Spinning, While the program installs
      spinner
      pause_webserver PHP
      #
      #   They didn't want to Install PHP
      #
    else
      echo
      return 1 # They didn't wanna install php
    fi # "Install PHP"
    return 0
  fi # command -v php 2>> "${logfile}" >/dev/null
}