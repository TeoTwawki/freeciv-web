#!/usr/bin/env bash

# Freeciv server version upgrade notes (backports)
# ------------------------------------------------
# osdn #????? or RM #??? is a ticket in freeciv.org tracker:
# https://osdn.net/projects/freeciv/ticket/?????
# https://redmine.freeciv.org/issues/???
#
# 0048-Handle-CoastStrict-units-correctly-on-city-removal.patch
#   Fix to unit placement after city destruction
#   RM #525
# 0061-savegame-Correct-loading-last-turn-change-time.patch
#   Savegame loading fix
#   RM #545
# 0073-savecompat-Fix-adding-ACTION_NONE-actions-for-units-.patch
#   Savegame loading fix
#   RM #577
# 0089-Meson-Make-fc_client_common-to-depend-on-verhdr.patch
#   Build fix
#   RM #596
# 0080-savegame-Save-ACTION_NONE-as-1.patch
#   Savegame loading fix
#   RM #598
# 0068-Meson-Make-libfreeciv-to-depend-on-gitrev.patch
#   Build fix
#   RM #597
# 0074-Meson-Make-fc_server-to-depend-on-verhdr.patch
#   Build fix
#   RM #682
# 0077-city_freeze_workers_queue-Set-needs_arrange-for-citi.patch
#   City status legality fix
#   RM #661
# 0068-AI-Remove-shared-vision-from-pending-war-target-once.patch
#   AI assert fix
#   RM #701
# 0038-map_init_topology-Operate-on-any-map.patch
#   Dependency of 0030-Tex-Initialize-map-topology.patch
#   RM #707
# 0030-Tex-Initialize-map-topology.patch
#   Tex AI map topology fix
#   RM #663

# Not in the upstream Freeciv server
# ----------------------------------
# RevertAmplio2ExtraUnits.patch Revert freeciv-web breaking changes from amplio2 extra_units.spec
# meson_webperimental installs webperimental ruleset
# tutorial_ruleset changes the ruleset of the tutorial to one supported by Freeciv-web.
#      - This should be replaced by modification of the tutorial scenario that allows it to
#        work with multiple rulesets (Requires patch #7362 / SVN r33159)
# webgl_vision_cheat_temporary is a temporary solution to reveal terrain types to the WebGL client.
# longturn implements a very basic longturn mode for Freeciv-web.
# load_command_confirmation adds a log message which confirms that loading is complete, so that Freeciv-web can issue additional commands.
# endgame-mapimg is used to generate a mapimg at endgame for hall of fame.

# Local patches
# -------------
# Finally patches from patches/local are applied. These can be used
# to easily apply a temporary debug change that's not meant ever to get
# included to the repository.

declare -a GIT_PATCHLIST=(
)

declare -a PATCHLIST=(
  "backports/0048-Handle-CoastStrict-units-correctly-on-city-removal"
  "backports/0061-savegame-Correct-loading-last-turn-change-time"
  "backports/0073-savecompat-Fix-adding-ACTION_NONE-actions-for-units-"
  "backports/0089-Meson-Make-fc_client_common-to-depend-on-verhdr"
  "backports/0080-savegame-Save-ACTION_NONE-as-1"
  "backports/0068-Meson-Make-libfreeciv-to-depend-on-gitrev"
  "backports/0074-Meson-Make-fc_server-to-depend-on-verhdr"
  "backports/0077-city_freeze_workers_queue-Set-needs_arrange-for-citi"
  "backports/0068-AI-Remove-shared-vision-from-pending-war-target-once"
  "backports/0038-map_init_topology-Operate-on-any-map"
  "backports/0030-Tex-Initialize-map-topology"
  "RevertAmplio2ExtraUnits"
  "meson_webperimental"
  "metachange"
  "text_fixes"
  "freeciv-svn-webclient-changes"
  "goto_fcweb"
  "tutorial_ruleset"
  "savegame"
  "maphand_ch"
  "server_password"
  "scorelog_filenames"
  "longturn"
  "load_command_confirmation"
  "webgl_vision_cheat_temporary"
  "endgame-mapimg"
  $(ls -1 patches/local/*.patch 2>/dev/null | sed -e 's,patches/,,' -e 's,\.patch,,' | sort)
)

apply_git_patch() {
  echo "*** Applying $1.patch ***"
  if ! git -C freeciv apply ../patches/$1.patch ; then
    echo "APPLYING PATCH $1.patch FAILED!"
    return 1
  fi
  echo "=== $1.patch applied ==="
}

apply_patch() {
  echo "*** Applying $1.patch ***"
  if ! patch -u -p1 -d freeciv < patches/$1.patch ; then
    echo "APPLYING PATCH $1.patch FAILED!"
    return 1
  fi
  echo "=== $1.patch applied ==="
}

# APPLY_UNTIL feature is used when rebasing the patches, and the working directory
# is needed to get to correct patch level easily.
if test "$1" != "" ; then
  APPLY_UNTIL="$1"
  au_found=false

  for patch in "${GIT_PATCHLIST[@]} ${PATCHLIST[@]}"
  do
    if test "$patch" = "$APPLY_UNTIL" ; then
      au_found=true
      APPLY_UNTIL="${APPLY_UNTIL}.patch"
    elif test "${patch}.patch" = "$APPLY_UNTIL" ; then
      au_found=true
    fi
  done
  if test "$au_found" != "true" ; then
    echo "There's no such patch as \"$APPLY_UNTIL\"" >&2
    exit 1
  fi
else
  APPLY_UNTIL=""
fi

. ./version.txt

CAPSTR_EXPECT="NETWORK_CAPSTRING=\"${ORIGCAPSTR}\""
CAPSTR_SRC="freeciv/fc_version"
echo "Verifying ${CAPSTR_EXPECT}"

if ! grep "$CAPSTR_EXPECT" ${CAPSTR_SRC} 2>/dev/null >/dev/null ; then
  echo "   Found  $(grep 'NETWORK_CAPSTRING=' ${CAPSTR_SRC}) in $(pwd)/freeciv/fc_version" >&2
  echo "Capstring to be replaced does not match that given in version.txt" >&2
  exit 1
fi

sed "s/${ORIGCAPSTR}/${WEBCAPSTR}/" freeciv/fc_version > freeciv/fc_version.tmp
mv freeciv/fc_version.tmp freeciv/fc_version
chmod a+x freeciv/fc_version

if test "$GIT_PATCHING" = "yes" ; then
  for patch in "${GIT_PATCHLIST[@]}"
  do
    if test "${patch}.patch" = "$APPLY_UNTIL" ; then
      echo "$patch not applied as requested to stop"
      break
    fi
    if ! apply_git_patch $patch ; then
      echo "Patching failed ($patch.patch)" >&2
      exit 1
    fi
  done
elif test "${GIT_PATCHLIST[0]}" != "" ; then
  echo "Git patches defined, but git patching is not enabled" >&2
  exit 1
fi

for patch in "${PATCHLIST[@]}"
do
  if test "${patch}.patch" = "$APPLY_UNTIL" ; then
    echo "$patch not applied as requested to stop"
    break
  fi
  if ! apply_patch $patch ; then
    echo "Patching failed ($patch.patch)" >&2
    exit 1
  fi
done
