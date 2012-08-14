#include <Streaming.h>
int sensorPin = A0;    // select the input pin for the potentiometer

void setup() {
  Serial.begin(9600);
}

char const * decode(int button) {
  switch (button / 10) {
    case 74: return "select";
    case 50: return "left";
    case 32: return "down";
    case 14: return "up";
    case  0:
    return "right";
  }
  return "open";
}

void loop() {
  // read the value from the sensor:
  int button = analogRead(sensorPin);
  Serial << button << " " << decode(button) << endl;
  delay (200);
}

/*

Open = 1023
                     143
                     Up
Select     Left                Right
 740,741    503     Down        0
                   329,328

*/
