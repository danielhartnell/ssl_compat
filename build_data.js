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
let resHandler = ios.getProtocolHandler("resource")
  .QueryInterface(Ci.nsIResProtocolHandler);
let mozDir = Cc["@mozilla.org/file/directory_service;1"]
  .getService(Ci.nsIProperties)
  .get("CurProcD", Ci.nsILocalFile);
let mozDirURI = ios.newFileURI(mozDir);
resHandler.setSubstitution("app", mozDirURI);


Cu.import("resource://gre/modules/Services.jsm");
Cu.import("resource://gre/modules/FileUtils.jsm");
Cu.import("resource://gre/modules/XPCOMUtils.jsm");
Cu.import("resource://gre/modules/NetUtil.jsm");
XPCOMUtils.defineLazyGetter(this, "Timer", function() {
  let timer = {};
  Cu.import("resource://gre/modules/Timer.jsm", timer);
  return timer;
});

var log;
for (var i=0;i<arguments.length;i++)
{
  if (arguments[i].indexOf("-log=") != -1)
  {
    log = arguments[i].split("-log=")[1];
  } else {
    throw "No path to log file given. Aborting test.\n";
  }
}

Cu.import("resource://gre/modules/AppConstants.jsm");

let nssInfo = Cc["@mozilla.org/security/nssversion;1"].getService(Ci.nsINSSVersion);
let nssVersion = "NSS " + nssInfo.NSS_Version;
let nsprVersion = "NSPR " + nssInfo.NSPR_Version;

// currently unused
let appVersion = AppConstants.MOZ_APP_VERSION_DISPLAY;
let branch = AppConstants.MOZ_UPDATE_CHANNEL;


function writeLog() {
  let file = Cc["@mozilla.org/file/local;1"].createInstance(Components.interfaces.nsILocalFile);
  file.initWithPath(log);
  let fos = FileUtils.openSafeFileOutputStream(file);
  dump("Opened " + file.path + " for log\n");
  var msg = nssVersion + ", " + nsprVersion + "\n" + branch + "\n" + appVersion;

  fos.write(msg, msg.length);

  FileUtils.closeSafeFileOutputStream(fos);
}

writeLog();

dump ("OK\n\n");
