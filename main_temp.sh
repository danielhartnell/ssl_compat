#!/bin/bash

# ARGS:
# -b branch URL
#
# optional: 
# -u build URL
# -s source URL list - defaults to Pulse top sites list
# -d description
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

# check arguments
if [ -n "${help}" ]
then
    echo $'\n'Usage: 
    echo $'\t'-b name of branch: beta, aurora, nightly
    echo $'\n'Optional:
    echo $'\t'-s name of source list: 
    echo $'\t'$'\t'smoke, test, alexa \(default\), pulse, google
    echo $'\t'$'\t'OR custom URL to source list
    echo $'\t'-u URL of Firefox DMG to test 
    echo $'\t'-d description of test run \(use quotes\)
    echo $'\t'-p preference to pass to Firefox 
    echo $'\t'-p1 preference to pass to Firefox test build \(overrides -p\)
    echo $'\t'-p2 preference to pass to Firefox release build \(overrides -p\)$'\n'
    exit
fi
  
if [ -z $source ]
then
    source=alexa
fi  

if [ $pref ] 
then
    pref1=$pref
    pref2=$pref
fi

case $source in
smoke)
    source_name="Smoke list"
    url_source="smoke_list.txt"
;;
test)
    source_name="Test list"
    url_source="test_url_list.txt"
;;
pulse)
    source_name="Pulse top sites"
    url_source="pulse_top_sites_list.txt"
;;
google)
    source_name="Google CT"
    url_source="google_ct_list.txt"
;;
alexa)
    source_name="Alexa top sites"
    url_source="alexa_top_sites.txt"
;;
*)
    source_name="Custom list"
    url_source=$source
esac

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

# tuneable parameters for speed/accuracy
# i.e.,
# number of simultaneous requests = connections_per_second * interval 
#
# TBD: pass in as parameters to scan_urls.js
#
if [[ $platform == "osx" ]]
then
    # higher is faster, lower for more accuracy
    connections_per_second=20
    interval=5
else
    # linux seems to have issues
    # we're going to make this lower for now
    connections_per_second=10
    interval=5
fi

# time between making batches of requests
pause_time=5

DIR=$( cd "$( dirname "$BASH_SOURCE[0]}" )" && pwd )
cd $DIR

# make sure certificate database files are read-only
# this prevents intermediate cert caching when we
# assign custom profiles
chmod 400 profiles/default_profile/cert8.db
chmod 400 profiles/default_profile/key3.db
chmod 400 profiles/test_profile/cert8.db
chmod 400 profiles/test_profile/key3.db


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
TEMP=$TEST_DIR"/temp/"
cd $TEMP

# download test build
wget -O 'FirefoxTestBuild'$file_extension $test_build_url

if [[ $platform == "osx" ]]
then
    open $TEMP'FirefoxTestBuild'$file_extension
    sleep 20
    # move Firefox build from volume to local test folder
    cp -rf "/Volumes/"$volume"/"$app_name $TEMP
    mv $app_name "Firefox_"$branch".app"
    test_build=$TEMP"Firefox_"$branch".app/Contents/MacOS/firefox"
    hdiutil detach "/Volumes/"$volume
else
    # linux - unzip archive
    bzip2 -d $TEMP'FirefoxTestBuild.tar.bz2'
    sleep 5
    tar -xf $TEMP'FirefoxTestBuild.tar'
    sleep 10
    mv firefox firefox_test
    test_build=$TEMP"firefox_test/firefox"
fi

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

# get metadata from each build of Firefox
#
# opening each build will generate a log file,
# which we'll use again when we make a master log file

cd $DIR
echo $($test_build -xpcshell $DIR/build_data.js -log=$TEST_DIR/temp/test_build_metadata.txt)
echo $($release_build -xpcshell $DIR/build_data.js -log=$TEST_DIR/temp/release_build_metadata.txt)
sleep 5

# although we already know some of this data, 
# we are going to capture it again,
# to be sure that we've grabbed the right builds

test_metadata=$( sed '1q;d' $TEST_DIR/temp/test_build_metadata.txt )
test_branch=$( sed '2q;d' $TEST_DIR/temp/test_build_metadata.txt )
test_version=$( sed '3q;d' $TEST_DIR/temp/test_build_metadata.txt )

release_metadata=$( sed '1q;d' $TEST_DIR/temp/release_build_metadata.txt )
release_branch=$( sed '2q;d' $TEST_DIR/temp/release_build_metadata.txt )
release_version=$( sed '3q;d' $TEST_DIR/temp/release_build_metadata.txt )

# grab number of sites in source file
temp=( $( wc -l $DIR"/sources/"$url_source ) )
num_sites="${temp[0]}"

# if description doesn't exist, autogenerate here
if [ -z ${description+x} ]
then
    description="Fx"$test_version" "$test_branch" vs Fx"$release_version" "$release_branch
fi

# generate metadata
l1="timestamp : "$timestamp
l2="branch : "$branch
l3="description : "$description
l4="source : "$source_name" "$num_sites
l5="test build url : "$test_build_url
l6="release build url : "$release_build_url
l7="test build metadata : "$test_metadata
l8="release build metadata : "$release_metadata

echo $l1$'\n'$l2$'\n'$l3$'\n'$l4$'\n'$l5$'\n'$l6$'\n'$l7$'\n'$l8 > $TEST_DIR/temp/metadata.txt

# run scans
run ()
{
    id_arg='-id='$timestamp
    app_path="$1"
    source_arg='-s='"$2"
    log_file='-log='"$3"
    json_arg='-j='"$4"
    cert_arg='-c='"$5"
    profile_arg='-prof='"$6"
    pref_arg='-p='"$7"
    js=$DIR/scan_urls.js
    path_arg=" -d="$DIR"/"
    echo $($app_path -xpcshell $js $id_arg $path_arg $source_arg $log_file $json_arg $cert_arg $profile_arg $pref_arg) 
    sleep $file_system_pause_time
}

# First pass: run list against test build
# Arguments: build path, source URIs, log file name, print json, save certs, prefs, profile
run $test_build $DIR'/sources/'$url_source 'test_error_urls.txt' 0 0 'test_profile'

# First pass: run error URLs against release build
run $release_build $TEST_DIR/temp/test_error_urls.txt 'release_error_urls.txt' 0 0 'default_profile'

# diff results and make a new URL list
cd $TEST_DIR
cd temp
sort -u test_error_urls.txt > test_errors_first_pass.txt
sort -u release_error_urls.txt > release_errors_first_pass.txt
sleep $file_system_pause_time
awk -F" " 'FILENAME=="release_errors_first_pass.txt"{A[$1]=$1} FILENAME=="test_errors_first_pass.txt"{if(A[$1]){}else{print}}' release_errors_first_pass.txt test_errors_first_pass.txt > first-pass-diff.txt
sleep $file_system_pause_time
cut -f1,1 -d " " first-pass-diff.txt | sort -u > first_pass_error_urls.txt

# if there are no errors, stop right now
temp=( $( wc -l "first_pass_error_urls.txt" ) )
num_errors="${temp[0]}"

cd $DIR

# Second pass: run error URL list once again
sleep $file_system_pause_time
run $test_build $TEST_DIR/temp/first_pass_error_urls.txt 'test_error_urls_2.txt' 0 0 'test_profile'


# Second pass: run error URL list from above against release build again
run $release_build $TEST_DIR/temp/test_error_urls_2.txt 'release_error_urls_2.txt' 0 0 'default_profile'

# diff results once again and make a new URL list
cd $TEST_DIR
cd temp
sort -u test_error_urls_2.txt > test_errors_second_pass.txt
sort -u release_error_urls_2.txt > release_errors_second_pass.txt
sleep $file_system_pause_time
awk -F" " 'FILENAME=="release_errors_second_pass.txt"{A[$1]=$1} FILENAME=="test_errors_second_pass.txt"{if(A[$1]){}else{print}}' release_errors_second_pass.txt test_errors_second_pass.txt > second-pass-diff.txt
cd $DIR

# Third pass: run error URL list once again
sleep $file_system_pause_time
run $test_build $TEST_DIR/temp/second-pass-diff.txt 'test_error_urls_3.txt' 0 0 'test_profile'

# Third pass: run error URL list from above against release build again
run $release_build $TEST_DIR/temp/test_error_urls_3.txt 'release_error_urls_3.txt' 0 0 'default_profile'

# diff results once again and make a new URL list
cd $TEST_DIR
cd temp
sort -u test_error_urls_3.txt > test_errors_third_pass.txt
sort -u release_error_urls_3.txt > release_errors_third_pass.txt
sleep $file_system_pause_time
awk -F" " 'FILENAME=="release_errors_third_pass.txt"{A[$1]=$1} FILENAME=="test_errors_third_pass.txt"{if(A[$1]){}else{print}}' release_errors_third_pass.txt test_errors_third_pass.txt > final-diff.txt
sleep $file_system_pause_time
cut -f1,1 -d " " final-diff.txt | sort -u > final_urls.txt
sleep $file_system_pause_time
cd $DIR

temp=( $( wc -l $TEMP"final_urls.txt" ) )
num_errors="${temp[0]}"

if [[ $num_errors > 0 ]]
then
    # Run final error URL list just to grab SSL certificates
    run $test_build $TEST_DIR/temp/final_urls.txt 'final_errors.txt' 1 1 'test_profile'
    sort -u $TEMP"final_errors.txt" > $TEMP"final_errors_sorted.txt"
else
    sort -u $TEMP"final_urls.txt" > $TEMP"final_errors_sorted.txt"
fi

# total time
end_time=$(date +%s)
total_time=$(($end_time - $start_time))
minutes=$((total_time / 60))
l6="Total time : "$minutes" minutes"
l7="++++++++++"

echo $l6$'\n'$l7 > $TEST_DIR/temp/end_time.txt
sleep 2
cat $TEMP"metadata.txt" $TEMP"end_time.txt" $TEMP"final_errors_sorted.txt" > $TEST_DIR/log.txt

# format report into quasi-JSON
t1={
t2=\"
t3=$t2:$t2
t4=$t2,$t2
t5=}

v1=run
v2=branch
v3=errors
v4=description

log_str=$t1$t2$v1$t3$timestamp$t4$v2$t3$branch$t4$v3$t3$num_errors$t4$v4$t3$description$t2$t5
echo $log_str > $TEST_DIR/temp/run_info.txt

sleep 2
cat $DIR/runs/runs.txt $TEST_DIR/temp/run_info.txt > $TEST_DIR/temp/runs.txt
sleep 2
mv $TEST_DIR/temp/runs.txt $DIR/runs/runs.txt

cp $DIR/report_template.htm $TEST_DIR/index.htm

# optional: delete temp folder
# rm -r $TEMP

exit 0