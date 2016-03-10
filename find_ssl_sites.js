/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

"use strict";

const Cc = Components.classes;
const Ci = Components.interfaces;
const Cu = Components.utils;
const Cr = Components.results;

// Register resource://app/ URI

let ios = Cc["@mozilla.org/network/io-service;1"].getService(Ci.nsIIOService);
let resHandler = ios.getProtocolHandler("resource").QueryInterface(Ci.nsIResProtocolHandler);
let mozDir = Cc["@mozilla.org/file/directory_service;1"].getService(Ci.nsIProperties).get("CurProcD", Ci.nsILocalFile);
let mozDirURI = ios.newFileURI(mozDir);
resHandler.setSubstitution("app", mozDirURI);


Cu.import("resource://gre/modules/Services.jsm");
//Cu.import("resource://gre/modules/FileUtils.jsm");
Cu.import("resource://gre/modules/XPCOMUtils.jsm");
Cu.import("resource://gre/modules/NetUtil.jsm");
XPCOMUtils.defineLazyGetter(this, "Timer", function() {
  let timer = {};
  Cu.import("resource://gre/modules/Timer.jsm", timer);
  return timer;
});


if (!arguments || arguments.length < 1) {
  throw "Usage: xpcshell sslScan.js <-u=rank,uri>\n";
}
  
const DEFAULT_TIMEOUT = 10000;
var current_directory;
var completed = false;
var host;
var rank = 0;
var good_domains = [];
var numResults = 0;


for (var i=0;i<arguments.length;i++)
{
  if (arguments[i].indexOf("-d=") != -1)
  {
    current_directory = arguments[i].split("-d=")[1];
  }
  if (arguments[i].indexOf("-u=") != -1)
  {
    host = arguments[i].split("-u=")[1].toLowerCase();
    var temp = host.split(",");
    if (temp.length > 1)
    {
      rank = temp[0];
      host = temp[1];
    }
  }
  if (arguments[i].indexOf("-r=") != -1)
  {
    rank = arguments[i].split("-r=")[1];
  }
  if (arguments[i].indexOf("-p=") != -1)
  {
    var temp1 = arguments[i].split("-p=")[1];
    var temp2 = temp1.split("=");
    var o = {};
    o.name = temp2[0];
    o.value = temp2[1];
    prefs.push (o);
  }
  if (arguments[i].indexOf("-c=") != -1)
  {
    certPath = arguments[i].split("-c=")[1];
  }
  if (arguments[i].indexOf("-j=") != -1)
  {
    print_json = arguments[i].split("-j=")[1];
  }
  if (arguments[i].indexOf("-id=") != -1)
  {
    run_id = arguments[i].split("-id=")[1];
  }
}


function RedirectStopper() {}
RedirectStopper.prototype = {
  // nsIChannelEventSink
  asyncOnChannelRedirect: function(oldChannel, newChannel, flags, callback) {
    throw Cr.NS_ERROR_ENTITY_CHANGED;
  },
  getInterface: function(iid) {
    return this.QueryInterface(iid);
  },
  QueryInterface: XPCOMUtils.generateQI([Ci.nsIChannelEventSink])
};


function queryHost(hostname, callback) {
  let timeout;
  function completed(error, xhr) {
    clearTimeout();
    callback(hostname,error, xhr);
  }
  function errorHandler(e) {
    clearTimeout();
    completed(e.target.channel.QueryInterface(Ci.nsIRequest).status, e.target);
  }
  function readyHandler(e) {
    if (e.target.readyState === 4) {
      clearTimeout();
      completed(null, e.target); // no error
    }
  }
  function clearTimeout()
  {
    if (timeout) {
      Timer.clearTimeout(timeout);
      timeout = null;
    }  
  }
  try {
    let req = Cc["@mozilla.org/xmlextras/xmlhttprequest;1"].createInstance(Ci.nsIXMLHttpRequest);
    timeout = Timer.setTimeout(() => completed(0, req), DEFAULT_TIMEOUT+2000);
    req.open("HEAD", "https://" + hostname, true);
    req.timeout = DEFAULT_TIMEOUT;
    req.channel.notificationCallbacks = new RedirectStopper();
    req.addEventListener("error", errorHandler, false);
    req.addEventListener("load", readyHandler, false);
    req.send();
  } catch (e) {
    infoMessage("Runtime error for XHR: " + e.message)
    completed(-1, req);
  }
}

function loadURI(uri) {
  function recordResult(hostname, error, xhr) {
    if ( error == null )
    {
      good_domains.push ( hostname );
    }
  }
  function handleResult(uri, err, xhr) {
    recordResult(uri, err, xhr);
    numResults++;
    if (numResults == 2)
    {
      if ( good_domains.length == 1 )
      {
        dump ( rank + "," + good_domains[0] + "\n" );
      } else if ( good_domains.length == 2 )
      {
        dump ( rank + "," + host + "\n" );
      } 
      completed = true;
    }
  }
  queryHost(uri, handleResult);
  queryHost("www." + uri, handleResult);
  waitForAResponse(() => completed != true);
}

function waitForAResponse(condition) {
  try {
    let threadManager = Cc["@mozilla.org/thread-manager;1"].getService(Ci.nsIThreadManager);
    let mainThread = threadManager.currentThread;
    while (condition()) {
      mainThread.processNextEvent(true);
    }
  } catch(e) {
    dump ("THREAD ISSUE\n")
    failRun(e.message); 
  }
}

function failRun(arg)
{
  dump ("FAIL: fatal error: " + arg + + "\t" + host + "\n")
  completed = true;
}

try {
  loadURI(host);
} catch (e) {
  dump ("TOTAL FAIL\n")
  failRun(e.message);
}
