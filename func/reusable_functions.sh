#
# USAGE:
# run_command
# handleError $? "Error Occurred With Command"
#

#
#   pause()
#
#   Ask the user to press ENTER and wait for them to do so
#
pause() {
  echo
  echo -e "Hit <ENTER> to continue: \c"
  read -r trash
}

pause_webserver() {
  clear
  echo
  echo -e "$1 $2 Installed" "\xE2\x9C\x94" "\n\\nHit <ENTER> to continue: \n"
  # shellcheck disable=SC2034
  read -r trash

}


logfile=errorlog.txt

#
# USAGE:
# run_command
# handleError $? "Error Occurred With Command"
#
handleError() {
  local exit_code=$1
  shift
  [[ $exit_code ]] && # do nothing if no error code passed
    ((exit_code != 0)) && { # do nothing if error code is 0
    echo "ERROR: $* [With Exit Code $exit_code]" > >(tee -a >(ts '[%Y-%m-%d %H:%M:%S]' >>"${logfile}")) # Log Error.
    echo "Check Logfile -> $logfile"
    exit 1
  }
}

#
#   yes_no()
#
#   A function to display a string (passed in as $*), followed by a "(Y/N)?",
#   and then ask the user for either a Yes or No answer.  Nothing else is
#   acceptable.
#   If Yes is answered, yes_no() returns with an exit code of 0 (True).
#   If No is answered, yes_no() returns with an exit code of 1 (False).
#
yes_no() {
  #
  #   Loop until a valid response is entered
  #
  while :; do
    #
    #   Display the string passed in $1, followed by "(Y/N)?"
    #   The \c causes suppression of echo's newline
    #
    echo -e "$* (Y/N)? \c"

    #
    #   Read the answer - only the first word of the answer will
    #   be stored in "yn".  The rest will be discarded
    #   (courtesy of "junk")
    #
    read -r yn junk

    case $yn in
    y | Y | yes | Yes | YES | yeS | yES)
      return 0
      ;; # return TRUE
    n | N | no | No | NO | nO)
      return 1
      ;; # return FALSE
    *)
      echo -e "Could You Please answer Yes or No."
      ;;
      #
      # and continue around the loop ....
      #
    esac
  done
}

#
#   A spinner while long process is running
#

spinner() {
  local pid=$!
  local delay=1
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

progress_bar() {
  for ((k = 0; k <= 10; k++)); do
    echo -e -n "[ "
    for ((i = 0; i <= k; i++)); do echo -n "###"; done
    for ((j = i; j <= 10; j++)); do echo -n "   "; done
    v=$((k * 10))
    echo -n " ] "
    echo -n "$v %" $'\r'
    sleep 0.7
  done
  echo
}

#   quit Function
#
#   This Prompt the user to exit the program, if they choose to,
#   an exit code is provided in the first argument ($1)
#
quit() {
  #
  #   Store the exit code away, coz calling another function
  #   overwrites $1.
  #
  code=$1
  if yes_no "Do you really wish to exit"; then
    exit "$code" #  exit using the supplied code.
  fi
}

#
#   Usage Message FUNCTION
#
#   ************************************************************
#   ***Warning*** This comment would be long, it's for reference:
#   *************************************************************
#   The Usage function I created here is a bit tricky, this is what happens,
#   I take $1 which is supposed to represent the script name, and it then stores it in a little variable called script.
#
#   Shouldn't $1 be a first positional argument, it shouldn't be a script name right? That is correct, but consider we call the
#   usage function as so:
#
#   usage $0 websitename
#
#   The usage word above isn't a parameter, it is a function, and it takes the $0 (script name) as its first positional argument
#   ($1), and it then stores it in the variable script in the usage function.
#
#    The shift in the function skips the first parameter, this way we can separate the script name from the rest of the
#     paramater, so, whatever other parameter you pass e.g if you
#    pass $2 it would now represent $1, and if you pass $3, it would now represent $2 and so on. $* in the function makes us
#     perform test on all the other arguments, even if you supply 20.

#   "basename" is used to transform "/home/devsrealm/install_classicpress"
#   into "install_classicpress"
usage() {
  script=$1
  shift
  echo
  echo -e "Usage: $(basename "$script") $*\n" 1>&2

  exit 2
}

function addUserAccount() {
  local username=${1}
  local password=${2}
  local silent_mode=${3}

  if [[ ${silent_mode} == "true" ]]; then
    sudo adduser --disabled-password --gecos '' "${username}"
  else
    sudo adduser --disabled-password "${username}"
  fi

  echo "${username}:${password}" | sudo chpasswd
}

askForOnlySiteName() {
  while :; do # Unless Password Matches, Keep Looping
    echo -e "Enter only site name (e.g if the site name is google.com, enter only google) \c?"
    read -r onlysitename
    echo -e "Enter Again \c?"
    read -r onlysitename2

    if [ "$onlysitename" != "$onlysitename2" ]; then
      echo -e "Site name doesn't match"
    else
      echo -e "Matches, Moving On..."
      break
    fi
  done
}