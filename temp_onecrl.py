import logging
import os
import sys
import time
import urllib2
from shutil import rmtree



workdir="./test"

one_crl_environ="prod"

# find go installation and create subdirectories
locations = os.environ.get("PATH").split(os.pathsep)
candidates = []
for location in locations:
    candidate = os.path.join(location, 'go')
    if os.path.isfile(candidate):
        candidates.append(candidate)
go_orig = candidates[0]
go_real_path = os.path.realpath(go_orig)
go_src_path = os.path.normpath(go_real_path+"../../../src")

temp_dir = go_src_path+"/github.com"

if not os.path.exists(temp_dir):
	os.mkdir(temp_dir)
	os.mkdir(temp_dir+"/mozmark")
	os.mkdir(temp_dir+"/mozmark/OneCRL-Tools")


# put OneCRL code into this directory
git_src_path = temp_dir+"/mozmark/OneCRL-Tools"
cmd1 = "git clone https://github.com/mozmark/OneCRL-Tools " + git_src_path
os.system(cmd1)

# obtain OneCRL list and write to disk
one_crl_app = git_src_path+"/oneCRL2RevocationsTxt/main.go"
cmd2 = "go run "+one_crl_app+ " "+one_crl_environ+" > "+workdir+"/revocations.txt"
os.system(cmd2)

# remove temporary directory
rmtree(temp_dir)


print ("done")
