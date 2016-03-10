#!/bin/bash

url_source="top-1m.csv"
test_build="/Applications/Firefox.app/Contents/MacOS/firefox"

# required to allow for file system operations
file_system_pause_time=5

# number of simultaneous requests
batch_quantity=100

# time between making batches of requests
pause_time=5

DIR=$( cd "$( dirname "$BASH_SOURCE[0]}" )" && pwd )
cd $DIR

# run scans
run ()
{
    input_file=$DIR"/sources/"$url_source
    app_dir=$( dirname $test_build )
    gre_dir=$( dirname $app_dir )"/Resources"

    shell_path=$DIR"/xpcshell" 

    path_arg=" -d="$PWD

    js=$DIR/find_ssl_sites.js
    LOG=$DIR"/sources/alexa_top_n_sites.txt"

    site_list=$( cat $input_file )

    n=0
    for line in $site_list; do
        uri_array[n]=$line
        n=$(($n+1))
    done

    exec 6>&1
    exec > $LOG

    export DYLD_LIBRARY_PATH=$app_dir

    index=0

    for uri in $site_list; do
        index=$(($index+1))
        uri_arg=" -u="$uri
        echo $($shell_path -g $gre_dir -a $app_dir -s $js$uri_arg$path_arg) &
        if [ $index -gt $batch_quantity ]; then
            index=0
            sleep $pause_time
        fi
    done

    sleep $file_system_pause_time
}

run  



