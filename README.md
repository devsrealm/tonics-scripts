# tonics-scripts
Script That Automate The Installation Of Tonics Apps and Various Packages 

►Key Requirements

- Operating system: Debian
- Memory: At least 512MB RAM 
- The installation must be performed on a clean system, free of installed/configured software, especially anything related to web servers.
- The installation must be done as a root user, it won't even allow you to pass through even if you want to.
- If you want to use the Let's Encrypt Feature, make sure you have an A record for the website

## How To Install The Program

The installation is easy:

### Connect to your server as root via SSH

> ssh root@yourserver

### If you do not have git install, please do with

> apt install git

### Download The Program, and Change Your Diretory To The Program Directory 

> git clone https://github.com/devsrealm/tonics-scripts.git && cd tonics-scripts

### Give It an Executable Permission

> chmod +x tonicsScripts

### Run The Program, and Configure Away

> ./tonicsScripts yourwebsite.com

*Note: Make Sure You Always Add a Top Level Domain, i.e .com, .net, etc*
