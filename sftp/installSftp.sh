#
#   sFTP is a “secure version of file transfer protocol which helps
#   in transmitting data over a secure shell data stream, it is simply a secure way of transferring
#   files between local and remote servers.
#
#   This function helps to automate the creation of sftp user group, this way, we can restrict
#   this group to each user document root e.g /var/www/website1
#

sftp() {

  #
  #   Read more about managing users in Linux
  #
  #   https://devsrealm.com/cloud-computing/ubuntu/an-easy-guide-to-managing-users-in-ubuntu-18-04/
  #
  #   The goal of this function is not to create an sftp access arbitrarily, but to
  #   to jail a user, this way they have no way to break out of their home directory.
  #
  #   We then mount a location to their home directory, so they can upload files to their website root folder.
  #   For example, If user "paul" needs to upload files to /var/www/websitename.com, we chroot to /home/jail/paul
  #   and then mount /var/www/websitename.com to their home directory, this way, they can upload to the correct website directory without
  #   needing access to it, and thus, things would be breeze and secure.
  #
  SFTP_ONLY_GROUP="sftp_only"

  # Make sure the group exists
  # grep  -i "^${SFTP_ONLY_GROUP}" /etc/group  >/dev/null 2>&1
  if grep -i "^${SFTP_ONLY_GROUP}" /etc/group >/dev/null 2>&1; then # If group exist
    echo -e "Initial Setup Okay... Moving On."
  else
    echo -e "Adding Initials"
    sudo groupadd $SFTP_ONLY_GROUP # Create sftp group

    #
    #   Disabling normal sftp and enabling jailed sftp
    #
    config='/etc/ssh/sshd_config'
    sed -i "s/Subsystem.*sftp/#Subsystem sftp/" /etc/ssh/sshd_config # Disabling normal sftp

    #   Enabling Jailed SFTP
    echo " " >>$config
    echo "Subsystem sftp internal-sftp" >>$config
    echo "Match Group $SFTP_ONLY_GROUP" >>$config
    echo "ChrootDirectory %h" >>$config
    echo "    AllowTCPForwarding no" >>$config
    echo "    X11Forwarding no" >>$config
    echo "    ForceCommand internal-sftp" >>$config

  fi

  #
  #   Creating a chroot Directory, this is the home directory we will be chrooting our sFTP user to
  #   This would enable us have more directories with each one relating to a different website.
  #

  chroot_dir=/sftpusers/jailed

  echo -e "Enter SFTP New User: \c"
  read -r sftp_user

  # Does User exist?
  id "$sftp_user" &>/dev/null
  if [ $? -eq 0 ]; then
    echo -e "$sftp_user exists"
    if yes_no "Do you want to change password instead?"; then

      while :; do # Unless Password Matches, Keep Looping
        echo -e "Enter $sftp_user new password: \c"
        read -rs pass1 # Adding the -s option to read hides the input from being displayed on the screen.
        echo -e "Repeat $sftp_user new password: \c"
        read -rs pass2

        #
        #   Checking if both passwords match
        #

        if [ "$pass1" != "$pass2" ]; then
          echo
          echo -e "Passwords do not match, Please Try again"
        else
          echo
          echo -e "Passwords Matches, Moving On..."
          break
        fi
      done # Endwhile loop

      echo "$sftp_user:$pass2" | chpasswd -c SHA512 #Encrypt Password using SHA512
      echo -e "Password Changed"
      return 0
    fi

  else

    if [ ! -d $chroot_dir/"$sftp_user" ]; then
      echo -e "$sftp_user directory and user does not exist yet...creating"

      mkdir -p $chroot_dir/"$sftp_user"/
      mkdir -p $chroot_dir/"$sftp_user"/"$websitename"
      echo -e "$sftp_user created"
    fi

    #
    #   Adding the new user with the home directory with no ability to shell login
    #   The user won't be able to SSH into the server, but can only access through SFTP for transferring files
    #

    useradd -d $chroot_dir/"$sftp_user"/ -s /usr/sbin/nologin -G $SFTP_ONLY_GROUP "$sftp_user"

    while :; do # Unless Password Matches, Keep Looping

      echo -e "Enter $sftp_user new password: \c"
      read -rs pass1 # Adding the -s option to read hides the input from being displayed on the screen.
      echo
      echo -e "Repeat $sftp_user new password: \c"
      read -rs pass2

      #
      #   Checking if both passwords match
      #

      if [ "$pass1" != "$pass2" ]; then
        echo
        echo -e "Passwords do not match, Please Try again"
      else
        echo
        echo -e "Passwords Matches, Moving On..."
        break
      fi
    done # Endwhile loop

    echo
    echo -e "Changing password\n"
    echo "$sftp_user:$pass2" | chpasswd -c SHA512 #Encrypt Password using SHA512

    #
    #   Restart SSH
    #
    service ssh restart >/dev/null 2>&1
    service sshd restart >/dev/null 2>&1

    echo -e "Setting Proper User Permissions..."

    chmod 711 $chroot_dir
    chmod 755 $chroot_dir/"$sftp_user"/
    chown root:root $chroot_dir # chowning the chroot_directory

    #   Setting the permissions of the mount directory

    chown "$sftp_user":$SFTP_ONLY_GROUP $chroot_dir/"$sftp_user"/"$websitename"/
    chmod 700 $chroot_dir/"$sftp_user"/"$websitename"/

    #
    #   The below forces any new files or directories created by this user to have a group matching the parent directory
    #
    find /var/www/"$websitename"/ -type d -exec chmod g+s {} \;

    #
    #   Now we mount a specific directory to the users chrooted home directory.
    #   The below command mount the directory stated in /etc/fstab to the directory we have just specified
    #   ($chroot_dir/$sftp_user/$websitename/)
    #

    mount -o bind /var/www/"$websitename" $chroot_dir/"$sftp_user"/"$websitename"

    #
    #   The /etc/fstab file is a system configuration file that contains all
    #   available disks, disk partitions and their options.
    #   Each file system is described on a separate line. This file would help to mount additional volumes you would like to
    #   automatically mount at boot time
    #

    echo -e "Mounting Directory..."
    echo "/var/www/$websitename/ $chroot_dir/$sftp_user/$websitename/ none bind 0 0" >>/etc/fstab
    echo -e "SFTP User Created"

    #
    #   Restart SSH
    #

    service ssh restart >/dev/null 2>&1
    service sshd restart >/dev/null 2>&1

    echo "
    SFTP User Created
    You can login with $sftp_user@$ip and your choosen password
    " | boxes -d ian_jones

    return 0

  fi
}
