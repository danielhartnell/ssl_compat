#!/bin/bash

path_arg=" -d="$PWD
cert_arg=" -c=true"

command="/Applications/Firefox.app/Contents/MacOS/xpcshell_new /Users/mwobensmith/ssl_compat/v2prototype/scan_url.js -u="

#command="/Applications/Nightly.app/Contents/MacOS/xpcshell_new /Users/mwobensmith/ssl_compat/v2prototype/scan_url.js -u="

newline=$'\n'
return=$'\r'
log_data="test metadata"$return'+++ blah'$return'--- blah'$return
space=' '

file="./final-urls.txt"
site_list=$(cat $file)

# create array
n=0
for line in $site_list; do
uri_array[n]=$line
n=$(($n+1))
done
echo $n sites total

# redirect stdout to log file
# http://www.tldp.org/LDP/abs/html/x17974.html

LOG=final-release-errors.txt
exec 6>&1
exec > $LOG

limit=100
index=0

for uri in ${uri_array[@]}; do
index=$(($index+1))
echo $($command$uri$path_arg) &
if [ $index -gt $limit ]; then
index=0
sleep 5
fi

done

# nightly --> nightly-errors
# cut urls --> nightly-error-urls
# run nightly urls against release --> release-errors
# diff results --> diff
# cut urls --> diff-urls
# run urls once again in nightly, save final nightly log --> final-nightly-errors
# cut urls from final nightly log --> final-nightly-error-urls
# run these urls in release once again --> final-release-errors
# diff error logs --> final-diff

exit 0