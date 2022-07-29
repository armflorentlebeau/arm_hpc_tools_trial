#!/bin/bash

ROOT_DIR=${PWD}
TMP_DIR=${ROOT_DIR}/tmp_test
TESTS="C F90 Py"
NPROCS=2
SIZE=64
PYTHON="python"
#PROFILE="map -s --profile"
MPIRUN_CMD="mpirun -n ${NPROCS}"

############# DO NOT EDIT BELOW #############
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
ERROR=0
NT=9

compile () {
  cd ${TMP_DIR}/src
  make clean
  printf "\t${GREEN}Cleaned directory${NC}\n"
  for i in ${TESTS}; do
    cd ${TMP_DIR}/src/$i
    if [ $i != "Py" ]; then
      make
      if [ ! -f ./mmult ]; then
        printf "\t${RED}FAILED compiling $i version${NC}\n"
        ERROR=$[ ${ERROR}+1 ]
      else
        printf "\t${GREEN}$i version compiled${NC}\n"
      fi
    else
      make
      if [ ! -f ./C/mmult*.so ] && [ ! -f ./F90/mmult*.so ]; then
        printf "\t${RED}FAILED compiling $i version${NC}\n"
        ERROR=$[ ${ERROR}+1 ]
      else
        printf "\t${GREEN}$i version compiled${NC}\n"
      fi
    fi
  done
}

run () {
  for i in ${TESTS}; do
    cd ${TMP_DIR}/src/$i
    rm -f myres_$i.mat output*.log diff*.log
    if [ $i != "Py" ]; then
      ${PROFILE} ${MPIRUN_CMD} ./mmult ${SIZE} myres_${i}.mat > output.log
      if [ ! -f myres_${i}.mat ]; then
        printf "\t${RED}ERROR while running $i version - no result file${NC}\n"
        ERROR=$[ ${ERROR}+1 ]
      else
        printf "\t${GREEN}Successfully ran $i version${NC}\n"
        diff -q myres_$i.mat ${ROOT_DIR}/test/ref/ref_$i.mat > diff.log
        if [ -s diff.log ]; then
          printf "\t${RED}ERROR while checking results for $i version - bad results${NC}\n"
          ERROR=$[ ${ERROR}+1 ]
        else
          printf "\t${GREEN}Successfully checked results for $i version${NC}\n"
        fi
      fi
    else
      if [ "${BLAS}" == "1" ]; then
        ${PROFILE} ${MPIRUN_CMD} ${PYTHON} ./mmult.py -k Py -s ${SIZE} > output_Py.log
        if [ ! -f res_${i}.mat ]; then
          printf "\t${RED}ERROR while running $i version - no result file${NC}\n"
          ERROR=$[ ${ERROR}+1 ]
        else
          printf "\t${GREEN}Successfully ran $i version${NC}\n"
          diff -q res_$i.mat ${ROOT_DIR}/test/ref/ref_$i.mat > diff.log
          if [ -s diff.log ]; then
            printf "\t${RED}ERROR while checking results for $i version - bad results${NC}\n"
            ERROR=$[ ${ERROR}+1 ]
          else
            printf "\t${GREEN}Successfully checked results for $i version${NC}\n"
          fi
        fi
      else
        ${PROFILE} ${MPIRUN_CMD} ${PYTHON} ./mmult.py -o myres_Py_C.mat -s ${SIZE} > output_C.log
        ${PROFILE} ${MPIRUN_CMD} ${PYTHON} ./mmult.py -k F90 -o myres_Py_F90.mat -s ${SIZE} > output_F90.log
        if [ ! -f myres_Py_C.mat ] || [ ! -f myres_Py_F90.mat ]; then
          printf "\t${RED}ERROR while running $i version - no result file${NC}\n"
          ERROR=$[ ${ERROR}+1 ]
        else
          printf "\t${GREEN}Successfully ran $i version${NC}\n"
          if [ -s diff_C.log ] || [ -s diff_F90.log ]; then
            printf "\t${RED}ERROR while checking results for $i version - bad results${NC}\n"
            ERROR=$[ ${ERROR}+1 ]
          else
            printf "\t${GREEN}Successfully checked results for $i version${NC}\n"
          fi
        fi
      fi
    fi
  done
}


printf "Downloading trial package...\n\n"
if [ ! -f $PACKAGE.tar.gz ]; then
  wget https://armkeil.blob.core.windows.net/developer/Files/downloads/hpc/aas-forge-trials-package/$PACKAGE.tar.gz
fi

tar xf $PACKAGE.tar.gz $PACKAGE/src/ -C .
mv $PACKAGE/src .
rm -rf $PACKAGE

printf "${GREEN}[1/${NT}] Start trial package test: copy sources${NC}\n\n"
BLAS="0"
mkdir ${TMP_DIR}
cd ${TMP_DIR}
cp -r ${ROOT_DIR}/src .

printf "${GREEN}[2/${NT}] Apply fix and compile...${NC}\n"
patch -s -p 1 < ${ROOT_DIR}/test/patches/fix.patch
compile

echo
printf "${GREEN}[3/${NT}] Run...${NC}\n"
run
echo

printf "${GREEN}[4/${NT}] Recompile with optimizations...${NC}\n"
cd ${TMP_DIR}
patch -s -p 1 < ${ROOT_DIR}/test/patches/opt.patch
compile

echo
printf "${GREEN}[5/${NT}] Run...${NC}\n"
run
echo

printf "${GREEN}[6/${NT}] Recompile with BLAS...${NC}\n"
cd ${TMP_DIR}
patch -s -p 1 < ${ROOT_DIR}/test/patches/blas.patch
compile

echo
printf "${GREEN}[7/${NT}] Run...${NC}\n"
BLAS="1"
run
echo

printf "${GREEN}[8/${NT}] Remove temporary folder...${NC}\n\n"
cd ${ROOT_DIR}
# Comment the two lines below for debugging
rm -rf ${TMP_DIR}
rm -rf $PACKAGE.tar.gz

if [ "${ERROR}" == "0" ]; then
  printf "${GREEN}[9/${NT}] Completed with no error${NC}\n"
else
  printf "${RED}[9/${NT}] Completed with %d error(s)${NC}\n" ${ERROR}
fi

exit ${ERROR}
