#!/usr/bin/env bash
# ساخت کاربر جدید (یا تغییر رمز کاربر موجود)
# استفاده:
#   ./add-user.sh <username>              → رمز را تعاملی می‌پرسد
#   ./add-user.sh <username> <password>   → رمز را مستقیم می‌دهد (در history می‌ماند)
set -euo pipefail
cd "$(dirname "$0")"

say() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mخطا: %s\033[0m\n' "$*" >&2; exit 1; }

[ $# -ge 1 ] || die "نام کاربری را بدهید: ./add-user.sh <username>"
USERNAME="$1"
[ $# -ge 2 ] && PASSWORD="$2" || PASSWORD=""

case "$USERNAME" in
  *[!a-zA-Z0-9._-]*) die "نام کاربری فقط حروف انگلیسی، عدد، نقطه، خط تیره و زیرخط." ;;
esac

docker compose ps >/dev/null 2>&1 || die "سرویس بالا نیست. اول ./setup.sh را اجرا کنید."

# فقط یک پروسه می‌تواند به دیتابیس دست بزند
say "توقف موقت FileBrowser..."
docker compose stop filebrowser >/dev/null 2>&1 || true

restore() { docker compose start filebrowser >/dev/null 2>&1 || true; }
trap restore EXIT

run_cli() {
  docker compose run --rm --no-deps --entrypoint="" filebrowser \
    ./filebrowser user set "$USERNAME" --password "$1" -c /home/filebrowser/data/config.yaml
}

if [ -n "$PASSWORD" ]; then
  run_cli "$PASSWORD"
else
  docker compose run --rm --no-deps --entrypoint="" filebrowser \
    ./filebrowser user set "$USERNAME" --password -c /home/filebrowser/data/config.yaml
fi

say "کاربر «${USERNAME}» ساخته/به‌روز شد."

# پوشه‌ی شخصی بلافاصله ساخته می‌شود تا از همان اول در دسترس باشد
docker compose run --rm --no-deps --entrypoint="" filebrowser \
  sh -c "mkdir -p '/data/users/${USERNAME}' && chown -R 1000:1000 '/data/users/${USERNAME}'" || true

restore
trap - EXIT

cat <<EOF

کاربر آماده است. کاربر با این آدرس وارد شود: $(grep -E '^DOMAIN=' .env | cut -d= -f2-)
دسترسی‌ها:
  • «پوشه من»  → فقط فایل‌های خودش  (files/users/${USERNAME})
  • «مشترک»    → فایل‌های همه       (files/shared)
EOF
