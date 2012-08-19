#include "WiFly.h"

// NOTE: Arbitrary cast to avoid constructor ambiguity.
// TODO: Handle this a different way so we're not using
//       NULL pointers all over the place?
#define NO_CLIENT WiFlyClient ((uint8_t*) NULL, 0)

WiFlyServer::WiFlyServer(uint16_t port) :
  _port         (port),
  activeClient  (NO_CLIENT) {
  // TODO: Handle this better.
  // NOTE: This only works if the server object was created globally.
  WiFly.serverPort = port;
}


void WiFlyServer::begin() {
}

#define TOKEN_MATCH_OPEN "*OPEN*"
WiFlyClient& WiFlyServer::available() {
  if (!WiFly.serverConnectionActive)
    activeClient._port = 0;

  // Return active server connection if present
  if (!activeClient) {
    if (WiFly.uart->available() >= (int)strlen (TOKEN_MATCH_OPEN)) {
      if (WiFly.responseMatched (TOKEN_MATCH_OPEN)) {
        // The following values indicate that the connection was
        // created when acting as a server.

        activeClient._port   = _port;
        activeClient._domain = NULL;
        activeClient._ip     = NULL;
        activeClient.connect();

        WiFly.serverConnectionActive = true;
      }
      else
        WiFly.uart->flush();
    }
  }

  return activeClient;
}
