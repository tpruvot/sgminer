/*
 * Copyright 2014 Andre Vehreschild
 * Copyright 2016 John Doering
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 3 of the License, or (at your option)
 * any later version. See LICENCE for more details.
 */

#include "config.h"

#ifdef HAVE_NVML

/* NVML is available for Linux and Windows only */
#if defined(__linux__) || defined(_WIN32)
#include "miner.h"

#ifdef __linux__
#include <stdlib.h>
#include <unistd.h>
#include <dlfcn.h>

void *hDLL;
#else
#include <windows.h>
typedef unsigned int uint;

#define dlsym (void *) GetProcAddress
#define dlclose FreeLibrary

static HMODULE hDLL;
#endif

static char * (*NVML_nvmlErrorString)(nvmlReturn_t);
static nvmlReturn_t (*NVML_nvmlInit)();
static nvmlReturn_t (*NVML_nvmlDeviceGetCount)(uint *);
static nvmlReturn_t (*NVML_nvmlDeviceGetHandleByIndex)(uint, nvmlDevice_t *);
static nvmlReturn_t (*NVML_nvmlDeviceGetName)(nvmlDevice_t, char *, uint);
static nvmlReturn_t (*NVML_nvmlDeviceGetPciInfo)(nvmlDevice_t, nvmlPciInfo_t *);
static nvmlReturn_t (*NVML_nvmlDeviceGetTemperature)(nvmlDevice_t, nvmlTemperatureSensors_t, uint *);
static nvmlReturn_t (*NVML_nvmlDeviceGetFanSpeed)(nvmlDevice_t, uint *);
static nvmlReturn_t (*NVML_nvmlShutdown)();

void nvml_init() {
    nvmlReturn_t ret;

#ifdef WIN32
    /* Not in system path, but could be local */
    hDLL = LoadLibrary("nvml.dll");
    if(!hDLL) {
        char path[512];
        ExpandEnvironmentStringsA("%ProgramFiles%\\NVIDIA Corporation\\NVSMI\\nvml.dll", path, sizeof(path));
        hDLL = LoadLibrary(path);
    }
#else
    hDLL = dlopen("libnvidia-ml.so", RTLD_LAZY | RTLD_GLOBAL);
#endif
    if(!hDLL) {
        applog(LOG_INFO, "Unable to load the NVIDIA Management Library");
        opt_nonvml = true;
        return;
    }

    NVML_nvmlInit = (nvmlReturn_t (*)()) dlsym(hDLL, "nvmlInit_v2");
    if(!NVML_nvmlInit) {
        /* Try an older interface */
        NVML_nvmlInit = (nvmlReturn_t (*)()) dlsym(hDLL, "nvmlInit");
        if(!NVML_nvmlInit) {
            applog(LOG_ERR, "NVML: Unable to initialise");
            opt_nonvml = true;
            return;
        } else {
            NVML_nvmlDeviceGetCount = (nvmlReturn_t (*)(uint *)) \
              dlsym(hDLL, "nvmlDeviceGetCount");
            NVML_nvmlDeviceGetHandleByIndex = (nvmlReturn_t (*)(uint, nvmlDevice_t *)) \
              dlsym(hDLL, "nvmlDeviceGetHandleByIndex");
            NVML_nvmlDeviceGetPciInfo = (nvmlReturn_t (*)(nvmlDevice_t, nvmlPciInfo_t *)) \
              dlsym(hDLL, "nvmlDeviceGetPciInfo");
        }
    } else {
        NVML_nvmlDeviceGetCount = (nvmlReturn_t (*)(uint *)) \
          dlsym(hDLL, "nvmlDeviceGetCount_v2");
        NVML_nvmlDeviceGetHandleByIndex = (nvmlReturn_t (*)(uint, nvmlDevice_t *)) \
          dlsym(hDLL, "nvmlDeviceGetHandleByIndex_v2");
        NVML_nvmlDeviceGetPciInfo = (nvmlReturn_t (*)(nvmlDevice_t, nvmlPciInfo_t *)) \
          dlsym(hDLL, "nvmlDeviceGetPciInfo_v2");
    }

    NVML_nvmlErrorString = (char * (*)(nvmlReturn_t)) \
      dlsym(hDLL, "nvmlErrorString");
    NVML_nvmlDeviceGetName = (nvmlReturn_t (*)(nvmlDevice_t, char *, uint)) \
      dlsym(hDLL, "nvmlDeviceGetName");
    NVML_nvmlDeviceGetTemperature = (nvmlReturn_t (*)(nvmlDevice_t, nvmlTemperatureSensors_t, uint *)) \
      dlsym(hDLL, "nvmlDeviceGetTemperature");
    NVML_nvmlDeviceGetFanSpeed = (nvmlReturn_t (*)(nvmlDevice_t, uint *)) \
      dlsym(hDLL, "nvmlDeviceGetFanSpeed");
    NVML_nvmlShutdown = (nvmlReturn_t (*)()) \
      dlsym(hDLL, "nvmlShutdown");

    ret = NVML_nvmlInit();
    if(ret != NVML_SUCCESS) {
        applog(LOG_ERR, "NVML: Init failed %s", NVML_nvmlErrorString(ret));
    }
}

// todo: cache mapping in an array (or cgpu)
unsigned int nvml_gpu_id(const unsigned int busid)
{
    uint dev, devnum = 0;
    bool matched = false;
    nvmlReturn_t ret = NVML_nvmlDeviceGetCount(&devnum);
    if (ret != NVML_SUCCESS) {
        applog(LOG_ERR, "NVML: unable to query devices %s", NVML_nvmlErrorString(ret));
        return UINT_MAX;
    }

    for (dev=0; dev < devnum; dev++) {
        nvmlPciInfo_t pci;
        nvmlDevice_t gpu = NULL;
        ret = NVML_nvmlDeviceGetHandleByIndex(dev, &gpu);
        if (ret != NVML_SUCCESS)
            continue;
        ret = NVML_nvmlDeviceGetPciInfo(gpu, &pci);
        if (ret != NVML_SUCCESS)
            continue;
        if (pci.bus == busid) {
            matched = true;
            break;
        }
    }
    if (!matched) {
        return UINT_MAX;
    }
    return dev;
}

void nvml_gpu_temp_and_fanspeed(const unsigned int busid, float *temp, int *fanspeed)
{
    nvmlReturn_t ret;
    nvmlDevice_t gpu = NULL;
    uint nTemp, nSpeed;

    uint dev = nvml_gpu_id(busid);
    if (dev == UINT_MAX) {
        *temp = -1.0f;
        *fanspeed = -1;
        return;
    }

    ret = NVML_nvmlDeviceGetHandleByIndex(dev, &gpu);
    if (ret != NVML_SUCCESS || !gpu) {
        *temp = -1.0f;
        *fanspeed = -1;
        return;
    }

    ret = NVML_nvmlDeviceGetTemperature(gpu, NVML_TEMPERATURE_GPU, &nTemp);
    *temp = (ret != NVML_SUCCESS) ? -1.0f : (float)nTemp;
    ret = NVML_nvmlDeviceGetFanSpeed(gpu, &nSpeed);
    *fanspeed = (ret != NVML_SUCCESS) ? -1 : (int)nSpeed;
}


void nvml_print_devices()
{
    uint dev, devnum = 0;
    nvmlReturn_t ret = NVML_nvmlDeviceGetCount(&devnum);
    if(ret != NVML_SUCCESS) {
        applog(LOG_ERR, "NVML: Device number query failed with code %s",
          NVML_nvmlErrorString(ret));
        return;
    }

    applog(LOG_INFO, "Number of NVML devices: %d", devnum);
    if(!devnum) return;

    for(dev = 0; dev < devnum; dev++) {
        char name[NVML_DEVICE_NAME_BUFFER_SIZE];
        nvmlDevice_t gpu;
        nvmlPciInfo_t pci;

        ret = NVML_nvmlDeviceGetHandleByIndex(dev, &gpu);
        if(ret != NVML_SUCCESS) {
            applog(LOG_ERR, "NVML: GPU %u handle failed with code %s",
              dev, NVML_nvmlErrorString(ret));
            return;
        }

        ret = NVML_nvmlDeviceGetName(gpu, name, NVML_DEVICE_NAME_BUFFER_SIZE);
        if(ret != NVML_SUCCESS) {
            applog(LOG_ERR, "NVML: GPU %u name query failed with code %s",
              dev, NVML_nvmlErrorString(ret));
            return;
        }

        ret = NVML_nvmlDeviceGetPciInfo(gpu, &pci);
        if(ret != NVML_SUCCESS) {
            applog(LOG_ERR, "NVML: GPU %u PCI ID query failed with code %s",
              dev, NVML_nvmlErrorString(ret));
            return;
        }

        applog(LOG_INFO, "GPU %u: %s [%s]", dev, name, pci.busId);
    }
}

void nvml_shutdown()
{
    nvmlReturn_t ret = NVML_nvmlShutdown();
    if(ret != NVML_SUCCESS) {
        applog(LOG_ERR, "NVML: Unable to shut down");
        return;
    }
    if(hDLL) dlclose(hDLL);
}

#else /* !(defined(__linux__) || defined(_WIN32)) */

/* Unsupported platform */

void nvml_init() {
    opt_nonvml = true;
}

void nvml_gpu_temp_and_fanspeed(const unsigned int __unused, float *temp, int *fanspeed) {
    *temp = -1.0f;
    *fanspeed = -1;
}

void nvml_print_devices() {}

void nvml_shutdown() {}

#endif /* defined(__linux__) || defined(_WIN32) */

#endif /* HAVE_NVML */
