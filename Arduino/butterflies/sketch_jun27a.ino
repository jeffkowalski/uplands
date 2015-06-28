int led0=0;
int led1=1;
int led2=2;

// the setup routine runs once when you press reset:
void setup() {
  // initialize the digital pin as an output.
  int pin;
  for (pin=0; pin<3; ++pin)
    pinMode(pin, OUTPUT);
}

void glow(int pin) {
  for (int times = 0; times < 5; ++times) {
    digitalWrite(pin, HIGH); 
    delay(60);
    digitalWrite(pin, LOW);
    delay(7);
  }
}

void fade(int pin) {
  int level;
  int step = random(1, 3);
  for (level=0; level < 256; level+=step) {
    analogWrite (pin, level);
    delay(3);
  }
  for (level=255; level >= 0; level-=step) {
    analogWrite (pin, level);
    delay(1);
  }
  analogWrite(pin, 0);
}

// 0 = SPLIT (can fade)
// 1 = MIDPAIR (can fade)
// 2 = TOP (can't fade)

static int lastpin = 0;

void random_loop() {
  int pin;
  do {
    pin = random(3);
  } while (pin == lastpin);
  lastpin = pin;
  if (random(2))
    fade(pin);
  else
    glow(pin);
  delay (random(5) * 100); 
}

void static_loop() {
  glow(2);  // top can't fade

  fade(1);  // pair can fade
  fade(0);  // split can fade
}


void loop() {
  int ii;
  for (ii = 0; ii < 2; ++ii)
    static_loop();
  for (ii = 0; ii < 2; ++ii)
    random_loop();
}

