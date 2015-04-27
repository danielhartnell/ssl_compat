# ssl_compat
Automated testing of Firefox for SSL web compatibility

This project:
* Downloads a branch build of Firefox.
* Automatically runs thousands of secure sites on that build.
* Runs any errors on a release version of Firefox. 
* Diffs the results and presents potentially broken sites in an HTML page for further diagnosis.

Requirements:
* Mac, for now
* Pre-installed release version of Firefox in default location


Directions:
* Use the bash_test.sh script to run the test
* Specify three parameters:
  * -u Build URL
  * -s Source list of sites
  * -d Decription of test

Example:
bash_test.sh -u=http://ftp.mozilla.org/pub/mozilla.org/firefox/candidates/38.0b8-candidates/build2/mac/en-US/Firefox%2038.0b8.dmg -s=smoke -d="Simple smoke test of Fx38.0b8 against Fx release"

* When test run is over, an HTML page will be opened with lists of flagged sites.
* Go to Options tab and click "Show broken sites only".
* Go to first tab and view list. These sites are uniquely broken in your test build.
* To filter list, click on string in the table and choose option in pop-up to remove from list or to filter search.


More information is available in the index.htm page located within.



