#!/bin/bash

# ARGS:
# -b branch URL
#
# optional: 
# -u build URL
# -s source URL list - defaults to Pulse top sites list
# -d description
# -o OneCRL set
# -p prefs for both runs
# -p1 pref for test run only (overrides -p)
# -p2 pref for release run only (overrides -p)

for i in "$@"
do
case $i in
    -u=*)
    test_build_url="${i#*=}"
    ;;
    -b=*)
    branch="${i#*=}"
    ;;
    -s=*)
    source="${i#*=}"
    ;;
    -d=*)
    description="${i#*=}"
    ;;
    -p=*)
    pref="${i#*=}"
    ;;
    -o=*)
    one_crl="${i#*=}"
    ;;
    -p1=*)
    pref1="${i#*=}"
    ;;
    -p2=*)
    pref2="${i#*=}"
    ;;
    -h)
    help=1
    ;;
    *)
    ;;
esac
done

  
if [ -z $one_crl ]
then
    one_crl=prod
fi  

if [ $pref ] 
then
    pref1=$pref
    pref2=$pref
fi

# hard-coded
source_name="Top sites"
url_source=top-1m.csv

if [[ $OSTYPE =~ .*darwin*. ]]
then
    platform=osx
    file_extension=.dmg
else
    # we will assume linux64
    platform=linux64
    file_extension=.tar.bz2
fi

# construct URLs based on platform
release_build_url="https://download.mozilla.org/?product=firefox-latest&os="$platform"&lang=en-US"
beta_build_url="https://download.mozilla.org/?product=firefox-beta-latest&os="$platform"&lang=en-US"
aurora_build_url="https://download.mozilla.org/?product=firefox-aurora-latest&os="$platform"&lang=en-US"
nightly_build_url="https://download.mozilla.org/?product=firefox-nightly-latest&os="$platform"&lang=en-US"

case $branch in
*"beta"*)
    version=$beta
    test_build_url=$beta_build_url
    branch=Beta
    app_name="Firefox.app"
    volume="Firefox"
;;
*"aurora"*)
    version=$aurora
    test_build_url=$aurora_build_url
    branch=Aurora
    app_name="FirefoxDeveloperEdition.app"
    volume="FirefoxDeveloperEdition"
;;
*"nightly"*)
    version=$nightly
    test_build_url=$nightly_build_url
    branch=Nightly
    app_name="FirefoxNightly.app"
    volume="Nightly"
;;
*)
    branch=Release
    app_name="Firefox.app"
    volume="Firefox"
;;
esac

# required to allow for file system operations
file_system_pause_time=5

# number of simultaneous requests
if [[ $platform == "osx" ]]
then
    # may be too high; 50 might work better, lower for more accuracy
    batch_quantity=100
else
    # linux is running out of file handles, so
    # we're going to throttle this lower for now
    batch_quantity=50
fi

# time between making batches of requests
pause_time=5

DIR=$( cd "$( dirname "$BASH_SOURCE[0]}" )" && pwd )
cd $DIR

start_time=$(date +%s)
run_date=$(date +%F)
time=$(date +%H-%M-%S)
timestamp=$run_date'-'$time

# generate run ID
mkdir runs/$timestamp
TEST_DIR=$DIR"/runs/"$timestamp

cd $TEST_DIR
mkdir certs
mkdir temp

# setting up profile folders
mkdir profiles
mkdir profiles/test_profile
mkdir profiles/release_profile
test_profile=$TEST_DIR"/profiles/test_profile"
release_profile=$TEST_DIR"/profiles/release_profile"

cp $DIR"/profiles/default_profile/cert8.db" $test_profile
cp $DIR"/profiles/default_profile/key3.db" $test_profile
cp $DIR"/profiles/default_profile/cert8.db" $release_profile
cp $DIR"/profiles/default_profile/key3.db" $release_profile

# fetch OneCRL list
export go_orig=$(which go)
export go_orig_path=$(dirname $go_orig)
export go_path=$(readlink $go_orig)
export new_path=$(dirname $go_path)
cd $go_orig_path
cd $new_path

if [[ $platform == "osx" ]]
then
    cd ../libexec/src
else
    # we will assume linux
    cd ../src
fi

if [[ $platform == "osx" ]]
then
    mkdir github.com
    cd github.com
    export src_dir=$PWD
    mkdir mozmark
    cd mozmark
    git clone https://github.com/mozmark/OneCRL-Tools
else
    # we will assume linux
    sudo mkdir github.com
    cd github.com
    export src_dir=$PWD
    sudo mkdir mozmark
    cd mozmark
    sudo git clone https://github.com/mozmark/OneCRL-Tools
fi

cd OneCRL-Tools/oneCRL2RevocationsTxt

# get revocations from live environment and save locally
go run main.go $one_crl > $test_profile"/revocations.txt"
go run main.go prod > $release_profile"/revocations.txt"

if [[ $platform == "osx" ]]
then
    rm -rf $src_dir
else
    # we will assume linux
    sudo rm -rf $src_dir
fi

chmod -R 0555 $test_profile
chmod -R 0555 $release_profile

TEMP=$TEST_DIR"/temp/"
cd $TEMP

# download 

wget -O 'FirefoxReleaseBuild'$file_extension $release_build_url
sleep 15

if [[ $platform == "osx" ]]
then
    # move Firefox build from dmg to local test folder
    open "FirefoxReleaseBuild"$file_extension
    sleep 15
    cp -rf "/Volumes/Firefox/Firefox.app" $TEMP
    mv Firefox.app Firefox_Release.app
    release_build=$TEMP"Firefox_Release.app/Contents/MacOS/firefox"
    hdiutil detach /Volumes/Firefox
else
    # linux
    bzip2 -d $TEMP'FirefoxReleaseBuild.tar.bz2'
    sleep 5
    tar -xf $TEMP'FirefoxReleaseBuild.tar'
    sleep 10
    mv firefox firefox_release
    release_build=$TEMP"firefox_release/firefox"
    sleep 5
fi


cd $DIR

# run scans
run ()
{
    input_file="$1"
    log_file="$2"
    app_path="$3"

    profile_arg='-profile='$TEST_DIR'/profiles/'"$4"

    pref_arg=' -p='"$5"
    json_arg="$6"
    cert_arg="$7"
    path_arg=" -d="$DIR"/"
    js=$DIR/scan_url2.js
    LOG=$TEST_DIR"/temp/"$log_file
    site_list=$( cat $input_file )

    n=0
    for line in $site_list; do
        uri_array[n]=$line
        n=$(($n+1))
    done

    exec 6>&1
    exec > $LOG

    index=0
    for uri in $site_list; do
        index=$(($index+1))
        uri_arg=" -u="$uri
        echo $($app_path -xpcshell $js$uri_arg$path_arg $profile_arg$pref_arg$json_arg$cert_arg) &
        if [ $index -gt $batch_quantity ]; then
            index=0
            sleep $pause_time
        fi
    done
    sleep $file_system_pause_time
}

# First pass: run error URLs against release build
run $DIR/sources/top-1m.csv url_list.txt $release_build "release_profile" $pref2

# diff results and make a new URL list
cd $TEST_DIR
cd temp
sort -u url_list.txt > top_url_list.txt
sleep $file_system_pause_time
cd $DIR

# change permissions 
chmod -R 0777 $test_profile
chmod -R 0777 $release_profile

exit 0