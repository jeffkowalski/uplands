#include <MemoryFree.h>
#include <LiquidCrystal.h>
#include <WiFly.h>
#include <Time.h>
#include <Streaming.h>
#include "Credentials.h"

#define WEATHER_UPDATE_INTERVAL  (15L * 60L * 1000L)
#define CALENDAR_UPDATE_INTERVAL ( 1L * 60L * 1000L)
#define STATUS_UPDATE_INTERVAL    500L

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

static LiquidCrystal        lcd (8,9,4,5,6,7);
static char const * const   ssid = WIFI_SSID;
static char const * const   pass = WIFI_PASSPHRASE;
static long                 last_weather_check  = 0;
static long                 last_status_print   = 0;
static long                 last_calendar_check = 0;
static time_t               trigger = 0;
static int                  pop = 0;
static WiFlyServer          server(80);
static WiFlyClient          wundergroundClient("api.wunderground.com", 80);
static WiFlyClient          pachubeClient("api.pachube.com", 80);
static WiFlyClient          googleClient("www.google.com", 80);

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
    snprintf (datetime, sizeof(datetime), "%04d-%02d-%02dT%02d:%02d:%02dZ", year(t), month(t), day(t), hour(t), minute(t), second(t));
    return datetime;
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
  //say ("joining network ", ssid); 
  while (!WiFly.join(ssid, pass, true)) {
    //say ("retry join"); 
    delay(3000);  // try again after 3 seconds;
  }

  //say ("starting server"); 
  delay(3000);
  server.begin();
  setSyncProvider (getTime);
  //say ("server ready", WiFly.ip());
}

static void getResponse (
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

    // wait a little for the response;
    int retries = 10;
    while (!client.available() && retries--) {
      delay(100);
    }
    
    //say ("parsing");
    int target_len = strlen(target);
    char const * try_target = target;
    int try_target_len = target_len;
    --response_len;
    while (client.connected() && response_len > 0) {
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

    client.stop();
  }
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


void checkCalendar() {
  //say ("calendar");
  char cal[32];
  cal[0] = '\0';
  char * resource = "/calendar/feeds/" GOOGLE_FEED "@group.calendar.google.com/private-" GOOGLE_PRIVATE "/full?fields=entry(gd:when,title[text()='flud'])&singleevents=true&prettyprint=true&max-results=1&orderby=starttime&sortorder=a&start-min=2012-01-20T00:00:00Z&start-max=2012-01-20T23:59:59Z";
  char * found = strstr (resource, "start-min=");
  if (found) strncpy (found+10, timestamp(now()), 20);
  found = strstr (resource, "start-max=");
  if (found) strncpy (found+10, timestamp(now()+SECS_PER_HOUR), 20);
  getResponse (googleClient, resource, "startTime='", '\'', cal, sizeof(cal));
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
    long zone = (cal[23] == '-' ? -1L : 1L) * (((cal[24] - '0') * 10 + (cal[25] - '0')) * SECS_PER_HOUR + ((cal[27] - '0') * 10 + (cal[28] - '0')) * SECS_PER_MIN);
    trigger = (long)makeTime(te) - zone;
  }
}


void checkWeather() {
  //say ("weather");
#if 1
  char popbuf[4];
  getResponse (wundergroundClient, "/api/" WUNDERGROUND_APIKEY "/forecast/q/94705.json", "\"pop\":", ',', popbuf, sizeof(popbuf));
  putData (pachubeClient, "/v2/" PACHUBE_FEED "/43762/datastreams/0", "X-PachubeApiKey: " PACHUBE_APIKEY "\r\nContent-Type: text/csv", popbuf);
  pop = atoi(popbuf);
#endif
}


void printStatus() {
  char line[17];
  snprintf(line, sizeof(line), "%d%% %ldm %db", pop, (trigger ? (trigger - (long)now()) / SECS_PER_MIN : -1), freeMemory());
  line[16] = '\0';
  say (timestamp(now())+5, line);
}

void loop() {
  WiFlyClient client = server.available();
  if (client) {
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
          // send a standard http response header
          client << F("HTTP/1.1 200 OK") << endl;
          client << F("Content-Type: text/html") << endl << endl;
          client << F("millis = ") << millis() << F("<br>") << endl;
          client << F("time = ") << timestamp(now()) << F("<br>") << endl;
          client << F("pop = ") << pop << F("<br>") << endl;
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
    // give the web browser time to receive the data
    delay(100);
    client.stop();
    //say ("client stopped");
  }
  else if (!last_weather_check || (millis() - last_weather_check > WEATHER_UPDATE_INTERVAL)) {
    checkWeather();
    last_weather_check = millis();
  }
  else if (!last_calendar_check || (millis() - last_calendar_check > CALENDAR_UPDATE_INTERVAL)) {
    checkCalendar();
    last_calendar_check = millis();
  }
  else if (!last_status_print || (millis() - last_status_print) > STATUS_UPDATE_INTERVAL) {
    printStatus();
    last_status_print = millis();
  }
}

