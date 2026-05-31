#!/bin/sh
# Recreate SONAME symlinks as regular files on FAT32
# For each .so file, extract its SONAME and copy if missing
LIBDIR=/opt/lib

for f in "$LIBDIR"/*.so*; do
  [ -f "$f" ] || continue

  # Try to get SONAME via strings
  soname=$(strings "$f" 2>/dev/null | grep '^SONAME' | sed 's/SONAME//' | tr -d '[:space:]')
  [ -z "$soname" ] && continue

  # glibc-style libs: libc-2.27.so -> libc.so.6, libpthread-2.27.so -> libpthread.so.0
  # Regular libs: libfoo.so.X.Y.Z -> libfoo.so.X (SONAME)
  if [ "$soname" != "$(basename "$f")" ]; then
    target="$LIBDIR/$soname"
    if [ ! -e "$target" ]; then
      cp "$f" "$target"
      echo "Created: $soname"
    fi
  fi
done

# Also handle glibc pattern explicitly (libc-2.27.so -> libc.so.6, etc)
# These all have SONAME embedded, but let's also handle the common ones manually
# in case strings doesn't catch them
for f in "$LIBDIR"/*-2.27.so "$LIBDIR"/lib*-2.27.so; do
  [ -f "$f" ] || continue
  base=$(basename "$f" | sed 's/-2.27\.so//')  # e.g. libc -> libc.so.6
  case "$base" in
    libc)       t="libc.so.6" ;;
    libpthread) t="libpthread.so.0" ;;
    libm)       t="libm.so.6" ;;
    libdl)      t="libdl.so.2" ;;
    librt)      t="librt.so.1" ;;
    libresolv)  t="libresolv.so.2" ;;
    libutil)    t="libutil.so.1" ;;
    libnsl)     t="libnsl.so.1" ;;
    libnss_files) t="libnss_files.so.2" ;;
    libnss_dns) t="libnss_dns.so.2" ;;
    libanl)     t="libanl.so.1" ;;
    libcidn)    t="libcidn.so.1" ;;
    libcrypt)   t="libcrypt.so.1" ;;
    *)          continue ;;
  esac
  [ ! -e "$LIBDIR/$t" ] && cp "$f" "$LIBDIR/$t" && echo "Created: $t"
done

# For ncursesw, slang, event, etc with versioned SONAMEs
for f in "$LIBDIR"/libncursesw.so.* "$LIBDIR"/libslang.so.* "$LIBDIR"/libevent* "$LIBDIR"/libformw.so.* "$LIBDIR"/libmenuw.so.* "$LIBDIR"/libpanelw.so.*; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  # libncursesw.so.6.4 -> libncursesw.so.6
  soname=$(echo "$base" | sed -E 's/^((lib[^.]+\.so)\.([0-9]+))\.([0-9]+)$/\1/; t; s/^((lib[^.]+\.so)\.([0-9]+))(\.[0-9]+)+$/\1/')
  [ -z "$soname" ] && continue
  [ "$soname" = "$base" ] && continue
  [ ! -e "$LIBDIR/$soname" ] && cp "$f" "$LIBDIR/$soname" && echo "Created: $soname"
done

echo "Done. Listing /opt/lib/*.so*"
ls "$LIBDIR"/*.so*
