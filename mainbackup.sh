#
#   This function would do a periodic backup of all the website on the server
#   Plus the ability to push the backed up data to any cloud storage as long as 
#   you have it configured in rclone
#
#   There should also be an option to do a restore of the backed up file
#
#
# Includes Backup Function Library
#
source func/backup_add.sh
source func/backup_edit_retention.sh
source func/backup_restore.sh

backup()
  {
    #
    #   BorgBackup (short: Borg) is a deduplicating backup program. Optionally, it supports compression 
    #   and authenticated encryption.
    #

    if command -v borgbackup 2>> ${logfile} >/dev/null # Checking if the borgbackup package is installed
    then
        echo
        echo -e "tborgbackup dependency Okay...."
    else

        echo -e "\t\t\t\tInstalling Dependencies...."
        sudo apt-get install -y borgbackup 2>> ${logfile} >/dev/null &
        spinner
        echo -e "borgbackup dependency Installed, Moving On...."

    fi # End Checking if the borgbackup package is installed

echo "
Note: Make sure you already have rclone configured as root if you want to push
your data to a cloud storage.
This is totally optional as you can also leave your data on the server
storage disk if you prefer.
Read on how to configure rclone here:
https://devsrealm.com/cloud-computing/ubuntu/synchronize-file-with-cloud-storage-using-rclone-in-linux/
" | boxes -d columns


    # Create Backup Directory Log
    mkdir -p backup_log # Create Backup Directory If It Already Doesn't Exist

    # Close if borg or rclone is running
    if pidof "borg" || pgrep "rclone" > /dev/null 
    then
        echo "Backup already running, exiting - $now" 2>&1 | tee -a backup_log/$date.log
        exit 1
    fi

    echo -e "What Would You Like To Do...\n"
    while :
          do
#
#   Display DNS Menu
#
echo "
1.) Automate Full Sites Backup
2.) Edit Backup Retention
3.) Restore Backup File
4.) Exit

" | boxes -d columns

                        #
                #   Prompt for an answer
                #
                echo -e "Answer (or 'q' to quit): \c?"
                read ans junk

                #
                #   Empty answers (pressing ENTER) cause the menu to redisplay,
                #   so, this goes back around the loop
                #   We only make it to the "continue" bit if the "test"
                #   program ("[") returned 0 (True)
                #
                [ "$ans" = "" ] && continue

                #
                #   Decide what to do base on user selection
                #

                    case $ans in
                    1)     backup_add
                    ;;
                    2)     backup_edit_retention
                    ;;
                    3)     backup_restore
                    ;;
                    4)     quit 0
                    ;;
                    q*|Q*) quit 0
                    ;;
                    *)     echo -e "Please Enter a Number Between 1 and 4";;
                esac
                #
                #   Pause to give the user a chance to see what's on the screen, this way, we won't lose some infos
                #
                pause

    done              
} # END backup
