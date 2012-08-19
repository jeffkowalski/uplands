#include "WiFly.h"

boolean WiFlyDevice::findInResponse(const char *toMatch,
                                    unsigned int timeOut = 1000) {
  for (unsigned int offset = 0; offset < strlen(toMatch); offset++) {
    // Reset after successful character read
    unsigned long timeOutTarget = millis() + timeOut; // Doesn't handle timer wrapping

    while (!uart->available()) {
      // Wait, with optional time out.
      if (timeOut > 0 && millis() > timeOutTarget)
          return false;
      delay (1); // This seems to improve reliability slightly
    }

    // We read this separately from the conditional statement so we can
    // log the character read when debugging.
    int byteRead = uart->read();

    delay (1); // Removing logging may affect timing slightly

    if (byteRead != toMatch[offset]) {
      offset = 0;
      // Ignore character read if it's not a match for the start of the string
      if (byteRead != toMatch[offset]) 
        offset = -1;
      continue;
    }
  }

  return true;
}


boolean WiFlyDevice::responseMatched (const char *toMatch) {
  boolean       matchFound = true;

  for (unsigned int offset = 0; offset < strlen(toMatch); offset++) {
    unsigned long timeout = millis();
    while (!uart->available()) {
      if (millis() - timeout > 5000)
        return false;
      delay(1); // This seems to improve reliability slightly
    }
    
    if (uart->read() != toMatch[offset]) {
      matchFound = false;
      break;
    }
  }
  return matchFound;
}


#define COMMAND_MODE_ENTER_RETRY_ATTEMPTS 5
#define COMMAND_MODE_GUARD_TIME 250 // in milliseconds

boolean WiFlyDevice::enterCommandMode(boolean isAfterBoot) {
  // Note: We used to first try to exit command mode in case we were
  //       already in it. Doing this actually seems to be less
  //       reliable so instead we now just ignore the errors from
  //       sending the "$$$" in command mode.

  for (int retryCount = 0;
       retryCount < COMMAND_MODE_ENTER_RETRY_ATTEMPTS;
       retryCount++) {

    if (isAfterBoot) delay(1000); // This delay is so characters aren't missed after a reboot.

    delay(COMMAND_MODE_GUARD_TIME);

    uart->print(F("$$$"));

    delay(COMMAND_MODE_GUARD_TIME);

    uart->println();
    uart->println();

    uart->println(F("ver"));

    if (findInResponse("\r\nWiFly Ver", 1000)) {
      skipRemainderOfResponse() ;
      return true;
    }
  }
  return false;
}

void WiFlyDevice::skipRemainderOfResponse() {
  while (!(uart->available() && (uart->read() == '\n'))) {}
}

void WiFlyDevice::waitForResponse(const char *toMatch) {
   // Note: Never exits if the correct response is never found
   findInResponse(toMatch);
}

WiFlyDevice::WiFlyDevice() {
  // The WiFly requires the server port to be set between the `reboot`
  // and `join` commands so we go for a "useful" default first.
  serverPort = DEFAULT_SERVER_PORT;
  serverConnectionActive = false;
}

void  WiFlyDevice::setUart(Stream* newUart) {
  uart = newUart;
}

boolean WiFlyDevice::begin() {
  if (!reboot()) return false; // Reboot to get device into known state
  setConfiguration();
  return true;
}


#define SOFTWARE_REBOOT_RETRY_ATTEMPTS 5

boolean WiFlyDevice::reboot () {
  if (enterCommandMode (true))
    for (int tries = 0; tries < SOFTWARE_REBOOT_RETRY_ATTEMPTS; tries++) {
      uart->println(F("reboot"));
      // For some reason the full "*Reboot*" message doesn't always
      // seem to be received so we look for the later "*READY*" message instead.
      if (findInResponse("*READY*", 2000))
        return true;
    }
  return false;
}

boolean WiFlyDevice::sendCommand(const __FlashStringHelper *command,
                                 boolean isMultipartCommand = false,
                                 const char *expectedResponse = "AOK") {
  uart->print(command);
  delay(20);
  if (!isMultipartCommand) {
    //uart->flush();
    uart->println();
    if (!findInResponse(expectedResponse, 1000))
      return false;
  }
  return true;
}


boolean WiFlyDevice::sendCommand(const char *command,
                                 boolean isMultipartCommand = false,
                                 const char *expectedResponse = "AOK") {
  uart->print(command);
  delay(20);
  if (!isMultipartCommand) {
    //uart->flush();
    uart->println();
    if (!findInResponse(expectedResponse, 1000))
      return false;
  }
  return true;
}


void WiFlyDevice::setConfiguration() {
  enterCommandMode();

  // Set server port
  sendCommand(F("set ip localport "), true);
  uart->print (serverPort);
  sendCommand("");
  
  sendCommand(F("set comm remote 0"));  // Turn off remote connect message
  sendCommand(F("set t z 23"));
  sendCommand(F("set time address 129.6.15.28"));  // time-a.nist.gov	129.6.15.28	NIST, Gaithersburg, Maryland
  sendCommand(F("set time port 123"));   // 123 matches default
  sendCommand(F("set time enable 15"));  // fetch time every 15 minutes
}


boolean WiFlyDevice::join(const char *ssid) {
  sendCommand(F("join "), true);
  if (sendCommand(ssid, false, "Associated!")) {
    waitForResponse("Listen on ");
    skipRemainderOfResponse();
    return true;
  }
  return false;
}


boolean WiFlyDevice::join(const char *ssid, const char *passphrase, boolean isWPA) {
  sendCommand(F("set wlan "), true);
  if (isWPA)
    sendCommand(F("passphrase "), true);
  else 
    sendCommand(F("key "), true);
  sendCommand(passphrase);

  return join(ssid);
}


#define TIME_SIZE 11 // 1311006129
long WiFlyDevice::getTime(){
  /* Returns the time based on the NTP settings and time zone. */
  enterCommandMode();

  sendCommand(F("show t t"), false, "RTC=");

  // copy the time from the response into our buffer
  byte offset = 0;
  char buffer[TIME_SIZE+1];
  while (offset < sizeof(buffer) - 1) {
    char newChar = uart->read();
    if (newChar != -1)
        buffer[offset++] = newChar;
  }
  buffer[offset] = 0;

  // This should skip the remainder of the output.
  // TODO: Handle this better?
  waitForResponse("<");
  findInResponse(" ");

  // For some reason the "sendCommand" approach leaves the system
  // in a state where it misses the first/next connection so for
  // now we don't check the response.
  // TODO: Fix this
  uart->println(F("exit"));

  return strtol(buffer, NULL, 0);
}

// Preinstantiate required objects
WiFlyDevice WiFly;
