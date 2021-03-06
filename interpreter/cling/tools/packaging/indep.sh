#! /bin/bash

###############################################################################
#
#                           The Cling Interpreter
#
# Cling Packaging Tool (CPT)
#
# tools/packaging/indep.sh: Platform independent script with helper functions
# for CPT.
#
# Author: Anirudha Bose <ani07nov@gmail.com>
#
# This file is dual-licensed: you can choose to license it under the University
# of Illinois Open Source License or the GNU Lesser General Public License. See
# LICENSE.TXT for details.
#
###############################################################################

# Uncomment the following line to trace the execution of the shell commands
# set -o xtrace

function platform_init {
  OS=$(uname -o)

  if [ "${OS}" = "Cygwin" ]; then
    DIST="Win"
    SHLIBEXT=".dll"
    EXEEXT=".exe"

  elif [ "{$OS}" = "Darwin" ]; then
    OS="Mac OS"

  elif [ "${OS}" = "GNU/Linux" ] ; then
    if [ -f /etc/redhat-release ] ; then
      DistroBasedOn='RedHat'
      DIST=$(cat /etc/redhat-release |sed s/\ release.*//)
      PSEUDONAME=$(cat /etc/redhat-release | sed s/.*\(// | sed s/\)//)
      REV=$(cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//)
    elif [ -f /etc/debian_version ] ; then
      DistroBasedOn='Debian'
      DIST=$(cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }')
      PSEUDONAME=$(cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }')
      REV=$(cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }')
    fi
  fi

  if [ "${DIST}" = "" ]; then
    DIST="N/A"
  fi

  if [ "${DistroBasedOn}" = "" ]; then
    DistroBasedOn="N/A"
  fi

  if [ "${PSEUDONAME}" = "" ]; then
    PSEUDONAME="N/A"
  fi

  if [ "${REV}" = "" ]; then
    REV="N/A"
  fi
}

function get_OS {
  printf "%s" "${OS}"
}

function get_DIST {
  printf "%s" "${DIST}"
}

function get_DistroBasedOn {
  printf "%s" "${DistroBasedOn}"
}
function get_PSEUDONAME {
  printf "%s" "${PSEUDONAME}"
}
function get_REVISION {
  printf "%s" "${REV}"
}

function get_BIT {
  printf "%s" "$(getconf LONG_BIT)"
}

# Helper functions to prettify text like that in Debian Build logs
function box_draw_header {
  msg="cling ($(uname -m))$(date --rfc-2822)"
  spaces_no=$(echo "80 $(echo ${msg} | wc -m)" | awk '{printf "%d", $1 - $2 - 3}')
  spacer=$(head -c ${spaces_no} < /dev/zero | tr '\0' ' ')
  msg="cling ($(uname -m))${spacer}$(date --rfc-2822)"
  echo "\
╔══════════════════════════════════════════════════════════════════════════════╗
║ ${msg} ║
╚══════════════════════════════════════════════════════════════════════════════╝"
}

function box_draw {
  msg=${1}
  spaces_no=$(echo "80 $(echo ${msg} | wc -m)" | awk '{printf "%d", $1 - $2 - 3}')
  spacer=$(head -c ${spaces_no} < /dev/zero | tr '\0' ' ')
  echo "\
┌──────────────────────────────────────────────────────────────────────────────┐
│ ${msg}${spacer} │
└──────────────────────────────────────────────────────────────────────────────┘"
}

# Fetch the sources for the vendor clone of LLVM
function fetch_llvm {
  box_draw "Fetch source files"
  # TODO: Change the URL to use the actual Git repo of Cling, rather than Github.
  #       Use "git archive --remote=<url> ..." or similar to remove "wget" as dependency.
  LLVMRevision=$(wget -q -O- https://raw.githubusercontent.com/ani07nov/cling/master/LastKnownGoodLLVMSVNRevision.txt)
  echo "Last known good LLVM revision is: ${LLVMRevision}"

  function get_fresh_llvm {
    # ${LLVM_GIT_URL} can be overridden. More information in README.md.
    LLVM_GIT_URL=${LLVM_GIT_URL:-"http://root.cern.ch/git/llvm.git"}
    git clone ${LLVM_GIT_URL} ${srcdir}
    cd ${srcdir}
    git checkout ROOT-patches-r${LLVMRevision}
  }

  function update_old_llvm {
    git clean -f -x -d
    git fetch --tags
    git checkout ROOT-patches-r${LLVMRevision}
    git pull origin refs/tags/ROOT-patches-r${LLVMRevision}
  }

  if [ -d ${srcdir} ]; then
    cd ${srcdir}
    if [ ! -z ${LLVM_GIT_URL} ]; then
      grep -q ${LLVM_GIT_URL} ${srcdir}/.git/config
      if [ ${?} = 0 ]; then
        update_old_llvm
      else
        cd ${workdir}
        rm -Rf ${srcdir}
        get_fresh_llvm
      fi
    else
      update_old_llvm
    fi
  else
    get_fresh_llvm
  fi
}

# Fetch the sources for the vendor clone of Clang
function fetch_clang {
  function get_fresh_clang {
    # ${CLANG_GIT_URL} can be overridden. More information in README.md.
    CLANG_GIT_URL=${CLANG_GIT_URL:-"http://root.cern.ch/git/clang.git"}
    git clone ${CLANG_GIT_URL} ${srcdir}/tools/clang
    cd ${srcdir}/tools/clang
    git checkout ROOT-patches-r${LLVMRevision}
  }

  function update_old_clang {
    git clean -f -x -d
    git fetch --tags
    git checkout ROOT-patches-r${LLVMRevision}
    git pull origin refs/tags/ROOT-patches-r${LLVMRevision}
  }

  if [ -d ${srcdir}/tools/clang ]; then
    cd ${srcdir}/tools/clang
    if [ ! -z ${CLANG_GIT_URL} ]; then
      grep -q ${CLANG_GIT_URL} ${srcdir}/tools/clang/.git/config
      if [ ${?} = 0 ]; then
        update_old_clang
      else
        cd ${srcdir}/tools
        rm -Rf ${srcdir}/tools/clang
        get_fresh_clang
      fi
    else
      update_old_clang
    fi
  else
    get_fresh_clang
  fi
}

# Fetch the sources for Cling
function fetch_cling {

  function get_fresh_cling {
    # ${CLING_GIT_URL} can be overridden. More information in README.md.
    CLING_GIT_URL=${CLING_GIT_URL:-"http://root.cern.ch/git/cling.git"}
    git clone ${CLING_GIT_URL} ${CLING_SRC_DIR}
    cd ${CLING_SRC_DIR}

    if [ ${1} = "last-stable" ]; then
      checkout_branch=$(git describe --match v* --abbrev=0 --tags | head -n 1)
    elif [ ${1} = "master" ]; then
      checkout_branch="master"
    else
      checkout_branch="${1}"
    fi

    git checkout ${checkout_branch}
  }

  function update_old_cling {
    git clean -f -x -d
    git fetch --tags

    if [ ${1} = "last-stable" ]; then
      checkout_branch=$(git describe --match v* --abbrev=0 --tags | head -n 1)
    elif [ ${1} = "master" ]; then
      checkout_branch="master"
    else
      checkout_branch="${1}"
    fi

    git checkout ${checkout_branch}
    git pull origin ${checkout_branch}
  }

  if [ -d ${CLING_SRC_DIR} ]; then
    cd ${CLING_SRC_DIR}
    if [ ! -z ${CLING_GIT_URL} ]; then
      grep -q ${CLING_GIT_URL} ${CLING_SRC_DIR}/.git/config
      if [ ${?} = 0 ]; then
        update_old_cling ${1}
      else
        cd ${srcdir}
        rm -Rf ${CLING_SRC_DIR}
        get_fresh_cling ${1}
      fi
    else
      update_old_cling ${1}
    fi
  else
    get_fresh_cling ${1}
  fi
}

function set_version {
  box_draw "Set Cling version"
  cd ${CLING_SRC_DIR}
  VERSION=$(cat ${CLING_SRC_DIR}/VERSION)

  # If development release, then add revision to the version
  REVISION=$(git log -n 1 --pretty=format:"%H")
  echo "${VERSION}" | grep -qE "dev"
  if [ "${?}" = 0 ]; then
    VERSION="${VERSION}"-"$(echo ${REVISION} | cut -c1-7)"
  fi
  echo "Version: ${VERSION}"
  if [ ${REVISION} != "" ]; then
    echo "Revision: ${REVISION}"
  fi
}

function set_ext {
  box_draw "Set binary/library extensions"
  if [ "${LLVM_OBJ_ROOT}" = "" ]; then
    LLVM_OBJ_ROOT=${workdir}/builddir
  fi

  if [ ! -f ${LLVM_OBJ_ROOT}/test/lit.site.cfg ]; then
    make -C ${LLVM_OBJ_ROOT}/test lit.site.cfg
  fi

  SHLIBEXT=$(grep "^config.llvm_shlib_ext = " ${LLVM_OBJ_ROOT}/test/lit.site.cfg | sed -e "s|config.llvm_shlib_ext = ||g" -e 's|"||g')
  EXEEXT=$(grep "^config.llvm_exe_ext = " ${LLVM_OBJ_ROOT}/test/lit.site.cfg | sed -e "s|config.llvm_exe_ext = ||g" -e 's|"||g')

  echo "EXEEXT: ${EXEEXT}"
  echo "SHLIBEXT: ${SHLIBEXT}"
}

function compile {
  prefix=${1}
  python=$(type -p python)
  # TODO: "nproc" program is a part of GNU Coreutils and may not be available on all systems. Use a better solution if needed.
  cores=$(nproc)

  # Cleanup previous installation directory if any
  rm -Rf ${prefix}
  mkdir -p ${workdir}/builddir
  cd ${workdir}/builddir

  if [ "${OS}" = "Cygwin" ]; then
    box_draw "Configuring Cling with CMake and generating Visual Studio 11 project files"
    cmake -G "Visual Studio 11" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$(cygpath --windows --absolute ${TMP_PREFIX}) ../$(basename ${srcdir})

    box_draw "Building Cling (using ${cores} cores)"
    cmake --build . --target clang --config Release
    cmake --build . --target cling --config Release

    box_draw "Install compiled binaries to prefix (using ${cores} cores)"
    cmake --build . --target INSTALL --config Release
  else
    box_draw "Configuring Cling for compilation"
    ${srcdir}/configure --disable-compiler-version-checks --with-python=${python} --enable-targets=host --prefix=${TMP_PREFIX} --enable-optimized=yes --enable-cxx11

    box_draw "Building Cling (using ${cores} cores)"
    make -j${cores}

    box_draw "Install compiled binaries to prefix (using ${cores} cores)"
    make install -j${cores} prefix=${TMP_PREFIX}
  fi
}

function install_prefix {

    set_ext
    box_draw "Filtering Cling's libraries and binaries"
    echo "This is going to take a while. Please wait."
    sed -i "s|@EXEEXT@|${EXEEXT}|g" ${HOST_CLING_SRC_DIR}/dist-files.mk
    sed -i "s|@SHLIBEXT@|${SHLIBEXT}|g" ${HOST_CLING_SRC_DIR}/dist-files.mk

    for f in $(find ${TMP_PREFIX} -type f -printf "%P\n"); do
      grep -q $(echo $f | sed "s|${TMP_PREFIX}||g")[[:space:]] ${HOST_CLING_SRC_DIR}/dist-files.mk
      if [ ${?} = 0 ]; then
        mkdir -p ${prefix}/$(dirname $f)
        cp ${TMP_PREFIX}/$f ${prefix}/$f
      fi
    done
}

function test_cling {
  box_draw "Run Cling test suite"
  if [ ${OS} != "Cygwin" ]; then
    cd ${workdir}/builddir/tools/cling
    make test
  fi
}

function tarball {
  box_draw "Compressing binaries to produce a bzip2 tarball"
  cd ${workdir}
  tar -cjvf $(basename ${prefix}).tar.bz2 -C . $(basename ${prefix})
}

function cleanup {
  # Newline is required to align boxes prooperly when SIGINT is encountered
  echo ""
  box_draw "Clean up"
  echo "Remove directory: ${workdir}/builddir"
  rm -Rf ${workdir}/builddir

  if [ -d "${prefix}" ]; then
    echo "Remove directory: ${prefix}"
    rm -Rf ${prefix}
  fi

  echo "Remove directory: ${TMP_PREFIX}"
  rm -Rf ${TMP_PREFIX}

  if [ "${VALUE}" = "deb" -o "${PARAM}" = "--deb-tag" ]; then
    echo "Create output directory: ${workdir}/cling-${VERSION}-1"
    mkdir -p ${workdir}/cling-${VERSION}-1

    if [ "$(ls -A ${workdir}/cling_${VERSION}* 2> /dev/null)" != "" ]; then
      echo "Moving Debian package files to ${workdir}/cling-${VERSION}-1"
      mv -v ${workdir}/cling_${VERSION}* ${workdir}/cling-${VERSION}-1
    fi

    if [ "$(ls -A ${workdir}/cling-${VERSION}-1 2> /dev/null)" = "" ]; then
      echo "Removing empty directory: ${workdir}/cling-${VERSION}-1"
      rm -Rf ${workdir}/cling-${VERSION}-1
    fi
  fi

  if [ -f "${workdir}/cling.nsi" ]; then
    echo "Remove file: cling.nsi"
    rm -Rf ${workdir}/cling.nsi
  fi

  # Reset trap on SIGEXIT, or else function "cleanup" will be executed twice.
  trap - EXIT
  exit
}

# Initialize variables with details of the platform and Operating System
platform_init
