#define SER_PIN   2  // pin 14 on the 75HC595
#define RCLK_PIN  3  // pin 12 on the 75HC595
#define SRCLK_PIN 11 // pin 11 on the 75HC595

static char valves;

void commitValves() {
  digitalWrite (RCLK_PIN, LOW);
  for (int ii = 7; ii >= 0; --ii) {
    digitalWrite (SRCLK_PIN, LOW);
    digitalWrite (SER_PIN, (valves & (1 << ii)) ? HIGH : LOW);
    digitalWrite (SRCLK_PIN, HIGH);
  }
  digitalWrite(RCLK_PIN, HIGH);
}

//set an individual pin HIGH or LOW
void setValve(int index, int value) {
  if (value)
    valves |=  (1 << index);
  else
    valves &= ~(1 << index);
}


void setup(){
  pinMode (SER_PIN,   OUTPUT);
  pinMode (RCLK_PIN,  OUTPUT);
  pinMode (SRCLK_PIN, OUTPUT);

  valves = 0;
  commitValves();
}

static int count = 0;

void loop(){
  for (int ii = 0; ii < 8; ++ii)
      setValve(ii, count & (1 << ii));
  ++count;

  valves = random();
  commitValves();
  delay(500);
}
