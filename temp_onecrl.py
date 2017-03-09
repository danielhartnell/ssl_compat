import logging
import os
import sys
import time
import urllib2



workdir=""

one_crl_environ="prod"

# find go installation and create subdirectories
locations = os.environ.get("PATH").split(os.pathsep)
candidates = []
for location in locations:
    candidate = os.path.join(location, 'go')
    if os.path.isfile(candidate):
        candidates.append(candidate)
go_orig = candidates[0]
go_orig_dir = os.path.dirname(go_orig)
go_path = os.readlink(go_orig)
go_real_path = os.path.realpath(go_orig)
go_src_path = os.path.normpath(go_real_path+"../../../src")


print (go_src_path)


#os.mkdir(go_src_path+"/github.com")
#os.mkdir(go_src_path+"/github.com/mozmark")


print ("done")
# put OneCRL code into this directory


# obtain OneCRL list and write to disk


# remove directory