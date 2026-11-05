#!/bin/bash

# Change this value to switch all project-owned repositories to another owner.
Z4R_GITHUB_OWNER="${Z4R_GITHUB_OWNER:-serogaq}"

Z4R_PROJECT_REPO="${Z4R_PROJECT_REPO:-zapret4rocket}"
Z4R_PROJECT_REF="${Z4R_PROJECT_REF:-master}"
Z4R_LAUNCHER_REPO="${Z4R_LAUNCHER_REPO:-z4r}"
Z4R_LAUNCHER_REF="${Z4R_LAUNCHER_REF:-main}"
Z4R_MIRROR_HOST="${Z4R_MIRROR_HOST:-http://mizulina.shit.vc:666}"

Z4R_PROJECT_SLUG="$Z4R_GITHUB_OWNER/$Z4R_PROJECT_REPO"
Z4R_LAUNCHER_SLUG="$Z4R_GITHUB_OWNER/$Z4R_LAUNCHER_REPO"
Z4R_RAW_BASE="https://raw.githubusercontent.com/$Z4R_PROJECT_SLUG/$Z4R_PROJECT_REF"
Z4R_API_BASE="https://api.github.com/repos/$Z4R_PROJECT_SLUG"
Z4R_GITHUB_BASE="https://github.com/$Z4R_PROJECT_SLUG"
Z4R_MIRROR_BASE="$Z4R_MIRROR_HOST/$Z4R_PROJECT_SLUG/$Z4R_PROJECT_REF"
Z4R_LAUNCHER_RAW_BASE="https://raw.githubusercontent.com/$Z4R_LAUNCHER_SLUG/$Z4R_LAUNCHER_REF"
Z4R_LAUNCHER_MIRROR_BASE="$Z4R_MIRROR_HOST/$Z4R_LAUNCHER_SLUG/$Z4R_LAUNCHER_REF"

z4r_repo_url() {
  printf '%s/%s\n' "$Z4R_RAW_BASE" "$1"
}

z4r_api_url() {
  printf '%s/%s\n' "$Z4R_API_BASE" "$1"
}

download_z4r_file() {
  local path="$1"
  local destination="$2"
  local max_time="${3:-}"

  if [ -n "$max_time" ]; then
    curl --connect-timeout 5 --max-time "$max_time" -fL -o "$destination" "$Z4R_RAW_BASE/$path" ||
      curl --max-time "$max_time" -fL -o "$destination" "$Z4R_MIRROR_BASE/$path"
  else
    curl --connect-timeout 5 -fL -o "$destination" "$Z4R_RAW_BASE/$path" ||
      curl -fL -o "$destination" "$Z4R_MIRROR_BASE/$path"
  fi
}

stream_z4r_file() {
  local path="$1"

  curl --connect-timeout 5 -fsL "$Z4R_RAW_BASE/$path" ||
    curl -fsL "$Z4R_MIRROR_BASE/$path"
}

download_z4r_launcher_file() {
  local path="${1:-z4r}"
  local destination="$2"

  if command -v curl >/dev/null 2>&1; then
    curl --connect-timeout 5 -fL -o "$destination" "$Z4R_LAUNCHER_RAW_BASE/$path" ||
      curl -fL -o "$destination" "$Z4R_LAUNCHER_MIRROR_BASE/$path"
  elif command -v wget >/dev/null 2>&1; then
    wget --timeout=5 -qO "$destination" "$Z4R_LAUNCHER_RAW_BASE/$path" ||
      wget -qO "$destination" "$Z4R_LAUNCHER_MIRROR_BASE/$path"
  else
    echo "Ошибка: нет curl или wget для загрузки внешнего z4r." >&2
    return 1
  fi
}
