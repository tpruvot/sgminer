/*
 * TRIBUS kernel implementation v2 (with midstate)
 *
 * ==========================(LICENSE BEGIN)============================
 *
 * Copyright (c) 2017 tpruvot
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * ===========================(LICENSE END)=============================
 */

#define DEBUG(x)

#if __ENDIAN_LITTLE__
  #define SPH_LITTLE_ENDIAN 1
#else
  #define SPH_BIG_ENDIAN 1
#endif

#define SPH_UPTR sph_u64

typedef unsigned int sph_u32;
typedef int sph_s32;
#ifndef __OPENCL_VERSION__
  typedef unsigned long long sph_u64;
  typedef long long sph_s64;
#else
  typedef unsigned long sph_u64;
  typedef long sph_s64;
#endif

#define SPH_64 1
#define SPH_64_TRUE 1

#define SPH_C32(x)    ((sph_u32)(x ## U))
#define SPH_T32(x) (as_uint(x))
#define SPH_ROTL32(x, n) rotate(as_uint(x), as_uint(n))
#define SPH_ROTR32(x, n)   SPH_ROTL32(x, (32 - (n)))

#define SPH_C64(x)    ((sph_u64)(x ## UL))
#define SPH_T64(x) (as_ulong(x))
#define SPH_ROTL64(x, n) rotate(as_ulong(x), (n) & 0xFFFFFFFFFFFFFFFFUL)
#define SPH_ROTR64(x, n)   SPH_ROTL64(x, (64 - (n)))

#define SPH_ECHO_64 1
#define SPH_KECCAK_64 1
#define SPH_JH_64 1
#define SPH_KECCAK_NOCOPY 0

#ifndef SPH_KECCAK_UNROLL
  #define SPH_KECCAK_UNROLL 0
#endif

#include "jh.cl"
#include "keccak.cl"
#include "echo.cl"

#define SWAP4(x) as_uint(as_uchar4(x).wzyx)
#define SWAP8(x) as_ulong(as_uchar8(x).s76543210)

#if SPH_BIG_ENDIAN
  #define DEC64E(x) (x)
  #define DEC64LE(x) SWAP8(*(const __global sph_u64 *) (x));
  #define DEC64BE(x) (*(const __global sph_u64 *) (x));
#else
  #define DEC64E(x) SWAP8(x)
  #define DEC64LE(x) (*(const __global sph_u64 *) (x));
  #define DEC64BE(x) SWAP8(*(const __global sph_u64 *) (x));
#endif

#define SHL(x, n) ((x) << (n))
#define SHR(x, n) ((x) >> (n))

typedef union {
  unsigned char h1[64];
  uint h4[16];
  ulong h8[8];
} hash_t;

typedef union {
  unsigned char h1[16];
  uint  h4[4];
  ulong h8[2];
} hash16_t;

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search(__global sph_u64 *midstate, __global hash_t* hashes)
{
  uint gid = get_global_id(0);
  __global hash_t *out = &(hashes[gid-get_global_offset(0)]);

  // jh512 midstate
  sph_u64 h0h = DEC64LE(&midstate[0]);
  sph_u64 h0l = DEC64LE(&midstate[1]);
  sph_u64 h1h = DEC64LE(&midstate[2]);
  sph_u64 h1l = DEC64LE(&midstate[3]);
  sph_u64 h2h = DEC64LE(&midstate[4]);
  sph_u64 h2l = DEC64LE(&midstate[5]);
  sph_u64 h3h = DEC64LE(&midstate[6]);
  sph_u64 h3l = DEC64LE(&midstate[7]);

  sph_u64 h4h = DEC64LE(&midstate[0 + 8]);
  sph_u64 h4l = DEC64LE(&midstate[1 + 8]);
  sph_u64 h5h = DEC64LE(&midstate[2 + 8]);
  sph_u64 h5l = DEC64LE(&midstate[3 + 8]);
  sph_u64 h6h = DEC64LE(&midstate[4 + 8]);
  sph_u64 h6l = DEC64LE(&midstate[5 + 8]);
  sph_u64 h7h = DEC64LE(&midstate[6 + 8]);
  sph_u64 h7l = DEC64LE(&midstate[7 + 8]);

  // end of input data with nonce
  hash16_t hash;
  hash.h8[0] = DEC64LE(&midstate[16]);
  hash.h8[1] = DEC64LE(&midstate[17]);
  hash.h4[3] = gid;

  sph_u64 tmp;

  // Round 2 (16 bytes with nonce)
  h0h ^= hash.h8[0];
  h0l ^= hash.h8[1];
  h1h ^= 0x80U;
  E8;
  h4h ^= hash.h8[0];
  h4l ^= hash.h8[1];
  h5h ^= 0x80U;

  // Round 3 (close, 640 bits input)
  h3l ^= 0x8002000000000000UL;
  E8;
  h7l ^= 0x8002000000000000UL;

  // keccak

  sph_u64 a00 = h4h, a01 = h6l, a02 = 0, a03 = 0, a04 = 0;
  sph_u64 a10 = h4l, a11 = h7h, a12 = 0, a13 = 0, a14 = 0;
  sph_u64 a20 = h5h, a21 = h7l, a22 = 0, a23 = 0, a24 = 0;
  sph_u64 a30 = h5l, a31 = 0,   a32 = 0, a33 = 0, a34 = 0;
  sph_u64 a40 = h6h, a41 = 0  , a42 = 0, a43 = 0, a44 = 0;

  a10 ^= SPH_C64(0xFFFFFFFFFFFFFFFF);
  a20 ^= SPH_C64(0xFFFFFFFFFFFFFFFF);
  a31 ^= SPH_C64(0xFFFFFFFFFFFFFFFF);
  a22 ^= SPH_C64(0xFFFFFFFFFFFFFFFF);
  a23 ^= SPH_C64(0xFFFFFFFFFFFFFFFF);
  a04 ^= SPH_C64(0xFFFFFFFFFFFFFFFF);

  a31 ^= 0x8000000000000001;
  KECCAK_F_1600;

  // Finalize the "lane complement"
  a10 = ~a10;
  a20 = ~a20;

  out->h8[0] = a00;
  out->h8[1] = a10;
  out->h8[2] = a20;
  out->h8[3] = a30;
  out->h8[4] = a40;
  out->h8[5] = a01;
  out->h8[6] = a11;
  out->h8[7] = a21;

  barrier(CLK_GLOBAL_MEM_FENCE);
}

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search1(__global hash_t* hashes, volatile __global uint* output, const ulong target)
{
  uint gid = get_global_id(0);
  uint offset = get_global_offset(0);
  __global hash_t *hash = &(hashes[gid-offset]);

  __local sph_u32 AES0[256], AES1[256], AES2[256], AES3[256];

  int init = get_local_id(0);
  int step = get_local_size(0);

  for (int i = init; i < 256; i += step)
  {
    AES0[i] = AES0_C[i];
    AES1[i] = AES1_C[i];
    AES2[i] = AES2_C[i];
    AES3[i] = AES3_C[i];
  }

  barrier(CLK_LOCAL_MEM_FENCE);

  // echo
  sph_u64 W00, W01, W10, W11, W20, W21, W30, W31, W40, W41, W50, W51, W60, W61, W70, W71;
  sph_u64 W80, W81, W90, W91, WA0, WA1, WB0, WB1, WC0, WC1, WD0, WD1, WE0, WE1, WF0, WF1;
  sph_u64 Vb00, Vb01, Vb10, Vb11, Vb20, Vb21, Vb30, Vb31, Vb40, Vb41, Vb50, Vb51, Vb60, Vb61, Vb70, Vb71;

  sph_u32 K0 = 512;
  sph_u32 K1 = 0;
  sph_u32 K2 = 0;
  sph_u32 K3 = 0;

  Vb00 = Vb10 = Vb20 = Vb30 = Vb40 = Vb50 = Vb60 = Vb70 = 512UL;
  Vb01 = Vb11 = Vb21 = Vb31 = Vb41 = Vb51 = Vb61 = Vb71 = 0;

  W00 = Vb00;
  W01 = Vb01;
  W10 = Vb10;
  W11 = Vb11;
  W20 = Vb20;
  W21 = Vb21;
  W30 = Vb30;
  W31 = Vb31;
  W40 = Vb40;
  W41 = Vb41;
  W50 = Vb50;
  W51 = Vb51;
  W60 = Vb60;
  W61 = Vb61;
  W70 = Vb70;
  W71 = Vb71;

  W80 = hash->h8[0];
  W81 = hash->h8[1];
  W90 = hash->h8[2];
  W91 = hash->h8[3];
  WA0 = hash->h8[4];
  WA1 = hash->h8[5];
  WB0 = hash->h8[6];
  WB1 = hash->h8[7];
  WC0 = 0x80;
  WC1 = 0;
  WD0 = 0;
  WD1 = 0;
  WE0 = 0;
  WE1 = 0x200000000000000;
  WF0 = 0x200;
  WF1 = 0;

  for (unsigned u = 0; u < 10; u ++) {
    BIG_ROUND;
  }

  sph_u64 h83 = hash->h8[3] ^ Vb11 ^ W11 ^ W91;

  barrier(CLK_GLOBAL_MEM_FENCE);

  if (h83 <= target)
    output[output[0xFF]++] = SWAP4(gid);
}

