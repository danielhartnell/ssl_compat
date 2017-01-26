cd tls-canary
mkdir ./runs
virtualenv --always-copy .
. bin/activate
pip install -e .
tls_canary smoke   —reportdir=./runs