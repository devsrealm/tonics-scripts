installPhp() {
  PHP_VERSION=8.1
  if command -v php 2>>"${logfile}" >/dev/null; then
    echo
    echo -e "PHP is available\n"
  else
    echo
    echo -e "PHP Seems To Be Missing"
    if yes_no "Install PHP"; then
      echo -e "This might take a little while (Sit Back and Relax)"
      sudo apt install lsb-release ca-certificates apt-transport-https software-properties-common gnupg2 2>>"${logfile}" >/dev/null &
      wait $!

      sudo wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
      mkdir -p "/etc/apt/sources.list.d"
      echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/sury-php.list

      sudo apt update 2>>"${logfile}" >/dev/null &
      sudo apt upgrade -y 2>>"${logfile}" >/dev/null &
      wait $!
      spinner

      echo -e "Installing PHP\n"
      sudo apt-get -y install php${PHP_VERSION} php${PHP_VERSION}-{gmp,bcmath,readline,fpm,xml,mysql,zip,intl,ldap,gd,cli,apcu,bz2,curl,mbstring,pgsql,opcache,soap,cgi} 2>>"${logfile}" >/dev/null &
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