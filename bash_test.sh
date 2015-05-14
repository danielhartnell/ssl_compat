#!/bin/bash

# ARGS:
# -u build URL
# -s source URL list
# -d description


for i in "$@"
do
case $i in
    -u=*)
    test_build_url="${i#*=}"
    ;;
    -s=*)
    source="${i#*=}"
    ;;
    -d=*)
    description="${i#*=}"
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
    echo -s name of source list
    echo $'\t'options:
    echo $'\t'smoke, test, pulse, google, combined
    echo $'\t'OR custom URL to source list
    echo -u URL of Firefox DMG to download and test 
    echo -d description of test run in quotes \(optional\) $'\n'
    exit
fi

if [ -z $test_build_url ]
then
    echo "No test build URL specified. Cannot run test."
exit
fi
  
if [ -z $source ]
then
    echo "No URL list specified. Cannot run test."
exit
fi  

if [ -z ${description+x} ]
then
    description="Generic test description"
fi

# source URL list lengths:
# smoke 100
# test 2696
# pulse 211096
# google ct 2678142
# Pulse + Google CT list 2759933

DIR=$( cd "$( dirname "$BASH_SOURCE[0]}" )" && pwd )
cd $DIR

run_date=$(date +%F)
time=$(date +%H-%M-%S)
timestamp=$run_date'-'$time

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
    source_name="Pulse top"
    url_source="pulse_top_sites_list.txt"
;;
google)
    source_name="Google CT"
    url_source="google_ct_list.txt"
;;
combined)
    source_name="Combined list"
    url_source="combined_site_list.txt"
;;
*)
    source_name="Custom list"
    url_source=$source
esac


case $test_build_url in
*"beta"*)
    echo "BETA"
    app_name="Firefox.app"
    volume="Firefox"
;;
*"aurora"*)
    echo "AURORA"
    app_name="FirefoxDeveloperEdition.app"
    volume="FirefoxDeveloperEdition"
;;
*"central"*)
    echo "NIGHTLY"
    app_name="FirefoxNightly.app"
    volume="Nightly"
;;
*)
    echo "RELEASE"
    app_name="Firefox.app"
    volume="Firefox"
;;
esac

curl -# -C - -o 'LatestFirefox.dmg' $test_build_url
open 'LatestFirefox.dmg'
sleep 15

# move Firefox build from dmg to local folder
cp -rf "/Volumes/"$volume"/"$app_name .

# create test folder and temp log file
mkdir $timestamp
TEST_DIR=$DIR"/"$timestamp
cd $TEST_DIR

# grab number of sites in source file
temp=( $( wc -l $DIR"/sources/"$url_source ) )
num_sites="${temp[0]}"

# dump metadata to log file
metadata="Metadata : "$timestamp" : "$source_name" "$num_sites" sites : "$description
test_title=$run_date" : "$source_name" "$num_sites" sites : "$description
echo $metadata$'\n'Build : $test_build_url > log.txt

# get app environment
test_build=$DIR"/"$app_name"/Contents/MacOS/firefox"
appDir=$( dirname $test_build )
greDir=$( dirname $appDir )"/Resources"
export DYLD_LIBRARY_PATH=$appDir

# run test against downloaded Firefox
XPC_SHELL=$DIR"/xpcshell"
$XPC_SHELL -g $greDir -a $appDir -s $DIR"/sslScan.js" $DIR"/sources/"$url_source $TEST_DIR"/"errors.txt $DIR

if [ "$?" -ne "0" ]; then
    XPC_SHELL=$DIR"/xpcshell_new"
    echo "TRYING BACKUP"
    $XPC_SHELL -g $greDir -a $appDir -s $DIR"/sslScan.js" $DIR"/sources/"$url_source $TEST_DIR"/"errors.txt $DIR
fi

echo "First pass on test build of Firefox complete"
cut -f1,1 -d " " errors.txt > error_urls.txt
sleep 2


# run it again to remove noise
$XPC_SHELL -g $greDir -a $appDir -s $DIR"/sslScan.js" $TEST_DIR"/"error_urls.txt $TEST_DIR"/"errors.txt $DIR
echo "Second pass on test build of Firefox complete"

sort -u errors.txt > final_errors.txt
cut -f1,1 -d " " final_errors.txt > error_urls.txt


# run control Fx against error_urls.txt
control_build="/Applications/Firefox.app/Contents/MacOS/firefox"
appDir=$( dirname $control_build )
greDir=$( dirname $appDir )"/Resources"
export DYLD_LIBRARY_PATH=$appDir

XPC_SHELL=$DIR"/xpcshell"
$XPC_SHELL -g $greDir -a $appDir -s $DIR"/sslScan.js" $TEST_DIR"/"error_urls.txt $TEST_DIR"/"_control_errors.txt $DIR

if [ "$?" -ne "0" ]; then
    XPC_SHELL=$DIR"/xpcshell_new"
    $XPC_SHELL -g $greDir -a $appDir -s $DIR"/sslScan.js" $TEST_DIR"/"error_urls.txt $TEST_DIR"/"_control_errors.txt $DIR
fi
echo "Tests on release Firefox complete."

# sort error output
sort -u _control_errors.txt > control_errors.txt

# diff both error files
diff -U 0 final_errors.txt control_errors.txt  | grep "^[+-]" | LC_ALL='C' sort > _error_diff.txt
sleep 3

# merge contents of log file with diff file
cat log.txt _error_diff.txt > error_diff.txt
sleep 2

# generate HTML report
arg_string='s/METADATA/'$test_title'/g'
sed -e "$arg_string" $DIR"/"report_template.htm > "$TEST_DIR/"index.htm
sleep 2

# remove some test files
rm -rf errors.txt
rm -rf log.txt
rm -rf error_urls.txt
rm -rf _control_errors.txt
rm -rf _error_diff.txt
rm -rf $DIR"/LatestFirefox.dmg"
rm -rf $DIR"/"$app_name

open index.htm


