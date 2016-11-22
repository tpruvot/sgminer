/**
 * Basic sysfs monitoring for amdgpu cards
 **/

#include "miner.h"

#ifdef __linux__

#include <math.h>
#include <sys/stat.h>

void sysfs_gpu_temp_and_fanspeed(const unsigned int gpuid, float *temp, int *fanspeed)
{
  int hwmon = 0;
  unsigned int hwmon_gpu = 0;

  *temp = -1.0f;
  *fanspeed = -1;

  while (true) {
    char dname[64] = { 0 };
    char fname[PATH_MAX];
    struct stat hwmon_folder;
    sprintf(dname, "/sys/class/hwmon/hwmon%d", hwmon);
    if (stat(dname, &hwmon_folder) != 0) break;

    sprintf(fname, "%s/pwm1", dname);
    if (stat(fname, &hwmon_folder) == 0) {
      if (hwmon_gpu == gpuid) {
        FILE *f = fopen(fname, "rb");
        if (f) {
          int pwm = 0;
          if (fscanf(f, "%d", &pwm) > 0)
            *fanspeed = round((float) (pwm * 100) / 255.);
          fclose(f);
        }
        sprintf(fname, "%s/temp1_input", dname);
        f = fopen(fname, "rb");
        if (f) {
          int t = 0;
          if (fscanf(f, "%d", &t) > 0)
            *temp = (float) t / 1000;
          fclose(f);
        }
      }
      hwmon_gpu++;
    }
    hwmon++;
  }
}

#endif /* __linux__ sysfs */
