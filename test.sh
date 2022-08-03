#!/usr/bin/env bash

ROOT_DIR=${PWD}
TMP_DIR=${ROOT_DIR}/tmp_test

if [ ! -f ${TMP_DIR} ]; then
  rm -rf ${TMP_DIR}
fi
mkdir ${TMP_DIR} && cd ${TMP_DIR}
cp -r ${ROOT_DIR}/src .

# Requires https://github.com/manolo/shell2junit in shell2junit folder
git clone https://github.com/manolo/shell2junit
. shell2junit/sh2ju.sh

juLogClean

check_output () { # $1-string
  #check if $1 is found in app.out
  if grep -q "${1}" app.out; then
    return 0
  else
    return 1
  fi
}

# Enable ASAN
patch -s -p 1 < ${ROOT_DIR}/test/patches/asan.patch

echo "Testing C version"
pushd src/C
juLog -name="build" -class="c_dbg" make
mpirun ./mmult 2>&1 | tee app.out
juLog -name="run_buffer_overflow" -class="c_dbg" check_output "AddressSanitizer: heap-buffer-overflow"
#juLog -name="run_stack0" -class="c_dbg" check_output "mmult.c:67"
#juLog -name="run_stack1" -class="c_dbg" check_output "mmult.c:164"
popd

echo "Testing Fortran version"
pushd src/F90
juLog -name="build" -class="fortran_dbg" make
mpirun ./mmult 2>&1 | tee app.out
juLog -name="run_buffer_overflow" -class="fortran_dbg" check_output "AddressSanitizer: heap-buffer-overflow"
#juLog -name="run_stack0" -class="fortran_dbg" check_output "mmult.F90:78"
#juLog -name="run_stack1" -class="fortran_dbg" check_output "mmult.F90:17"
popd

echo "Testing Python version"
pushd src/Py
juLog -name="build" -class="py_dbg" make
mpirun python3 ./mmult.py -k C &> app.out
juLog -name="run_c_buffer_overflow" -class="py_dbg" check_output "AddressSanitizer: heap-buffer-overflow"
mpirun python3 ./mmult.py -k F90 &> app.out
juLog -name="run_f90_buffer_overflow" -class="py_dbg" check_output "AddressSanitizer: heap-buffer-overflow"
popd

cd $ROOT_DIR

