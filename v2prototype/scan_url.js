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


/* === This is the stuff you might want to change === */
if (!arguments || arguments.length < 1) {

  throw "Usage: xpcshell sslScan.js <-u=uri>\n";
}

/*

-u :  uri to scan

-p :  preferences to apply (multiple flags supported)
      NOTE: Boolean pref values must be passed in as true/false and not 0/1

-r : (site) rank

*/
  

var host;
var prefs = [];
var rank = 0;

for (var i=0;i<arguments.length;i++)
{
  if (arguments[i].indexOf("-u=") != -1)
  {
    host = arguments[i].split("-u=")[1];
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
}

function applyPrefs()
{
  for (var i=0;i<prefs.length;i++)
  {
    var value = prefs[i].value;
    if ( value == "true" || value == "false" )
    {
      var n = (value == "false" ? 0 : 1);
      try
      {
         Services.prefs.setBoolPref(prefs[i].name, n);
      } catch (e)
      {
        dump ("Incorrect boolean preference name")
      }
    } else if (!isNaN(value))
    {
      try
      {
        Services.prefs.setIntPref(prefs[i],value);
      } catch (e)
      {
        dump ("Incorrect numeric preference name")
      }
    } else {
      try
      {
        Services.prefs.setPref(prefs[i],value);
      } catch (e)
      {
        dump ("Incorrect string preference name")
      }
    }
  }
}
applyPrefs();


const nsINSSErrorsService = Ci.nsINSSErrorsService;
let nssErrorsService = Cc['@mozilla.org/nss_errors_service;1'].getService(nsINSSErrorsService);
const UNKNOWN_ERROR = 0;

function createTCPError(status) {
  let errType, errName;
  if ((status & 0xff0000) === 0x5a0000) { // Security module
    let errorClass;
    // getErrorClass will throw a generic NS_ERROR_FAILURE if the error code is
    // somehow not in the set of covered errors.
    try {
      errorClass = nssErrorsService.getErrorClass(status);
    } catch (ex) {
      errorClass = 'protocol';
    }
    if (errorClass == nsINSSErrorsService.ERROR_CLASS_BAD_CERT) {
      errType = 'certificate';
    } else {
      errType = 'protocol';
    }
  } else {
    errType = 'network';
  }
  return { layer: errType };
}

function analyzeSecurityInfo(xhr, error, hostname, errorCode) {
  var secInfoObj = {};
  dump("\n" + hostname + ": ");
  if (error) {
    dump("failed: " + errorCodeLookup (errorCode) + " (" + error.layer + ")\n");
  } else {
    dump("succeeded\n");
  }
  if (!xhr) {
    dump("\tRequest failed: no information available\n");
    return false;
  }

  try {
    let channel = xhr.channel;
    let secInfo = channel.securityInfo;
    // Print general connection security state

    dump("\n\nSecurity Info:\n");
    if (secInfo instanceof Ci.nsITransportSecurityInfo) {
      secInfo.QueryInterface(Ci.nsITransportSecurityInfo);
      dump("\tSecurity state: ");
      // Check security state flags
      if ((secInfo.securityState & Ci.nsIWebProgressListener.STATE_IS_SECURE) ===
          Ci.nsIWebProgressListener.STATE_IS_SECURE) {
        dump("secure\n");
      } else if ((secInfo.securityState & Ci.nsIWebProgressListener.STATE_IS_INSECURE) ===
                 Ci.nsIWebProgressListener.STATE_IS_INSECURE) {
        dump("insecure\n");
      } else if ((secInfo.securityState & Ci.nsIWebProgressListener.STATE_IS_BROKEN) ===
                 Ci.nsIWebProgressListener.STATE_IS_BROKEN) {
        dump("unknown\n");
        dump("\tSecurity description: " + secInfo.shortSecurityDescription + "\n");
        dump("\tSecurity error message: " + secInfo.errorMessage + "\n");
      }
    } else {
      dump("\tNo security info available for this channel\n");
    }

    // Print SSL certificate details
    if (secInfo instanceof Ci.nsISSLStatusProvider) {
      if (secInfo.QueryInterface(Ci.nsISSLStatusProvider).SSLStatus != null)
      {
      let cert = secInfo.QueryInterface(Ci.nsISSLStatusProvider)
        .SSLStatus.QueryInterface(Ci.nsISSLStatus).serverCert;

      /*
      var isEV = secInfo.QueryInterface(Ci.nsISSLStatusProvider)
       .SSLStatus.QueryInterface(Ci.nsISSLStatus)
       .isExtendedValidation;
      */



      dump("\tCommon name (CN) = " + cert.commonName + "\n");
      dump("\tOrganisation = " + cert.organization + "\n");
      dump("\tIssuer = " + cert.issuerOrganization + "\n");
      dump("\tSHA1 fingerprint = " + cert.sha1Fingerprint + "\n");

      let validity = cert.validity.QueryInterface(Ci.nsIX509CertValidity);
      dump("\tValid from " + validity.notBeforeGMT + "\n");
      dump("\tValid until " + validity.notAfterGMT + "\n");
      dump("\n\n");

      // only write cert if we have one! 
      // raw data
      var l={};
      var raw = cert.getRawDER (l);
      writeCertToDisk(certFile,buildDER(raw))

     // currently unused functionality, but you could check for a root cert here
     // getRootCert (cert, hostname);
      dump ("\nchainLength: " + cert.getChain().length + "\n")

      var rootCert = getRootCert(cert);
      dump ("Root cert commonName: " + rootCert.commonName + "\n");
      dump ("Root cert issuerOrganization: " + rootCert.issuerOrganization + "\n");
      dump ("Root cert issuerOrganizationUnit: " + rootCert.issuerOrganizationUnit + "\n");
      dump ("Root cert sha1Fingerprint: " + rootCert.sha1Fingerprint + "\n");

    }
    }

    // THIS IS WHERE WE LOOK FOR ERRORS, regardless of error type, except for some network errors TBD
    if (error != null) {
      var errMsg = secInfo.errorMessage.split("(Error code: ")[1].split(")")[0];
      secInfoObj.message = errMsg;
      secInfoObj.type = error.layer;
      dump (errMsg + "\n")
    }
  } catch(err) {
    // secInfo is null, so we need to look at error for a specific network error message
    // https://developer.mozilla.org/en-US/docs/Mozilla/Errors

      dump("\nError: " + errorCodeLookup(errorCode) + "\n");
      secInfoObj.message = errorCodeLookup(errorCode);
      secInfoObj.type = error.layer;
  }
  return secInfoObj;
}
function errorCodeLookup(error)
{
  var msg;
  switch(error)
  {
    case 0x804b001e: 
      msg = "domain_not_found_error";
      break;
    case 0x804b000d: 
      msg = "connection_refused_error";
      break;
    case 0x804b0014: 
      msg = "net_reset_error";
      break;
    case 0x8000ffff: 
      msg = "unexpected_error";
      break;
    default:
      msg = "unknown_error";
      break;
  }
  return msg;
}

function buildDER(chars){
    var result = "";
    for (var i=0; i < chars.length; i++)
        result += String.fromCharCode(chars[i]);
    return result;
}

function getRootCert(cert)
{
  var chain = cert.getChain().enumerate();
  var childCert;
  while ( chain.hasMoreElements() )
  {
    childCert = chain.getNext().QueryInterface(Ci.nsISupports)
      .QueryInterface(Ci.nsIX509Cert);
  }
  return childCert;
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
    callback(error, xhr);
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
    let req = Cc["@mozilla.org/xmlextras/xmlhttprequest;1"]
      .createInstance(Ci.nsIXMLHttpRequest);
    timeout = Timer.setTimeout(() => completed(UNKNOWN_ERROR, req), 12000);
    req.open("HEAD", "https://" + hostname, true);
    req.timeout = 10000;
    req.channel.notificationCallbacks = new RedirectStopper();
    req.addEventListener("error", errorHandler, false);
    req.addEventListener("load", readyHandler, false);
    req.send();
  } catch (err) {
    dump("ERROR: runtime exception making request to " + hostname + ": " + err.message + "\n");
    completed(-1, req);
  }
}

function writeCertToDisk(outputStream, data) {
  outputStream.write(data, data.length);
}



function loadURI(uri, resultObj) {
  function recordResult(hostname, error, xhr) {
    let currentError = error ? createTCPError(error) : null;
    let secInfoObj = analyzeSecurityInfo(xhr, currentError, hostname, error);
    dump ("Record results here. \n");
  }
  function handleResult(err, xhr) {
    recordResult(uri, err, xhr);
    completed = true;
    FileUtils.closeSafeFileOutputStream(certFile);
  }
  queryHost(uri, handleResult);
  waitForAResponse(() => completed != true);
}


function waitForAResponse(condition) {
  try {
    let threadManager = Cc["@mozilla.org/thread-manager;1"]
      .getService(Ci.nsIThreadManager);
    let mainThread = threadManager.currentThread;
    while (condition()) {
      mainThread.processNextEvent(true);
    }
  } catch(e) {
    dump(e.message); 
  }
}
 
function openFile(name) {
  let file = Cc["@mozilla.org/file/local;1"].createInstance(Components.interfaces.nsILocalFile);
  file.initWithPath("/Users/mwobensmith/ssl_compat/v2prototype/" + name);
  try
  {
    var fos = FileUtils.openSafeFileOutputStream(file);
    return fos;
  } catch (e)
  {
    dump (e.message)
  }
}

function createDefaultObject()
{
  var o = {};
  o.site_info = {};
  o.site_info.uri= host;
  o.site_info.rank=rank;
  o.site_info.connection_speed="";
  o.site_info.timestamp="";
  
  o.error_info = {};
  o.error_info.code="";
  o.error_info.type="";
  o.error_info.message="";
  
  o.tls_info = {};
  o.tls_info.version="";
  o.tls_info.cipherName="";
  o.tls_info.keyLength="";
  o.tls_info.secretKeyLength="";
  
  o.cert_info = {};
  o.cert_info.isEV="";
  o.cert_info.certifiedUsages="";
  o.cert_info.chainLength="";
  o.cert_info.nickname="";
  o.cert_info.emailAddress="";
  o.cert_info.subjectName="";
  o.cert_info.commonName="";
  o.cert_info.extendedKeyUsage="";
  o.cert_info.certificateSubjectAltName="";
  o.cert_info.certificateKeyUsage="";
  o.cert_info.organization="";
  o.cert_info.organizationalUnit="";
  o.cert_info.validityNotBefore="";
  o.cert_info.validityNotAfter="";
  o.cert_info.sha1Fingerprint="";
  o.cert_info.sha256Fingerprint="";
  o.cert_info.issuerName="";
  o.cert_info.issuerOrganization="";
  o.cert_info.rootCertificateCommonName="";
  o.cert_info.rootCertificateOrganization="";
  o.cert_info.rootCertificateOrganizationalUnit="";
  o.cert_info.rootCertificateSHA1Fingerprint="";
  
  return o;
}


var completed = false;


try{
  var certFile = openFile(arguments[0]+ ".der");
  try {
    var obj = createDefaultObject();
    loadURI(host, obj);

    dump (JSON.stringify(obj));

  } catch (e) {
    dump(e.message + "\n");
  }
} catch (e)
{
  dump (e.message)
}

