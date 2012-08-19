#ifndef __WIFLY_H__
#define __WIFLY_H__

#include <Arduino.h>

#include "WiFlyDevice.h"
#include "WiFlyClient.h"
#include "WiFlyServer.h"

// Join modes
#define WEP_MODE false
#define WPA_MODE true

// Configuration options
#define WIFLY_BAUD 1

extern WiFlyDevice WiFly;

#endif

