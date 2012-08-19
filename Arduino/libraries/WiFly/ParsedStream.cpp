#include "ParsedStream.h"

ParsedStream::ParsedStream() {
  reset();
  _uart         = NULL;
}


void ParsedStream::begin (Stream* theUart) {
  _uart = theUart;
}


void ParsedStream::reset() {
  _rx_buffer.head = _rx_buffer.tail = _rx_buffer.buffer[0] = 0;
  _closed       = false;
  bytes_matched = 0;
}


uint8_t ParsedStream::available() {
  while (!_closed && freeSpace() && _uart->available())
    getByte();
  return available (false);
}


bool ParsedStream::closed() {
  return _closed && !available();
}


int ParsedStream::read() {
  if (!available()) 
    return -1;
  else {
    unsigned char c = _rx_buffer.buffer[_rx_buffer.tail];
    _rx_buffer.tail = (_rx_buffer.tail + 1) % RX_BUFFER_SIZE;
    return c;
  }
}


int ParsedStream::peek() {
  if (!available())
    return -1;
  else {
    unsigned char c = _rx_buffer.buffer[_rx_buffer.tail];
    return c;
  }
}


uint8_t ParsedStream::available(bool raw) {
  uint8_t available_bytes;
  
  available_bytes = (RX_BUFFER_SIZE + _rx_buffer.head - _rx_buffer.tail) % RX_BUFFER_SIZE;

  if (!raw) {
    if (available_bytes > bytes_matched) 
      available_bytes -= bytes_matched;
    else
      available_bytes = 0;
  }

  return available_bytes;
}


int ParsedStream::freeSpace() {
  return RX_BUFFER_SIZE - available(true) - 1 /* The -1 fudge due to getByte calculation*/;
}


void ParsedStream::getByte() {
  const static char *MATCH_TOKEN = "*CLOS*";

  if (_closed)
    return;

  if (freeSpace() == 0)
    return;
  
  int c = _uart->read();
  if (c == -1)
    return;

  if (c == MATCH_TOKEN[bytes_matched]) {
    bytes_matched++;
    if (bytes_matched == strlen(MATCH_TOKEN))
      _closed = true;
  }
  else if (c == MATCH_TOKEN[0])
    bytes_matched = 1;
  else
    bytes_matched = 0;

  // if we should be storing the received character into the location
  // just before the tail (meaning that the head would advance to the
  // current location of the tail), we're about to overflow the buffer
  // and so we don't write the character or advance the head.
  int i = (_rx_buffer.head + 1) % RX_BUFFER_SIZE;
  if (i != _rx_buffer.tail) {
    _rx_buffer.buffer[_rx_buffer.head] = c;
    _rx_buffer.head = i;
  }
}

