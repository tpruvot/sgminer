/*-
 * Copyright 2016 tpruvot
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * This file was originally written by Colin Percival as part of the Tarsnap
 * online backup system.
 */

#include "config.h"
#include "miner.h"

#include <stdlib.h>
#include <stdint.h>
#include <string.h>


#include "sph/sph_skein.h"

/* Move init out of loop, so init once externally, and then use one single memcpy with that bigger memory block */
typedef struct {
    sph_skein512_context    skein1;
    sph_skein512_context    skein2;
} Xhash_context_holder;

static Xhash_context_holder base_contexts;

static void init_Xhash_contexts()
{
    sph_skein512_init(&base_contexts.skein1);
    sph_skein512_init(&base_contexts.skein2);
}

static inline void be32enc_vect(uint32_t *dst, const uint32_t *src, uint32_t len)
{
	for (uint32_t i = 0; i < len; i++)
		dst[i] = htobe32(src[i]);
}

static inline void xhash(void *state, const void *input)
{
    init_Xhash_contexts();

    Xhash_context_holder ctx;

    uint32_t hashA[16];

    memcpy(&ctx, &base_contexts, sizeof(base_contexts));

    sph_skein512(&ctx.skein1, input, 80);
    sph_skein512_close(&ctx.skein1, hashA);

    sph_skein512(&ctx.skein2, hashA, 64);
    sph_skein512_close(&ctx.skein2, hashA);

    memcpy(state, hashA, 32);
}

static const uint32_t diff1targ = 0x0000ffff;

void skein2_regenhash(struct work *work)
{
    uint32_t data[20];
    uint32_t *nonce = (uint32_t*) (work->data + 76);
    uint32_t *ohash = (uint32_t*) (work->hash);

    be32enc_vect(data, (const uint32_t *)work->data, 19);
    data[19] = htobe32(*nonce);
    xhash(ohash, data);
	// applog_hex(ohash, 32);
}
