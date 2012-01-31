#include <MemoryFree.h>
#include <LiquidCrystal.h>
#include <WiFly.h>
#include <Time.h>
#include <Streaming.h>
#include <EEPROM.h>
#include "Credentials.h"

#define WEATHER_UPDATE_INTERVAL  (15L * 60L * 1000L)
#define CALENDAR_UPDATE_INTERVAL ( 1L * 60L * 1000L)
#define STATUS_UPDATE_INTERVAL    500L

#define SER_PIN   2  // pin 14 on the 75HC595
#define RCLK_PIN  3  // pin 12 on the 75HC595
#define SRCLK_PIN 11 // pin 11 on the 75HC595

#define SSER 0

#if SSER
  #include <SoftwareSerial.h>
  #define LOG Serial.println
  #define LOGX Serial.print
  static SoftwareSerial     WiFlySerial(2, 3);  // rx, tx
#else
  #define LOG (void)
  #define LOGX (void)
#endif

#define VALVE_COUNT         8

static LiquidCrystal        lcd (8,9,4,5,6,7);
static unsigned long        last_weather_check  = 0;
static unsigned long        last_status_print   = 0;
static unsigned long        last_calendar_check = 0;
static time_t               trigger = 0;
static time_t               advance = 0;
static int                  pop = 0;
static WiFlyServer          server(80);
static WiFlyClient          wundergroundClient("api.wunderground.com", 80);
static WiFlyClient          pachubeClient("api.pachube.com", 80);
static WiFlyClient          googleClient("www.google.com", 80);
static int                  valveOn = 0;

#define VALVE_NAME_SIZE     16
struct EEPROMSettings {
  int                       valveDuration[VALVE_COUNT];
  char                      valveName[VALVE_COUNT][VALVE_NAME_SIZE];
};

int get_valveDuration (int index) {
  int  retval = 0;
  if (index < VALVE_COUNT) {
    byte * bytes = (byte *)&retval;
    EEPROMSettings * settings = 0;
    for (unsigned int ii = 0; ii < sizeof(settings->valveDuration[0]); ++ii)
      bytes[ii] = EEPROM.read ((int)&settings->valveDuration[index] - (int)settings + ii);
  }
  return retval;
}
void set_valveDuration (int index, int time) {
  if (index < VALVE_COUNT) {
    byte * bytes = (byte *)&time;
    EEPROMSettings * settings = 0;
    for (unsigned int ii = 0; ii < sizeof(settings->valveDuration[0]); ++ii)
      EEPROM.write ((int)&settings->valveDuration[index] - (int)settings + ii, bytes[ii]);
  }
}
char * get_valveName (int index, char * name, int name_len) {
  if (index < VALVE_COUNT) {
    EEPROMSettings * settings = 0;
    for (int ii = 0; ii < name_len; ++ii)
      name[ii] = EEPROM.read ((int)&settings->valveName[index][ii] - (int)settings);
  }
  name[name_len-1] = '\0';
  return name;
}
void set_valveName (int index, char * name) {
  if (index < VALVE_COUNT) {
    EEPROMSettings * settings = 0;
    for (unsigned int ii = 0; ii < sizeof(settings->valveName[ii]); ++ii) {
      EEPROM.write ((int)&settings->valveName[index][ii] - (int)settings, name[ii]);
      if (!name[ii]) break;
    }
  }
}


static void say (
  char const * const line1,
  char const * const line2 = 0) {
  if (line1) {
    lcd.clear(); 
    lcd.print(line1);
    LOG(line1);
  }
  if (line2) {
    lcd.setCursor(0,1);
    lcd.print(line2);
    LOG(line2);
  }
}


static time_t getTime() {
  return WiFly.getTime();
}


static char const * timestamp (time_t t) {
    static char datetime[21]; // yyyy-mm-ddThh:mm:ssZ  
                              // 12345678901234567890
    snprintf (datetime, sizeof(datetime), 
              "%04d-%02d-%02dT%02d:%02d:%02dZ", year(t), month(t), day(t), hour(t), minute(t), second(t));
    return datetime;
}


static void putData (
  WiFlyClient &         client,
  char const  * const   resource, 
  char const  * const   headers,
  char const  *         data) {

  if (!client.connected()) {
    say (client._domain);
    client.connect();
  }

  if (client.connected()) {
    //say ("putting", resource);
    client << F("PUT ") << resource << F(" HTTP/1.1") << endl;
    client << F("Host: ") << client._domain << endl;
    if (headers && headers[0])
      client << headers << endl;
    client << F("Content-Length: ")  << strlen(data) << endl;
    client << F("Connection: close") << endl;
    client << endl;

    // here's the actual content of the PUT request:
    client << data << endl;
    delay (300);
    client.stop();
  } 
}


void putPachubeData (int stream, int value) {
    char request[sizeof("/v2/feeds/" PACHUBE_FEED "/datastreams/0")];
    snprintf (request, sizeof(request), "/v2/feeds/%s/datastreams/%d", PACHUBE_FEED, stream);
    request[sizeof(request)-1] = '\0';
    char data[6];
    snprintf (data, sizeof(data), "%d", value);
    data[sizeof(data)-1] = '\0';
    putData (pachubeClient, request, "X-PachubeApiKey: " PACHUBE_APIKEY "\r\nContent-Type: text/csv", data);
}


void commitValves() {
  digitalWrite (RCLK_PIN, LOW);
  for (int ii = VALVE_COUNT; ii > 0; --ii) {
    digitalWrite (SRCLK_PIN, LOW);
    digitalWrite (SER_PIN, valveOn == ii ? HIGH : LOW);
    digitalWrite (SRCLK_PIN, HIGH);
  }
  digitalWrite(RCLK_PIN, HIGH);
  putPachubeData (1, valveOn);
}


void setup() {
#if SSER
  Serial.begin(9600);
  LOG("Starting");
  WiFlySerial.begin(9600);
  WiFly.setUart(&WiFlySerial);
#else
  Serial.begin(9600);
  WiFly.setUart(&Serial);
#endif

  lcd.begin(16, 2);
  say ("flud.");

  WiFly.begin();
  //say ("joining network ", WIFI_SSID); 
  while (!WiFly.join(WIFI_SSID, WIFI_PASSPHRASE, true)) {
    //say ("retry join"); 
    delay(3000);  // try again after 3 seconds;
  }

  //say ("resetting valves")
  pinMode (SER_PIN,   OUTPUT);
  pinMode (RCLK_PIN,  OUTPUT);
  pinMode (SRCLK_PIN, OUTPUT);
  valveOn = 0;
  commitValves();

  //say ("starting server"); 
  delay(3000);
  server.begin();
  setSyncProvider (getTime);
  //say ("server ready", WiFly.ip());
}


static void getResponse (
  WiFlyClient &         client,
  char const  *         target, 
  char                  terminal, 
  char        *         response, 
  int                   response_len) {
  unsigned long         timeout = millis() + 20 * 1000;
  
  //say ("parsing");
  int target_len = strlen(target);
  char const * try_target = target;
  int try_target_len = target_len;
  --response_len;
  while (client.connected() && response_len > 0) {
    if (millis() > timeout) break;
    while (client.available() && response_len > 0) {
      char c = client.read();
      LOGX(c);

      if (try_target_len) {
        if (c == *try_target) {
          ++try_target;
          --try_target_len;
        }
        else {
          try_target = target;
          try_target_len = target_len;
        }
      }

      else if (c != terminal) {
        *response++ = c;
        --response_len;
      }

      else //c == terminal
        response_len = 0;
    }
  }
  *response = '\0';
}


static void getData (
  WiFlyClient &         client, 
  char const  *         resource, 
  char const  *         target, 
  char                  terminal, 
  char        *         response, 
  int                   response_len) {

  if (!client.connected()) {
    say (client._domain);
    client.connect();
  }

  if (client.connected()) {
    //say ("requesting", resource);
    LOG(resource);
    client << F("GET ") << resource << F(" HTTP/1.1") << endl;
    client << F("Host: ") << client._domain << endl;
    client << F("Connection: close") << endl;
    client << endl;
    
    getResponse (client, target, terminal, response, response_len);

    client.stop();
  }
}


// find trigger in calendar from now to one hour from now, or -1 if none
void checkCalendar() {
  //say ("calendar");
  char cal[32];
  cal[0] = '\0';
  // cast away const to enable overwriting static string -- be careful!
  char * resource = (char *)"/calendar/feeds/" GOOGLE_FEED "@group.calendar.google.com/private-" GOOGLE_PRIVATE "/full?fields=entry(gd:when,title[text()='flud'])&singleevents=true&prettyprint=true&max-results=1&orderby=starttime&sortorder=a&start-min=2012-01-20T00:00:00Z&start-max=2012-01-20T23:59:59Z";
  char * found = strstr (resource, "start-min=");
  if (found) strncpy (found+10, timestamp(now()), 20);
  found = strstr (resource, "start-max=");
  if (found) strncpy (found+10, timestamp(now()+SECS_PER_HOUR), 20);
  getData (googleClient, resource, "startTime='", '\'', cal, sizeof(cal));
  trigger = 0;
  if (cal[0]) {
    //yyyy-mm-ddThh:mm:ss.000-ZZ:ZZ  
    //01234567890123456789012345678
    TimeElements te;
    te.Year   = (cal[0]  - '0') * 1000 + (cal[1] - '0') * 100 + (cal[2] - '0') * 10 + (cal[3] - '0') - 1970;
    te.Month  = (cal[5]  - '0') * 10 + (cal[6]  - '0');
    te.Day    = (cal[8]  - '0') * 10 + (cal[9]  - '0');
    te.Hour   = (cal[11] - '0') * 10 + (cal[12] - '0');
    te.Minute = (cal[14] - '0') * 10 + (cal[15] - '0');
    te.Second = (cal[17] - '0') * 10 + (cal[18] - '0');
    long zone = (cal[23] == '-' ? -1L : 1L) * 
                            (((cal[24] - '0') * 10 + (cal[25] - '0')) * SECS_PER_HOUR + 
                             ((cal[27] - '0') * 10 + (cal[28] - '0')) * SECS_PER_MIN);
    trigger = (long)makeTime(te) - zone;
  }
}


void checkWeather() {
  //say ("weather");
  char popbuf[4];
  getData (wundergroundClient, "/api/" WUNDERGROUND_APIKEY "/forecast/q/94705.json", 
           "\"pop\":", ',', popbuf, sizeof(popbuf));
  pop = atoi(popbuf);
  putPachubeData (0, pop);
}


void printStatus() {
  char      line[17];
  time_t    current = now();
  if (valveOn && advance > current)
    snprintf (line, sizeof(line), 
              "v%d %02ld:%02ld  %db", valveOn, 
              (advance - current) / SECS_PER_MIN, 
              (advance - current) % SECS_PER_MIN, 
              freeMemory());
  else if (trigger > current)
    snprintf (line, sizeof(line), 
              "%d%% %02ld:%02ld  %db", pop, 
              (trigger - current) / SECS_PER_MIN,
              (trigger - current) % SECS_PER_MIN,
              freeMemory());
  else
    snprintf (line, sizeof(line), 
              "%d%%  %db", pop, 
              freeMemory());
  line[sizeof(line)-1] = '\0';
  say (timestamp(now())+5, line);
}


void advanceValve() {
  putPachubeData (1, valveOn);

  do {
    ++valveOn;
  } while (valveOn <= VALVE_COUNT && !get_valveDuration(valveOn-1));

  if (valveOn > VALVE_COUNT) {
    valveOn = 0;
    trigger = 0;
  }
  else
    advance = now() + get_valveDuration(valveOn-1) * SECS_PER_MIN;

  commitValves();
}


void sendIndex (
  WiFlyClient &client) {
  client << F("HTTP/1.1 200 OK") << endl;
  client << F("Content-Type: text/html") << endl << endl;
  client << F("millis = ") << millis() << F("<br>");
  client << F("time = ") << timestamp(now()) << F("<br>");
  client << F("pop = ") << pop << F("<br>");
  client << "Valves <form method='POST'>";
  for (int ii = 0; ii < VALVE_COUNT; ++ii) {
    char name[VALVE_NAME_SIZE];
    client << F("<input type='text' name='n") << ii << F("' value='") << get_valveName(ii, name, sizeof(name)) << F("' />");
    client << F("<input type='text' name='d") << ii << F("' value='") << get_valveDuration(ii)                 << F("' />");
    client << F("<br>");
  }
  client << F("<input type='hidden' name='h' /><input type='submit' value='Submit' /></form>");
}


void send404 (
  WiFlyClient &client) {
  client << F("HTTP/1.1 404 NOT FOUND") << endl << endl;
}


void loop() {
  WiFlyClient client = server.available();
  if (client) {
    char method[5];
    char resource[32];
    getResponse (client, "", ' ', method, sizeof(method));
    if (!strcmp (method, "GET"))
      getResponse (client, "", ' ', resource, sizeof(resource));
    //say ("client active");
    // an http request ends with a blank line
    boolean current_line_is_blank = true;
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        // if we've gotten to the end of the line (received a newline
        // character) and the line is blank, the http request has ended,
        // so we can send a reply
        if (c == '\n' && current_line_is_blank) {
          break;
        }
        if (c == '\n') {
          // we're starting a new line
          current_line_is_blank = true;
        } 
        else if (c != '\r') {
          // we've gotten a character on the current line
          current_line_is_blank = false;
        }
      }
    }
    if (!strcmp (method, "GET"))
      sendIndex (client);
    else if (!strcmp (method, "POST")) {
      //  xx=yy&
      do {
        getResponse (client, "", '=', resource, sizeof(resource));
        if (!strcmp(resource, "h")) 
          break;
        else {
          int index = atoi(&resource[1]);
          if (resource[0] == 'n') {
            getResponse (client, "", '&', resource, sizeof(resource));
            set_valveName (index, resource);
          }
          else if (resource[0] == 'd') {
            getResponse (client, "", '&', resource, sizeof(resource));
            set_valveDuration (index, atoi(resource));
          }
          else 
            break;
        }
      } while (resource[0]);
      sendIndex (client);
    }
    else 
      send404 (client);
    // give the web browser time to receive the data
    delay(100);
    client.stop();
    //say ("client stopped");
  }
  else if (!valveOn && (!last_weather_check || (millis() - last_weather_check > WEATHER_UPDATE_INTERVAL))) {
    checkWeather();
    last_weather_check = millis();
  }
  else if (!valveOn && (!last_calendar_check || (millis() - last_calendar_check > CALENDAR_UPDATE_INTERVAL))) {
    checkCalendar();
    last_calendar_check = millis();
  }
  else if ((!valveOn && trigger && trigger < now()) ||  // valves are off, but it's time to start, or
           ( valveOn && advance < now())) {             // a valve has been running for long enough
    advanceValve();
  }
  else if (!last_status_print || (millis() - last_status_print) > STATUS_UPDATE_INTERVAL) {
    printStatus();
    last_status_print = millis();
  }
}

