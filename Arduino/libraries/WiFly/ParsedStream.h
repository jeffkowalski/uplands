// Based on ring buffer implementation in `HardwareSerial`.

#ifndef __PARSED_STREAM_H__
#define __PARSED_STREAM_H__

#define RX_BUFFER_SIZE 64

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

struct ring_buffer {
  unsigned char buffer[RX_BUFFER_SIZE];
  int           head;
  int           tail;
};

class ParsedStream {
  public:
    ParsedStream();

    void          begin (Stream * theUart);
    uint8_t       available();
    int           read();
    int           peek();
    bool          closed();
    void          reset();

  private:  
    ring_buffer   _rx_buffer;
    unsigned int  bytes_matched;
    bool          _closed;
    Stream *      _uart;

    void          getByte();
    uint8_t       available (bool raw);
    int           freeSpace();
};

#endif
