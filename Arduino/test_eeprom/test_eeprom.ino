#include <Wire.h>
#include <EEPROM.h>

void setup() {
    char somedata[] = "Hello, Parker!"; // data to write
    Wire.begin(); // initialise the connection
    Serial.begin(9600);
    ext_eeprom_write_page(0, (byte *)somedata, sizeof(somedata)); // write to EEPROM 

    delay(10); //add a small delay

    Serial.println("Memory written");
}

void loop() {
    int addr=0; //first address
    byte b = ext_eeprom_read_byte(0); // access the first address from the memory

    while (b!=0) 
    {
      Serial.print((char)b); //print content to serial port
      addr++; //increase address
      b = ext_eeprom_read_byte(addr); //access an address from the memory
    }
    Serial.println(" ");
    delay(2000);
}

// ================
// EEPROM Functions
// ================

// ++++++ modified from Arduino EEPROM library ++++++
#define I2C_EEPROM_DEVICE_ADDR 0x51

void ext_eeprom_write_byte(unsigned int eeaddress, byte data) {
  int rdata = data;
  Wire.beginTransmission(I2C_EEPROM_DEVICE_ADDR);
  Wire.write((int)(eeaddress >> 8)); // MSB
  Wire.write((int)(eeaddress & 0xFF)); // LSB
  Wire.write(rdata);
  Wire.endTransmission();
  delay(5);
}

// WARNING: address is a page address, 6-bit end will wrap around
// also, data can be maximum of about 30 bytes, because the Wire library has a buffer of 32 bytes
void ext_eeprom_write_page(unsigned int eeaddresspage, byte* data, byte length) {
  Wire.beginTransmission(I2C_EEPROM_DEVICE_ADDR);
  Wire.write((int)(eeaddresspage >> 8)); // MSB
  Wire.write((int)(eeaddresspage & 0xFF)); // LSB
  byte c;
  for ( c = 0; c < length; c++)
    Wire.write(data[c]);
  Wire.endTransmission();
  delay(15);
}

byte ext_eeprom_read_byte(unsigned int eeaddress) {
  byte rdata = 0xFF;
  Wire.beginTransmission(I2C_EEPROM_DEVICE_ADDR);
  Wire.write((int)(eeaddress >> 8)); // MSB
  Wire.write((int)(eeaddress & 0xFF)); // LSB
  Wire.endTransmission();
  Wire.requestFrom(I2C_EEPROM_DEVICE_ADDR,1);
  if (Wire.available()) rdata = Wire.read();
  delay(1);
  return rdata;
}

// maybe let's not read more than 30 or 32 bytes at a time!
void ext_eeprom_read_buffer(unsigned int eeaddress, byte *buffer, int length) {
  Wire.beginTransmission(I2C_EEPROM_DEVICE_ADDR);
  Wire.write((int)(eeaddress >> 8)); // MSB
  Wire.write((int)(eeaddress & 0xFF)); // LSB
  Wire.endTransmission();
  Wire.requestFrom(I2C_EEPROM_DEVICE_ADDR,length);
  int c = 0;
  for ( c = 0; c < length; c++ )
    if (Wire.available()) buffer[c] = Wire.read();
  delay(1);
}


