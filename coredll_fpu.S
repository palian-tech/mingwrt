/* coredll_fpu.S: calls from -m4-nofpu code into the floating-point
   functions of the SH-4 coredll.dll (sh4-mingw32ce only).

   coredll.dll on SH-4 Windows CE is built by the Microsoft compiler with
   /Qsh4, which passes float and double in FPU registers: a double
   argument goes to dr4, then dr6 (the even register holds the high word),
   and still takes its two integer argument slots (an int after it goes to
   r6); a double result comes back in dr0.  FPSCR.PR and FPSCR.SZ are 0 at
   calls.  GCC's -m4-nofpu code passes a double in two integer registers,
   low word first, and returns it in memory through a hidden pointer in r4.
   See docs/sh4/ABI.md in cegcc-build.

   This file is assembled once per thunk with
     -DNAME=symbol -DIMP=__imp_symbol -DKIND=kind
   and the object goes into the import library, replacing the jump stub
   of the function (coredll_fpu.sh).  A thunk saves PR and FPSCR, clears
   FPSCR.PR and FPSCR.SZ, moves the arguments, calls the coredll function
   through IMP with a fresh 16-byte register save area, moves the result
   back and restores FPSCR.

   Kinds, by C prototype (D double, F float, I int or pointer):
     D_D D_DD D_DI D_ID D_I D_II  double results
     I_D I_DD I_DII I_DIII        int or pointer results
     F_F F_FF I_F I_FF            float functions, computed by the double
                                  function IMP (exact for these)
     F_ABS                        fabsf, no call  */

/* Save PR and FPSCR; FPSCR.PR = FPSCR.SZ = 0.  Uses r0, r1.  */
	.macro	ENTER
	sts.l	pr,@-r15
	sts.l	fpscr,@-r15
	sts	fpscr,r0
	mov	#0x18,r1
	shll16	r1
	not	r1,r1
	and	r1,r0
	lds	r0,fpscr
	.endm

	.macro	LEAVE
	lds.l	@r15+,fpscr
	lds.l	@r15+,pr
	rts
	nop
	.endm

/* FPSCR.PR = 1 or 0.  Uses r1, r2.  */
	.macro	PR1
	sts	fpscr,r1
	mov	#8,r2
	shll16	r2
	or	r2,r1
	lds	r1,fpscr
	.endm

	.macro	PR0
	sts	fpscr,r1
	mov	#8,r2
	shll16	r2
	not	r2,r2
	and	r2,r1
	lds	r1,fpscr
	.endm

/* Double in integer registers LO, HI to the FPU pair HI_FR:LO_FR.  */
	.macro	DARG lo, hi, frhi, frlo
	lds	\lo,fpul
	fsts	fpul,\frlo
	lds	\hi,fpul
	fsts	fpul,\frhi
	.endm

	.macro	CALL imp
	mov.l	1f,r0
	mov.l	@r0,r0
	jsr	@r0
	nop
	bra	2f
	nop
	.align	2
1:	.long	\imp
2:
	.endm

/* Double result: the hidden pointer goes to r8 (saved), the remaining
   arguments move down one register.  */
	.macro	DENTER
	ENTER
	mov.l	r8,@-r15
	mov	r4,r8
	add	#-20,r15
	.endm

/* Store dr0 at @r8 and return r8.  */
	.macro	DLEAVE
	flds	fr1,fpul
	sts	fpul,r1
	mov.l	r1,@r8
	flds	fr0,fpul
	sts	fpul,r1
	mov.l	r1,@(4,r8)
	mov	r8,r0
	add	#20,r15
	mov.l	@r15+,r8
	LEAVE
	.endm

	.macro	D_D name, imp		/* double f (double) */
	DENTER
	DARG	r5, r6, fr4, fr5
	CALL	\imp
	DLEAVE
	.endm

	.macro	D_DD name, imp		/* double f (double, double) */
	DENTER
	DARG	r5, r6, fr4, fr5
	/* The high word of the second double is on the caller's stack.  */
	mov.l	@(48,r15),r1
	DARG	r7, r1, fr6, fr7
	CALL	\imp
	DLEAVE
	.endm

	.macro	D_DI name, imp		/* double f (double, int) */
	DENTER
	DARG	r5, r6, fr4, fr5
	mov	r7,r6
	CALL	\imp
	DLEAVE
	.endm

	.macro	D_ID name, imp		/* double f (int, double) */
	DENTER
	DARG	r6, r7, fr4, fr5
	mov	r5,r4
	CALL	\imp
	DLEAVE
	.endm

	.macro	D_I name, imp		/* double f (int) */
	DENTER
	mov	r5,r4
	CALL	\imp
	DLEAVE
	.endm

	.macro	D_II name, imp		/* double f (int, int) */
	DENTER
	mov	r5,r4
	mov	r6,r5
	CALL	\imp
	DLEAVE
	.endm

	.macro	I_D name, imp		/* int f (double) */
	ENTER
	add	#-16,r15
	DARG	r4, r5, fr4, fr5
	CALL	\imp
	add	#16,r15
	LEAVE
	.endm

	.macro	I_DD name, imp		/* int f (double, double) */
	ENTER
	add	#-16,r15
	DARG	r4, r5, fr4, fr5
	DARG	r6, r7, fr6, fr7
	CALL	\imp
	add	#16,r15
	LEAVE
	.endm

	.macro	I_DII name, imp		/* int f (double, int, int) */
	I_D	\name, \imp
	.endm

	.macro	I_DIII name, imp	/* int f (double, int, int, int) */
	ENTER
	add	#-24,r15
	/* The fourth argument is at @(16,r15) on entry.  */
	mov.l	@(48,r15),r1
	mov.l	r1,@(16,r15)
	DARG	r4, r5, fr4, fr5
	CALL	\imp
	add	#24,r15
	LEAVE
	.endm

/* float x in r4 to dr4, float y in r5 to dr6.  */
	.macro	FARGS n
	ENTER
	add	#-16,r15
	PR1
	lds	r4,fpul
	fcnvsd	fpul,dr4
	.if \n == 2
	lds	r5,fpul
	fcnvsd	fpul,dr6
	.endif
	PR0
	.endm

	.macro	F_F name, imp		/* float f (float) */
	FARGS	1
	CALL	\imp
	PR1
	fcnvds	dr0,fpul
	PR0
	sts	fpul,r0
	add	#16,r15
	LEAVE
	.endm

	.macro	F_FF name, imp		/* float f (float, float) */
	FARGS	2
	CALL	\imp
	PR1
	fcnvds	dr0,fpul
	PR0
	sts	fpul,r0
	add	#16,r15
	LEAVE
	.endm

	.macro	I_F name, imp		/* int f (float) */
	FARGS	1
	CALL	\imp
	add	#16,r15
	LEAVE
	.endm

	.macro	I_FF name, imp		/* int f (float, float) */
	FARGS	2
	CALL	\imp
	add	#16,r15
	LEAVE
	.endm

	.macro	F_ABS name, imp		/* fabsf */
	mov	r4,r0
	shll	r0
	rts
	shlr	r0
	.endm

	.text
	.align	2
	.global	NAME
NAME:
	KIND	NAME, IMP
