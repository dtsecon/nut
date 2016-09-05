#!/bin/sh

# This script lists existing NUT *-mib.c sources with legacy MIB-mapping
# structures into a "legacy-mibfiles-list.inc" to be included by Makefile.
# It also generates the rule snippets to convert such files from C to DMF
# in a (hopefully) portable manner across different Make implementations.
# It expects to be located in (executed from) $NUT_SOURCEDIR/scripts/DMF
# of the real (e.g. not out-of-tree) NUT codebase, before configure is run.
# Be portable - no bash etc... plain minimal shell. Tested with bash, dash,
# busybox sh and ksh for good measure.
#
#   Copyright (C) 2016 Jim Klimov <EvgenyKlimov@eaton.com>
#

# Relative to here we look for old sources
_SCRIPT_DIR="`cd $(dirname "$0") && pwd`" || \
    _SCRIPT_DIR="./" # Fallback can fail

# Note that technically it is not required that this is an ".in" template
# as the data is currently static. However, it helps streamline out-of-tree
# builds (e.g. distcheck) using the powers of automake/configure scriptware.
OUTFILE=legacy-mibfiles-list.mk.in

[ -z "${DEBUG-}" ] && DEBUG=no

cd "$_SCRIPT_DIR" || exit

list_LEGACY_NUT_C_MIBS() {
    i=0
    for cmib in ../../drivers/*-mib.c; do
        [ -s "${cmib}" ] || \
            { [ "$DEBUG" = yes ] && echo "WARN: File not found or is empty: '${cmib}'" >&2; continue; }
        echo "`basename ${cmib}`"
        i="`expr $i + 1`"
    done
    [ "$i" = 0 ] && echo "ERROR: No files found" >&2 && return 2
    [ "$DEBUG" = yes ] && echo "INFO: Found $i files OK" >&2
    return 0
}

LEGACY_NUT_C_MIBS_LIST=""
sort_LEGACY_NUT_C_MIBS() {
    [ -n "${LEGACY_NUT_C_MIBS_LIST}" ] || \
        { LEGACY_NUT_C_MIBS_LIST="`list_LEGACY_NUT_C_MIBS`" && \
          LEGACY_NUT_C_MIBS_LIST="`echo "$LEGACY_NUT_C_MIBS_LIST" | sort | uniq`"; } \
        || return $?
    [ -n "${LEGACY_NUT_C_MIBS_LIST}" ] || return $?
    echo "$LEGACY_NUT_C_MIBS_LIST"
}

print_makefile_LEGACY_NUT_C_MIBS() {
    printf "LEGACY_NUT_C_MIBS ="
    for F in `sort_LEGACY_NUT_C_MIBS` ; do
        printf ' \\\n\t%s' "$F"
    done || return
    echo ""
    echo ""
    return 0
}

print_makefile_LEGACY_NUT_DMFS() {
    echo "# NOTE: DMFSNMP_SUBDIR is defined in Makefile.am"
    printf "LEGACY_NUT_DMFS ="
    for F in `sort_LEGACY_NUT_C_MIBS` ; do
        printf ' \\\n\t$(DMFSNMP_SUBDIR)/%s' "`basename "$F" .c`".dmf
    done || return
    echo ""
    echo ""
    return 0
}

print_makefile_LEGACY_NUT_DMF_SYMLINKS() {
    echo "# NOTE: DMFSNMP_SUBDIR is defined in Makefile.am"
    printf "LEGACY_NUT_DMF_SYMLINKS ="
    for F in `sort_LEGACY_NUT_C_MIBS` ; do
        case "$F" in
            *ietf-mib.c*) DMF_PREFIX="S90_" ;;
            *) DMF_PREFIX="S10_" ;;
        esac
        printf ' \\\n\t$(DMFSNMP_SUBDIR)/%s' "${DMF_PREFIX}`basename "$F" .c`".dmf
    done || return
    echo ""
    echo ""
    return 0
}

print_makefile_LEGACY_NUT_DMF_DEPS() {
    echo "# NOTE: DMFSNMP_SUBDIR, DMFGEN_DEPS and DMFGEN_CMD is defined in Makefile.am"
    for F in `sort_LEGACY_NUT_C_MIBS` ; do
        printf '$(DMFSNMP_SUBDIR)/%s : $(abs_top_srcdir)/drivers/%s $(DMFGEN_DEPS)\n\t@$(DMFGEN_CMD)\n\n' "`basename "$F" .c`".dmf "$F"
    done || return
    echo ""
    return 0
}

print_makefile() {
    echo "### This file was automatically generated at `TZ=UTC date`"
    sort_LEGACY_NUT_C_MIBS > /dev/null || return $? # prepare cache
    print_makefile_LEGACY_NUT_C_MIBS && \
    print_makefile_LEGACY_NUT_DMFS && \
    print_makefile_LEGACY_NUT_DMF_SYMLINKS && \
    print_makefile_LEGACY_NUT_DMF_DEPS
}

rm -f "$OUTFILE"
OUTTEXT="`print_makefile`" || { RES=$?; echo "FAILED to generate $OUTFILE content" >&2; rm -f "$OUTFILE"; exit $RES; }
echo "$OUTTEXT" > "$OUTFILE" || { RES=$?; echo "FAILED to generate $OUTFILE" >&2; rm -f "$OUTFILE"; exit $RES; }

echo "OK - Generated $OUTFILE" >&2
exit 0
