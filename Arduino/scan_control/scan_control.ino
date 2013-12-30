#include <Streaming.h>

int led_pin = 13;

int size_letter_pin   =  2;
int size_a4_pin       =  3;
int size_legal_pin    =  4;
int size_max_pin      =  5;
int scan_pin          =  6;
int mode_pin          =  7;
int crop_pin          =  8;
int deskew_pin        =  9;

void setup() {
  Serial.begin(9600);

  pinMode (led_pin, OUTPUT);

  pinMode (size_letter_pin, INPUT);
  digitalWrite (size_letter_pin, HIGH);
  pinMode (size_a4_pin, INPUT);
  digitalWrite (size_a4_pin, HIGH);
  pinMode (size_legal_pin, INPUT);
  digitalWrite (size_legal_pin, HIGH);
  pinMode (size_max_pin, INPUT);
  digitalWrite (size_max_pin, HIGH);
  pinMode (scan_pin, INPUT);
  digitalWrite (scan_pin, HIGH);
  pinMode (mode_pin, INPUT);
  digitalWrite (mode_pin, HIGH);
  pinMode (crop_pin, INPUT);
  digitalWrite (crop_pin, HIGH);
  pinMode (deskew_pin, INPUT);
  digitalWrite (deskew_pin, HIGH);
}

int ledstate = 0;

void loop() {
  digitalWrite (led_pin, ledstate);
  ledstate = ++ledstate % 2;

  if (!digitalRead (scan_pin)) {
    Serial << "(";
    Serial << "'size' => "    <<
      (!digitalRead (size_letter_pin) ? "'letter'" :
       !digitalRead (size_a4_pin)     ? "'a4'"     :
       !digitalRead (size_legal_pin)  ? "'legal'"  :
                                        "'max'") << ", ";
    Serial << "'mode' => "   << (!digitalRead(mode_pin) ? "'pdf'" : "'jpg'") << ", ";
    Serial << "'crop' => "   << !digitalRead(crop_pin) << ", ";
    Serial << "'deskew' => " << !digitalRead(deskew_pin) << ")" << endl;
    while (!digitalRead (scan_pin))
      delay (500);
  }
  delay (500);
}
