#!/usr/bin/env bash

ROOT_DIR=${PWD}
TMP_DIR=${ROOT_DIR}/tmp_test


usage () {
  echo "$0 [C | F90 | Py]"
}


check_output () { # $1-string
  #check if $1 is found in app.out
  if grep -q "${1}" app.out; then
    return 0
  else
    return 1
  fi
}


test_c () {
  echo "Testing C version"
  pushd src/C
  juLog -name="build" make
  mpirun ./mmult 2>&1 | tee app.out
  juLog -name="run" check_output "0: Done."
  juLog -name="results" diff -q res_*.mat ${ROOT_DIR}/test/ref/ref_C.mat
  popd
}


test_f90 () {
  echo "Testing Fortran version"
  pushd src/F90
  juLog -name="f_build" make
  mpirun ./mmult 2>&1 | tee app.out
  juLog -name="f_run" check_output "0 : Done."
  juLog -name="f_results" diff -q res_*.mat ${ROOT_DIR}/test/ref/ref_F90.mat
  popd
}


test_py () {
  echo "Testing Py version"
  pushd src/Py
  juLog -name="py_build" make
  mpirun python3 ./mmult.py -k C 2>&1 | tee app.out
  juLog -name="py_run_c" check_output "0: Done"
  juLog -name="py_results_c" diff -q res_*.mat ${ROOT_DIR}/test/ref/ref_Py.mat
  mpirun python3 ./mmult.py -k F90 2>&1 | tee app.out
  juLog -name="py_run_f" check_output "0: Done"
  juLog -name="py_results_f" diff -q res_*.mat ${ROOT_DIR}/test/ref/ref_Py.mat
  popd
}

test_p_blas () {
  echo "Testing Py version"
  pushd src/Py
  mpirun python3 ./mmult.py -k Py 2>&1 | tee app.out
  juLog -name="py_run_py" check_output "0: Done"
  juLog -name="py_results_py" diff -q res_*.mat ${ROOT_DIR}/test/ref/ref_Py.mat
  popd
}



setup () {
  if [ ! -f ${TMP_DIR} ]; then
    rm -rf ${TMP_DIR}
  fi
  mkdir ${TMP_DIR} && cd ${TMP_DIR}
  cp -r ${ROOT_DIR}/src .

  # Requires https://github.com/manolo/shell2junit in shell2junit folder
  git clone https://github.com/manolo/shell2junit
. shell2junit/sh2ju.sh

  juLogClean

  patch -s -p 1 < ${ROOT_DIR}/test/patches/fix.patch
  patch -s -p 1 < ${ROOT_DIR}/test/patches/opt.patch
}


case $1 in 
  C)
    setup
    test_c
    patch -s -p 1 < ${ROOT_DIR}/test/patches/blas.patch
    test_c
    ;;
  F90)
    setup
    test_f90
    patch -s -p 1 < ${ROOT_DIR}/test/patches/blas.patch
    test_f90
    ;;
  Py)
    setup
    test_py
    patch -s -p 1 < ${ROOT_DIR}/test/patches/blas.patch
    test_py_blas
    ;;
  *)
    usage
    ;;
esac

cd $ROOT_DIR
exit

