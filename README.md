# OBSOLETE:
This project has been eclipsed by the master TLS Canary project
located at https://github.com/mozilla/tls-canary

Use that instead, it's much better.

For archive purposes:

TLS Canary version 2: Automated testing of Firefox for SSL web compatibility

Results live here:
http://tlscanary.mozilla.org

This project:
* Downloads a branch build and a release build of Firefox.
* Automatically runs thousands of secure sites on those builds.
* Diffs the results and presents potentially broken sites in an HTML page for further diagnosis.

Requirements:
* Mac, for now.
* Forge TLS JS library, minimized, from https://github.com/digitalbazaar/forge

Directions:
* Sync to the Forge TLS library mentioned above
  * Build the repo to produce the file forge.min.js
  * Place this file in the js/forge directory here
* Use the main.sh script to run the test.
* Mandatory parameter:
  * -b branch (beta, aurora, nightly)
* Optional parameters:
  * -s Source list of sites - try 'test' if you are just testing this out 
  * -d Description of test
  * -h Lists other optional parameters

Example:
* main.sh -b=aurora -s=test -d="Just trying this out"

This short test should take 3-4 minutes.

When test run is over, the index.htm page will be updated with a link to your run.
* Click on your run to see results.
* To filter list, click on string in the table and choose option in pop-up to remove from list or to filter search.
* Other features: make charts, export lists, view captured certificates.

New features in version 2:
* Completely rewritten - better UI and page design
* No longer caches intermediate certs - one xpcshell instance per URL
* Far more accurate results (see above, plus additional sorting)
* Historical charting per branch
* Generate charts and lists of current site view
* Now capturing more metadata about connection and certificate
* Save certificate to disk when possible
* Ability to dynamically pass in customized preferences
