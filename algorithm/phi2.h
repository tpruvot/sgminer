#ifndef PHI2_H
#define PHI2_H

#include "miner.h"

// (4 * memshift(3) * 8 * 8 * 8)
#define LYRA2X2_SCRATCHBUF_SIZE 6144

extern void precalc_hash_cube(dev_blk_ctx *blk, uint32_t *midstate, uint32_t *pdata);

extern void phi2_regenhash(struct work *work);

#endif /* PHI2_H */
