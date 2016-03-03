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
    echo $'\t'$'\t'smoke, test, alexa, pulse \(default\), google
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
    source=pulse
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
    # we will assume linux
    platform=linux64
    file_extension=.tar.bz2
fi

# auto branch detection
master_url="https://www.mozilla.org/en-US/firefox/notes/"

wget -O 'temp.htm' $master_url

#curl -# -C - -o 'temp.htm' $master_url

src=$( cat temp.htm )
src=${src##*Notes (}
release=${src%%)*}
src=${src%%.0*}
src=${src%%.*}
beta=$(($src+1))
aurora=$(($src+2))".0a2"
nightly=$(($src+3))".0a1"
rm -rf temp.htm

# b2g URL - used to get xpcshell binary
b2g_url=http://ftp.mozilla.org/pub/b2g/nightly/latest-mozilla-central/



# construct URLs based on platform
if [[ $platform == "osx" ]]
then
    xpcshell_url=$b2g_url"firefox-"$nightly".en-US.mac64.dmg"
    release_build_url="https://download.mozilla.org/?product=firefox-latest&os="$platform"&lang=en-US"
    beta_build_url="https://download.mozilla.org/?product=firefox-beta-latest&os="$platform"&lang=en-US"
    aurora_build_url="https://download.mozilla.org/?product=firefox-aurora-latest&os="$platform"&lang=en-US"
    nightly_build_url="https://download.mozilla.org/?product=firefox-nightly-latest&os="$platform"&lang=en-US"
else
    #xpcshell_url=$b2g_url"graphene-"$nightly".en-US.linux-x86_64.tar.bz2"
    xpcshell_url=$xpcshell_nightly_url
	beta_build_url='http://download.cdn.mozilla.net/pub/firefox/releases/'$beta'b1/linux-x86_64/en-US/sdk/firefox-'$beta'b1.sdk.tar.bz2'
	aurora_build_url='http://download.cdn.mozilla.net/pub/firefox/nightly/latest-mozilla-aurora/firefox-'$aurora'.en-US.linux-x86_64.sdk.tar.bz2'
	nightly_build_url='http://download.cdn.mozilla.net/pub/firefox/nightly/latest-mozilla-central/firefox-'$nightly'.en-US.linux-x86_64.sdk.tar.bz2'
	release_build_url='http://ftp.mozilla.org/pub/firefox/releases/'$release'/linux-x86_64/en-US/firefox-'$release'.sdk.tar.bz2'

fi


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

echo $version

# required to allow for file system operations
file_system_pause_time=5

# number of simultaneous requests
batch_quantity=10

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
#cd $DIR
TEMP=$TEST_DIR"/temp/"
cd $TEMP

# temporary
#
# changes are coming that will eventually obsolete this section
# but for now, we'll need to hard-code some URLs for xpcshell,
# and only for linux
#
#
# download xpcshell binary, if needed
xpcshell_path=$DIR'/xpcshell'
if [ -e "$xpcshell_path" ]
then
    echo Has xpcshell installed
else

    if [[ $platform == "osx" ]]
    then
    	echo Downloading xpcshell
    	echo $xpcshell_url
    	wget -O 'temp'$file_extension $xpcshell_url
        open $TEMP'temp.dmg'
        sleep 15
        cp -rf "/Volumes/Nightly/FirefoxNightly.app/Contents/MacOS/xpcshell" $DIR
        hdiutil detach "/Volumes/Nightly"
    else
        # linux - unzip archive
	#bzip2 -d $TEMP'temp.tar.bz2'
	#sleep 5
	#tar -xf $TEMP'temp.tar'
	#sudo rm -rf $TEMP'Firefox '$version'.tar'
	#sleep 10
	#cp -rf $TEMP'graphene/xpcshell' $DIR
	#rm -rf $TEMP'graphene'
	#rm -rf $TEMP'temp.tar'
        foo=1
    fi
fi

# download test build
wget -O 'Firefox '$version$file_extension $test_build_url

if [[ $platform == "osx" ]]
then
    open $TEMP'Firefox '$version$file_extension
    sleep 15
    # move Firefox build from volume to local test folder
    cp -rf "/Volumes/"$volume"/"$app_name $TEMP
    mv $app_name "Firefox_"$branch".app"
    test_build=$TEMP"Firefox_"$branch".app/Contents/MacOS/firefox"
    hdiutil detach "/Volumes/"$volume
else
    # linux - unzip archive
    bzip2 -d $TEMP'Firefox '$version'.tar.bz2'
    sleep 5
    tar -xf $TEMP'Firefox '$version'.tar'
    sleep 10
    #rm -rf $TEMP'Firefox '$version'.tar'
    mv firefox-sdk firefox_test
    test_build=$TEMP"firefox_test/bin/firefox"
    cp -r firefox_test/sdk/bin/* firefox_test/bin
    chmod u+x firefox_test/bin/xpcshell
fi

wget -O 'Firefox '$src$file_extension $release_build_url
sleep 15

if [[ $platform == "osx" ]]
then
    # move Firefox build from dmg to local test folder
    open "Firefox "$src$file_extension
    sleep 15
    cp -rf "/Volumes/Firefox/Firefox.app" $TEMP
    mv Firefox.app Firefox_Release.app
    control_build=$TEMP"Firefox_Release.app/Contents/MacOS/firefox"
    hdiutil detach /Volumes/Firefox
else
    # linux
    bzip2 -d $TEMP'Firefox '$src'.tar.bz2'
    sleep 5
    tar -xf $TEMP'Firefox '$src'.tar'
    sleep 10
    #rm -rf $TEMP'Firefox '$src'.tar'
    mv firefox-sdk firefox_release
    #mv $DIR/xpcshell $TEMP"firefox_release/"
    control_build=$TEMP"firefox_release/bin/firefox"
    cp -r firefox_release/sdk/bin/* firefox_release/bin
    chmod u+x firefox_release/bin/xpcshell
    sleep 5
fi


echo PATHS
echo $test_build
echo $control_build


# grab number of sites in source file
temp=( $( wc -l $DIR"/sources/"$url_source ) )
num_sites="${temp[0]}"

# if description doesn't exist, autogenerate here
if [ -z ${description+x} ]
then
    description="Fx"$version" "$branch" vs Fx"$src" release"
fi


# get metadata from each build of Firefox
#
# opening each build will generate a log file,
# which we'll use again when we make a master log file

cd $DIR

app_dir=$( dirname $test_build )
if [[ $platform == "osx" ]]
then
	gre_dir=$( dirname $app_dir )"/Resources"
else
	gre_dir=$( dirname $test_build )
fi

# linux: move xpcshell plus librarys into bin folder
# chmod u+x xpcshell
# export LD_LIBRARY_PATH=.

export DYLD_LIBRARY_PATH=$app_dir
export LD_LIBRARY_PATH=$app_dir
echo $($TEMP'firefox_test/bin/xpcshell' -g $gre_dir -a $app_dir -s $DIR/build_data.js -log=$TEST_DIR/temp/test_build_metadata.txt)



app_dir=$( dirname $control_build )
if [[ $platform == "osx" ]]
then
	gre_dir=$( dirname $app_dir )"/Resources"
else
	gre_dir=$( dirname $control_build )
fi
export DYLD_LIBRARY_PATH=$app_dir
export LD_LIBRARY_PATH=$app_dir
echo $($TEMP'firefox_release/bin/xpcshell' -g $gre_dir -a $app_dir -s $DIR/build_data.js -log=$TEST_DIR/temp/release_build_metadata.txt)

sleep 5

test_metadata=$( cat $TEST_DIR/temp/test_build_metadata.txt )
release_metadata=$( cat $TEST_DIR/temp/release_build_metadata.txt )

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
	input_file="$1"
	log_file="$2"
	app_dir=$( dirname "$3" )
	if [[ $platform == "osx" ]]
	then
		gre_dir=$( dirname $app_dir )"/Resources"
	else
		gre_dir=$app_dir
	fi
	pref_arg=' -p='"$4"
	json_arg="$5"
	cert_arg="$6"
	if [[ $platform == "osx" ]]
	then
		shell_path=$DIR"/xpcshell" 
	else
		shell_path=$app_dir"/xpcshell"
	fi

	path_arg=" -d="$PWD

	js=$DIR/scan_url.js
	LOG=$TEST_DIR"/temp/"$log_file

	site_list=$( cat $input_file )

	n=0
	for line in $site_list; do
		uri_array[n]=$line
		n=$(($n+1))
	done

	exec 6>&1
	exec > $LOG

	export DYLD_LIBRARY_PATH=$app_dir
	export LD_LIBRARY_PATH=$app_dir

	index=0

	for uri in $site_list; do
		index=$(($index+1))
		uri_arg=" -u="$uri

		echo $($shell_path -g $gre_dir -a $app_dir -s $js$uri_arg$path_arg $pref_arg$json_arg$cert_arg) &
		if [ $index -gt $batch_quantity ]; then
			index=0
			sleep $pause_time
		fi
	done

	sleep $file_system_pause_time
}

# nightly --> nightly-errors
run $DIR/sources/$url_source test_error_urls.txt $test_build $pref1

# run nightly urls against release --> release-errors
run $TEST_DIR/temp/test_error_urls.txt control_error_urls.txt $control_build $pref2


# diff results --> diff
cd $TEST_DIR
cd temp
sort -u test_error_urls.txt > test_errors_first_pass.txt
sort -u control_error_urls.txt > control_errors_first_pass.txt
sleep $file_system_pause_time
awk -F" " 'FILENAME=="control_errors_first_pass.txt"{A[$1]=$1} FILENAME=="test_errors_first_pass.txt"{if(A[$1]){}else{print}}' control_errors_first_pass.txt test_errors_first_pass.txt > first-pass-diff.txt


# cut urls --> diff-urls
sleep $file_system_pause_time
cut -f1,1 -d " " first-pass-diff.txt | sort -u > first_pass_error_urls.txt
cd $DIR

# run urls once again in nightly, save final nightly log --> final-nightly-errors
sleep $file_system_pause_time
run $TEST_DIR/temp/first_pass_error_urls.txt test_error_urls_2.txt $test_build $pref1


# run these urls in release once again --> final-release-errors
run $TEST_DIR/temp/test_error_urls_2.txt control_error_urls_2.txt $control_build $pref2


# diff error logs --> final-diff
cd $TEST_DIR
cd temp
sort -u test_error_urls_2.txt > test_errors_second_pass.txt
sort -u control_error_urls_2.txt > control_errors_second_pass.txt
sleep $file_system_pause_time
awk -F" " 'FILENAME=="control_errors_second_pass.txt"{A[$1]=$1} FILENAME=="test_errors_second_pass.txt"{if(A[$1]){}else{print}}' control_errors_second_pass.txt test_errors_second_pass.txt > second-pass-diff.txt
cd $DIR


# run urls once again in nightly, save final nightly log --> final-nightly-errors
sleep $file_system_pause_time
run $TEST_DIR/temp/second-pass-diff.txt test_error_urls_3.txt $test_build $pref1

# run these urls in release once again --> final-release-errors
run $TEST_DIR/temp/test_error_urls_3.txt control_error_urls_3.txt $control_build $pref2

# diff error logs --> final-diff
cd $TEST_DIR
cd temp
sort -u test_error_urls_3.txt > test_errors_third_pass.txt
sort -u control_error_urls_3.txt > control_errors_third_pass.txt
sleep $file_system_pause_time
awk -F" " 'FILENAME=="control_errors_third_pass.txt"{A[$1]=$1} FILENAME=="test_errors_third_pass.txt"{if(A[$1]){}else{print}}' control_errors_third_pass.txt test_errors_third_pass.txt > final-diff.txt


# cut urls from diff
# run again and generate certs

sleep $file_system_pause_time
cut -f1,1 -d " " final-diff.txt | sort -u > final_urls.txt
sleep $file_system_pause_time
cd $DIR

run $TEMP"final_urls.txt" final_errors.txt $test_build $pref1 -j=true -c=$TEST_DIR"/certs/" 

sort -u $TEMP"final_errors.txt" > $TEMP"final_errors_sorted.txt"

# total time
end_time=$(date +%s)
total_time=$(($end_time - $start_time))
minutes=$((total_time / 60))
l6="Total time : "$minutes" minutes"
l7="++++++++++"

echo $l6$'\n'$l7 > $TEST_DIR/temp/end_time.txt
sleep 2
cat $TEMP"metadata.txt" $TEMP"end_time.txt" $TEMP"final_errors_sorted.txt" > $TEST_DIR/log.txt


# update runs file 
# grab number of sites in final error file
temp=( $( wc -l $TEMP"final_errors_sorted.txt" ) )
num_errors="${temp[0]}"

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
rm -r $TEMP


