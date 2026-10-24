#!/bin/sh
# coredll_fpu.sh LIBRARY ID SRCDIR
#
# sh4-mingw32ce: replaces the jump stubs of coredll's floating-point
# functions in the import library LIBRARY (libcoredll.a, libcoredll6.a:
# ID coredll; libceoldname.a: ID ceoldname) by the thunks of
# coredll_fpu.S, as listed in coredll_fpu.lst.  The jump stub's symbol is
# renamed so that the thunk's definition is the only one; the import
# pointer __imp__NAME stays in the import member, which the thunk pulls in.
#
# Running it again on a library that has the thunks changes nothing, so
# it can also be applied to another libcoredll.a installed later (w32api's).
#
# Uses CC, AR, NM and OBJCOPY from the environment.
set -e
lib=$1 id=$2 srcdir=$3
case $lib in /*) ;; *) lib=`pwd`/$lib ;; esac
tmp=`pwd`/fpu-`basename $lib`.tmp
rm -rf $tmp && mkdir $tmp
syms=`$NM -A $lib`
grep -v '^#' $srcdir/coredll_fpu.lst | while read l name kind imp; do
  test "$l" = "$id" || continue
  member=`echo "$syms" | sed -n "s/^[^:]*:\([^:]*\):[0-9a-f]* T _$name\$/\1/p"`
  case $member in
    "") echo "coredll_fpu.sh: $lib has no _$name, skipped"; continue ;;
    fpu_*) continue ;;
  esac
  (cd $tmp && $AR x $lib $member)
  $OBJCOPY --redefine-sym _$name=__coredll_fpu_stub_$name $tmp/$member
  $AR r $lib $tmp/$member
  $CC -c -x assembler-with-cpp -DNAME=_$name -DIMP=__imp__$imp -DKIND=$kind \
    $srcdir/coredll_fpu.S -o $tmp/fpu_$name.o
  $AR r $lib $tmp/fpu_$name.o
  rm -f $tmp/$member
done
$AR s $lib
rm -rf $tmp
