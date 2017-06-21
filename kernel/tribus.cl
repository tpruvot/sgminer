/*
 * TRIBUS kernel implementation.
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

#if 0
#define CONST_EXP2 \
  q[i+0] + SPH_ROTL64(q[i+1], 5)  + q[i+2] + SPH_ROTL64(q[i+3], 11) + \
  q[i+4] + SPH_ROTL64(q[i+5], 27) + q[i+6] + SPH_ROTL64(q[i+7], 32) + \
  q[i+8] + SPH_ROTL64(q[i+9], 37) + q[i+10] + SPH_ROTL64(q[i+11], 43) + \
  q[i+12] + SPH_ROTL64(q[i+13], 53) + (SHR(q[i+14],1) ^ q[i+14]) + (SHR(q[i+15],2) ^ q[i+15])
#endif

typedef union {
  unsigned char h1[80];
  uint h4[20];
  ulong h8[10];
} hash_t;

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search(__global unsigned char* block, __global hash_t* hashes)
{
  uint gid = get_global_id(0);
  __global hash_t *out = &(hashes[gid-get_global_offset(0)]);

  hash_t hash;
  #pragma unroll
  for (int i = 0; i < 10; i++)
    hash.h8[i] = DEC64LE(&block[i*8]); // data seems already swapped
  hash.h4[19] = gid;

  // jh512 80 - by tpruvot

  sph_u64 h0h = C64e(0x6fd14b963e00aa17), h0l = C64e(0x636a2e057a15d543);
  sph_u64 h1h = C64e(0x8a225e8d0c97ef0b), h1l = C64e(0xe9341259f2b3c361);
  sph_u64 h2h = C64e(0x891da0c1536f801e), h2l = C64e(0x2aa9056bea2b6d80);
  sph_u64 h3h = C64e(0x588eccdb2075baa6), h3l = C64e(0xa90f3a76baf83bf7);
  sph_u64 h4h = C64e(0x0169e60541e34a69), h4l = C64e(0x46b58a8e2e6fe65a);
  sph_u64 h5h = C64e(0x1047a7d0c1843c24), h5l = C64e(0x3b6e71b12d5ac199);
  sph_u64 h6h = C64e(0xcf57f6ec9db1f856), h6l = C64e(0xa706887c5716b156);
  sph_u64 h7h = C64e(0xe3c2fcdfe68517fb), h7l = C64e(0x545a4678cc8cdd4b);
  sph_u64 tmp;

  // Round 1 (64 first bytes)
  h0h ^= hash.h8[0];
  h0l ^= hash.h8[1];
  h1h ^= hash.h8[2];
  h1l ^= hash.h8[3];
  h2h ^= hash.h8[4];
  h2l ^= hash.h8[5];
  h3h ^= hash.h8[6];
  h3l ^= hash.h8[7];
  E8;
  h4h ^= hash.h8[0];
  h4l ^= hash.h8[1];
  h5h ^= hash.h8[2];
  h5l ^= hash.h8[3];
  h6h ^= hash.h8[4];
  h6l ^= hash.h8[5];
  h7h ^= hash.h8[6];
  h7l ^= hash.h8[7];

  // Round 2 (16 bytes with nonce)
  h0h ^= hash.h8[8];
  h0l ^= hash.h8[9];
  h1h ^= 0x80U;
  E8;
  h4h ^= hash.h8[8];
  h4l ^= hash.h8[9];
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

