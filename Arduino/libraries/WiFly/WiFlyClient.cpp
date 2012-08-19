#include "WiFly.h"
#include "WiFlyClient.h"

WiFlyClient::WiFlyClient(uint8_t *ip, uint16_t port) :
  _ip     (ip),
  _port   (port),
  _domain (NULL),
  _WiFly  (WiFly), 
  isOpen  (false) {}


WiFlyClient::WiFlyClient(const char* domain, uint16_t port) :
  _ip     (NULL),
  _port   (port),
  _domain (domain),
  _WiFly  (WiFly),
  isOpen  (false) {}


size_t  WiFlyClient::write(byte value) {
  _WiFly.uart->write(value);
  return 1;
}


size_t  WiFlyClient::write(const uint8_t *buffer, size_t size) {
  size_t retval = 0;
  while (size--)
    retval += _WiFly.uart->write(*buffer++);
  return retval;
}


boolean WiFlyClient::connect() {
  // Handle case when Null object returned from Server.available()
  if (!this)
    return false;

  stream.begin(_WiFly.uart);
  stream.reset();

  if ((_ip == NULL) && (_domain == NULL)) {
    // This is a connection started by the Server class
    // so the connection is already established.
  }
  else {
    _WiFly.enterCommandMode();
    
    _WiFly.sendCommand("open ", true, "" /* TODO: Remove this dummy value */);
    
    if (_ip != NULL) {
      for (int index = 0; /* break inside loop*/ ; index++) {
        _WiFly.uart->print(_ip[index], DEC);
        if (index == 3) break;
        _WiFly.uart->print('.');
      }
    }
    else if (_domain != NULL)
      _WiFly.uart->print(_domain);
    else {
      //while (1) {
        // This should never happen
      //}
    }
    
    _WiFly.uart->print(" ");
    _WiFly.uart->print(_port, DEC);
    _WiFly.sendCommand("", false, "*OPEN*");
    
    // TODO: Handle connect failure
  }
  
  isOpen = true;
  return true;
}


int WiFlyClient::available() {
  return (!isOpen) ?  0 : stream.available();
}

int WiFlyClient::read() {
  return (!isOpen) ? -1 : stream.read();
}

int WiFlyClient::peek() {
  return (!isOpen) ? -1 : stream.peek();
}

void WiFlyClient::flush(void) {
  if (!isOpen)
    return;
  else 
    while (stream.available() > 0)
      stream.read();
}

bool WiFlyClient::connected() {
  // TODO: Set isOpen to false once we know the stream is closed?
  return isOpen && !stream.closed();
}


void WiFlyClient::stop() {
  // TODO: Work out if there's some unintended compatibility issues
  //       related to interactions between `stop()`, `connected()` and
  //       `available()`.

  // This stop implementation is suboptimal. We need to handle the case
  // of a server connection differently to a client connection.
  // We also need to handle better detecting if the connection is already
  // closed.
  // In the interests of getting something out the door--that somewhat
  // works--this is what we're going with at the moment.

  _WiFly.enterCommandMode();
  _WiFly.uart->println("close");
  // We ignore the response which could be "*CLOS*" or could be an
  // error if the connection is no longer open.

  _WiFly.uart->println("exit"); // TODO: Fix this hack which is a workaround for the fact the closed connection isn't detected properly, it seems. Even with this there's a delay between reconnects needed.
  _WiFly.findInResponse("EXIT",1000);
  //_WiFly.skipRemainderOfResponse();
  // As a result of this, unwanted data gets sent to /dev/null rather than
  // confusing the WiFly which tries to interpret it as commands.
  stream.reset();
  _WiFly.uart->flush();

  // This doesn't really work because the object gets copied in the
  // WeWiFlyClient example code.
  isOpen = false; 
  // _port = 0;

  // So instead we mark any server connection as inactive.
  // TODO: Only do this if this was a server client connection
  _WiFly.serverConnectionActive = false;
}


WiFlyClient::operator bool() {
  // NOTE: In keeping with the Ethernet WiFlyClient class
  //       we use _ip == NULL, _domain == NULL, _port = 0 to
  //       indicate Server.available() found no connection.
  //       We use _ip == NULL, _domain == NULL, _port !=0 to
  //       indicate a server connection from a client.
  return !((_ip == NULL) && (_domain == NULL) && (_port == 0));
}
