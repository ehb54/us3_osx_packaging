[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## us3 osx_packaging

repo for info &amp; supplementary data to build us3 osx packages

- If you have any questions or problems, please create an issue.
- Pull requests happily considered.

## setting up a first time build environment
  - clone this repo (typically from your home directory, it will be assume so in the commands below)
    - note some of the commmands will require you to enter your password, others your Apple ID and its password
    - note that 'BRANCHNAME' below is to be replaced by the branch of the ultrascan3 repo you wish to build
  - quick way NOT RECOMMENDED
    - still questionable to recommended - you need to watch it and get your password entered in multiple steps
```
export XCODES_USERNAME='your-appleID'
export XCODES_PASSWORD='your-appleID-password'
~/us3_osx_packaging/setup/setup.pl --all
~/us3_osx_packaging/setup/setup.pl --us BRANCHNAME
cd ~/ultrascan-BRANCHNAME
. qt5env
./makeall.sh
./makesomo.sh
~/us3_osx_packaging/macOS-x64/utils/fixdependencies.pl update
## repeat the above step until no "cmds" are reported
~/us3_osx_packaging/macOS-x64/utils/fixapps.pl bin/*.app
~/us3_osx_packaging/macOS-x64/utils/fixlibs.pl lib/*.dylib
~/us3_osx_packaging/macOS-x64/utils/fixdependencies.pl list
## this final command should report the commands to run next to build the packages themselves
```
  - step-by-step way - recommended
```
~/us3_osx_packaging/setup/setup.pl --brew
~/us3_osx_packaging/setup/setup.pl --brewpackages
~/us3_osx_packaging/setup/setup.pl --xquartz
xcodes install 13.4.1
xcodes install 14.3.1
~/us3_osx_packaging/setup/setup.pl --zstd
~/us3_osx_packaging/setup/setup.pl --openssl
~/us3_osx_packaging/setup/setup.pl --mysql
~/us3_osx_packaging/setup/setup.pl --python2
~/us3_osx_packaging/setup/setup.pl --doxygen
~/us3_osx_packaging/setup/setup.pl --qt
~/us3_osx_packaging/setup/setup.pl --qwt
~/us3_osx_packaging/setup/setup.pl --us BRANCHNAME
cd ~/ultrascan-BRANCHNAME
. qt5env
./makeall.sh
./makesomo.sh
~/us3_osx_packaging/macOS-x64/utils/fixdependencies.pl update
## repeat the above step until no "cmds" are reported
~/us3_osx_packaging/macOS-x64/utils/fixapps.pl bin/*.app
~/us3_osx_packaging/macOS-x64/utils/fixlibs.pl lib/*.dylib
~/us3_osx_packaging/macOS-x64/utils/fixdependencies.pl list
## this final command should report the commands to run next to build the packages themselves
```

 - if all goes well, your package will be in `~/Downloads`
 
## after install - building ultrascan again
- all cases, make sure to have the latest packaging code
  - `cd ~/us3_osx_packaging`
  - `git pull` 
### existing branch
```
cd ~/ultrascan-BRANCHNAME
git fetch origin
git reset --hard origin/BRANCHNAME
git pull
~/us3_osx_packaging/setup/setup.pl --us_update BRANCHNAME
. qt5env
./makeall.sh
./makesomo.sh
~/us3_osx_packaging/macOS-x64/utils/fixdependencies.pl update
## repeat the above step until no "cmds" are reported
~/us3_osx_packaging/macOS-x64/utils/fixapps.pl bin/*.app
~/us3_osx_packaging/macOS-x64/utils/fixlibs.pl lib/*.dylib
~/us3_osx_packaging/macOS-x64/utils/fixdependencies.pl list
## this final command should report the commands to run next to build the packages themselves
```
   - if all goes well, your package will be in `~/Downloads`
### new branch
```
~/us3_osx_packaging/setup/setup.pl --us BRANCHNAME
cd ~/ultrascan-BRANCHNAME
. qt5env
./makeall.sh
./makesomo.sh
~/us3_osx_packaging/macOS-x64/utils/fixdependencies.pl update
## repeat the above step until no "cmds" are reported
~/us3_osx_packaging/macOS-x64/utils/fixapps.pl bin/*.app
~/us3_osx_packaging/macOS-x64/utils/fixlibs.pl lib/*.dylib
~/us3_osx_packaging/macOS-x64/utils/fixdependencies.pl list
## this final command should report the commands to run next to build the packages themselves
```
   - if all goes well, your package will be in `~/Downloads`

## notes


## credits

This repo is forked from the macOS installer/builder, a general tool for build macos packages.
See https://github.com/KosalaHerath/macos-installer-builder which can generate macOS installers for your applications and products from one command.

For more detailed process instruction on this please refer medium blog about the macOS installer builder: https://medium.com/swlh/the-easiest-way-to-build-macos-installer-for-your-application-34a11dd08744
