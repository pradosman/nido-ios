#!/bin/sh

set -eu

output_path=${1:?"Output plist path is required"}
repository_path=${2:-.}
revision=""
dirty=false

if command -v git >/dev/null 2>&1; then
    candidate=$(git -C "$repository_path" rev-parse --short=7 HEAD 2>/dev/null || true)
    case "$candidate" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
            revision=$candidate
            if ! git -C "$repository_path" diff --quiet --ignore-submodules -- \
                || ! git -C "$repository_path" diff --cached --quiet --ignore-submodules --; then
                dirty=true
            fi
            ;;
    esac
fi

mkdir -p "$(dirname "$output_path")"
temporary_path="${output_path}.tmp"
trap 'rm -f "$temporary_path"' EXIT HUP INT TERM

if [ -n "$revision" ]; then
    cat > "$temporary_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GitRevision</key>
    <string>$revision</string>
    <key>GitDirty</key>
    <$dirty/>
</dict>
</plist>
EOF
else
    cat > "$temporary_path" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
EOF
fi

mv "$temporary_path" "$output_path"
trap - EXIT HUP INT TERM
