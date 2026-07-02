#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -q -- "$pattern" "$file" || fail "$message"
}

assert_text_contains() {
  local text="$1"
  local pattern="$2"
  local message="$3"

  echo "$text" | grep -q -- "$pattern" || fail "$message"
}

assert_text_not_contains() {
  local text="$1"
  local pattern="$2"
  local message="$3"

  ! echo "$text" | grep -q -- "$pattern" || fail "$message"
}

TMP_DIR="$(mktemp -d /tmp/z2r-profile-lock.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

export Z2R_ROOT="$TMP_DIR/zapret2"
export Z2R_CONFIG="$Z2R_ROOT/config"
export Z2R_PROFILE_STATE_FILE="$TMP_DIR/profile.lock"

mkdir -p "$Z2R_ROOT/extra_strats" "$Z2R_ROOT/init.d/sysv/custom.d"
sed "s#/opt/zapret2#$Z2R_ROOT#g" "$REPO_DIR/config.default" > "$Z2R_CONFIG"

printf 'youtube.com\n' > "$Z2R_ROOT/extra_strats/TCP_YT_list.txt"
printf 'meduza.io\n' > "$Z2R_ROOT/extra_strats/TCP_RKN_list.txt"
printf 'youtube.com\n' > "$Z2R_ROOT/extra_strats/UDP_YT_list.txt"
printf 'script\n' > "$Z2R_ROOT/init.d/sysv/custom.d/50-stun4all"
printf 'script\n' > "$Z2R_ROOT/init.d/sysv/custom.d/50-discord-media"
discord_line_before="$(grep -- "discord.txt" "$Z2R_CONFIG" | head -n1)"

# shellcheck source=/dev/null
source "$REPO_DIR/lib/config_mutation.sh"
# shellcheck source=/dev/null
source "$REPO_DIR/lib/profile_lock.sh"

bash -n \
  "$REPO_DIR/z2r.sh" \
  "$REPO_DIR/lib/config_mutation.sh" \
  "$REPO_DIR/lib/profile_lock.sh" \
  "$REPO_DIR/lib/strategies.sh" \
  "$REPO_DIR/lib/submenus.sh" \
  "$REPO_DIR/lib/actions.sh"

[ "$(profile_lock_get YT_UDP)" = "auto" ] || fail "missing lock must be auto"

profile_lock_set YT_UDP skip
[ "$(profile_lock_get YT_UDP)" = "skip" ] || fail "YT_UDP skip was not stored"
assert_file_contains "$Z2R_PROFILE_STATE_FILE" "^YT_UDP[[:space:]][[:space:]]*skip$" "YT_UDP skip row is missing"
profile_apply_all "$Z2R_CONFIG"

yt_udp_count="$(grep -c -- "--skip --filter-udp=443 --hostlist=$Z2R_ROOT/extra_strats/UDP_YT_list.txt" "$Z2R_CONFIG")"
[ "$yt_udp_count" = "1" ] || fail "YT_UDP skip count is $yt_udp_count"

sum_before="$(sha256sum "$Z2R_CONFIG" | cut -d' ' -f1)"
profile_apply_all "$Z2R_CONFIG"
sum_after="$(sha256sum "$Z2R_CONFIG" | cut -d' ' -f1)"
[ "$sum_before" = "$sum_after" ] || fail "profile_apply_all is not idempotent"

profile_lock_set RKN skip
profile_apply_all "$Z2R_CONFIG"
tcp_line="$(grep -- "--qnum 300 --filter-tcp=80,443" "$Z2R_CONFIG" | head -n1)"
assert_text_contains "$tcp_line" "TCP_YT_list.txt" "YT hostlist was removed while skipping RKN"
assert_text_not_contains "$tcp_line" "TCP_RKN_list.txt" "RKN hostlist is still present"

profile_lock_set YT_TCP skip
profile_apply_all "$Z2R_CONFIG"
tcp_line="$(grep -- "--qnum 300 --filter-tcp=80,443" "$Z2R_CONFIG" | head -n1)"
assert_text_contains "$tcp_line" "^--skip .*--filter-tcp" "TCP line is not skipped after all hostlists are removed"

profile_lock_set RKN 2
[ "$(profile_lock_get RKN)" = "2" ] || fail "RKN strategy lock was not stored"
assert_file_contains "$Z2R_PROFILE_STATE_FILE" "^RKN[[:space:]][[:space:]]*2$" "RKN strategy row is missing"
profile_apply_all "$Z2R_CONFIG"
tcp_line="$(grep -- "--qnum 300 --filter-tcp=80,443" "$Z2R_CONFIG" | head -n1)"
assert_text_contains "$tcp_line" "TCP_RKN_list.txt" "RKN hostlist was not restored"
[ -s "$Z2R_ROOT/extra_strats/TCP/RKN/2.txt" ] || fail "RKN strategy file was not restored"

discord_line="$(grep -- "discord.txt" "$Z2R_CONFIG" | head -n1)"
assert_text_not_contains "$discord_line" "TCP_RKN_list.txt\\|TCP_YT_list.txt" "Discord line was polluted: $discord_line"
[ "$discord_line" = "$discord_line_before" ] || fail "Discord line changed: $discord_line"

profile_lock_set VOICE_UDP skip
profile_apply_all "$Z2R_CONFIG"
assert_file_contains "$Z2R_CONFIG" "--skip --filter-udp=50000-50099,1400,3478-3481,5349,19294-19344" "VOICE line was not skipped"
voice_ports_line="$(grep "^NFQWS2_PORTS_UDP=" "$Z2R_CONFIG")"
assert_text_not_contains "$voice_ports_line" "50000-50099" "VOICE ports are still present"
[ -f "$Z2R_ROOT/init.d/sysv/custom.d.disabled/50-stun4all" ] || fail "50-stun4all was not disabled"
[ -f "$Z2R_ROOT/init.d/sysv/custom.d.disabled/50-discord-media" ] || fail "50-discord-media was not disabled"

profile_lock_clear VOICE_UDP
[ "$(profile_lock_get VOICE_UDP)" = "auto" ] || fail "VOICE_UDP lock was not cleared"
assert_text_not_contains "$(cat "$Z2R_PROFILE_STATE_FILE")" "^VOICE_UDP[[:space:]]" "VOICE_UDP row is still stored"
profile_apply_voice_auto "$Z2R_CONFIG"
assert_file_contains "$Z2R_CONFIG" "^--filter-udp=50000-50099,1400,3478-3481,5349,19294-19344" "VOICE line was not restored"
[ -f "$Z2R_ROOT/init.d/sysv/custom.d/50-stun4all" ] || fail "50-stun4all was not restored"
[ -f "$Z2R_ROOT/init.d/sysv/custom.d/50-discord-media" ] || fail "50-discord-media was not restored"

printf 'YT_UDP\t99\n' > "$Z2R_PROFILE_STATE_FILE"
profile_apply_all "$Z2R_CONFIG" >/dev/null

echo "profile_lock smoke ok"
