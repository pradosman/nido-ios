#!/bin/bash

normalize_create_directory() {
  local directory="$1"
  if [[ -z "$directory" ]]; then
    printf '%s\n' 'Directory path must not be empty.' >&2
    return 2
  fi
  mkdir -p "$directory" || return 1
  (cd "$directory" && pwd -P)
}

verify_owned_container() {
  local owner_label
  if ! owner_label="$(docker inspect -f "{{ index .Config.Labels \"$CONTAINER_LABEL_KEY\" }}" "$CONTAINER_NAME" 2>/dev/null)"; then
    printf 'Could not verify ownership of container: %s\n' "$CONTAINER_NAME" >&2
    return 1
  fi
  if [[ "$owner_label" != "$CONTAINER_LABEL_VALUE" ]]; then
    printf 'Refusing to remove container without our ownership label: %s\n' "$CONTAINER_NAME" >&2
    return 1
  fi
}

remove_owned_container() {
  verify_owned_container || return 1
  if ! docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1; then
    printf 'The owned container could not be removed: %s\n' "$CONTAINER_NAME" >&2
    return 1
  fi
}
