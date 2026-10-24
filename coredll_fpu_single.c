/* coredll_fpu_single.c: the float functions of coredll_fpu.lst for
   -m4-single code (sh4-mingw32ce only).

   -m4-single code passes float and double in FPU registers like coredll's
   own /Qsh4 code, so it calls coredll's floating-point functions directly,
   without the thunks of coredll_fpu.S.  Only the float functions need a
   replacement: the CE 5.0 SH-4 coredll does not export all of them
   (sqrtf, fabsf), and a missing import keeps an EXE from loading.  As in
   coredll_fpu.S, they are computed by the double function IMP (exact for
   these), and fabsf clears the sign bit.

   This file is compiled once per function with
     -DNAME=name -DIMP=imp -DKIND_<kind>
   and the object replaces the function's import member (coredll_fpu.sh).  */

#if defined KIND_F_F
double IMP (double);
float NAME (float x) { return (float) IMP (x); }
#elif defined KIND_F_FF
double IMP (double, double);
float NAME (float x, float y) { return (float) IMP (x, y); }
#elif defined KIND_I_F
int IMP (double);
int NAME (float x) { return IMP (x); }
#elif defined KIND_I_FF
int IMP (double, double);
int NAME (float x, float y) { return IMP (x, y); }
#elif defined KIND_F_ABS
float
NAME (float x)
{
  union { float f; unsigned u; } v;
  v.f = x;
  v.u &= 0x7fffffff;
  return v.f;
}
#else
#error unknown KIND
#endif
