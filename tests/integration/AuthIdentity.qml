import QtQuick
import Quickshell
import "../.." as Plugin

ShellRoot {
  Plugin.AuthManager { id: auth; pluginDir: "/nonexistent" }
  Plugin.AuthManager { id: gated; pluginDir: "/nonexistent"; settingsReady: false }
  property int gatedResets: 0
  Connections {
    target: gated
    function onLoggedOut() { gatedResets++ }
  }
  function check(condition, message) {
    if (!condition) throw new Error(message)
  }
  Timer {
    interval: 1
    running: true
    onTriggered: {
    check(auth.lookupPurpose === "restore" || auth.sessionChecked, "Default client ID never restored the saved session")
    check(!gated.initialized, "Auth initialized before settings were ready")
    var queued = false
    gated.withAccessToken(function() { queued = true })
    check(!queued && gated.tokenWaiters.length === 1, "Token request was not queued while gated")
    gated.customClientId = "22222222222222222222222222222222"
    check(gatedResets === 0, "Loading the saved client ID reset the session")
    gated.settingsReady = true
    check(gated.initialized && gated.lookupPurpose === "request",
      "Queued token request was not served after settings were ready")
    gated.customClientId = "33333333333333333333333333333333"
    check(gatedResets === 1 && queued, "Real client ID change did not force re-login")
    auth.accessToken = "old"
    auth.accessTokenExpiresAt = Date.now() + 3600000
    auth.loggedIn = true
    auth.customClientId = "invalid"
    check(auth.accessToken === "", "Old access token survived identity change")
    check(!auth.loggedIn && !auth.validClientId, "Invalid identity was accepted")
    check(auth.resolvedClientId === "", "Invalid identity fell back silently")
    var error = ""
    auth.withAccessToken(function(token, reason) {
      check(token === "", "Old identity token reached a consumer")
      error = reason
    })
    check(error.indexOf("32") >= 0, "Invalid ID has no actionable error")
    var request = {
      readyState: 1, status: 200, responseText: "{}", aborted: false,
      open: function() {}, setRequestHeader: function() {}, send: function() {},
      abort: function() { this.aborted = true }
    }
    auth.xhrFactory = function() { return request }
    auth.customClientId = "11111111111111111111111111111111"
    var delivered = false
    auth.postTokenRequest("", "", function() { delivered = true })
    auth.customClientId = "invalid"
    request.readyState = XMLHttpRequest.DONE
    request.onreadystatechange()
    check(request.aborted, "Old token request was not aborted")
    check(!delivered, "Old identity response reached a new identity")
    console.log("AUTH_IDENTITY_PASS")
    Qt.quit()
    }
  }
}
