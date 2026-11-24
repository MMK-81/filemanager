#!/usr/bin/env bash
# پشتیبان‌گیری از تنظیمات، دیتابیس و پوشه‌ی مشترک
set -euo pipefail
cd "$(dirname "$0")"

STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups

say() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }

# دیتابیس SQLite باید در حالت بسته کپی شود
say "توقف موقت FileBrowser برای بکاپ سالم..."
docker compose stop filebrowser >/dev/null 2>&1 || true

tar -czf "backups/data-${STAMP}.tar.gz" --exclude='data/tmp' data
say "تنظیمات و دیتابیس: backups/data-${STAMP}.tar.gz"

docker compose start filebrowser >/dev/null 2>&1 || true

# فایل‌های کاربران سنگین‌اند؛ با rsync (قابل ادامه) بکاپ بگیرید
cat <<EOF

برای فایل‌های خود کاربران (حجیم)، از rsync استفاده کنید:
  rsync -a --delete files/ /مسیر/بکاپ/دور/بررسی/

ری‌استور:
  docker compose down
  tar -xzf backups/data-${STAMP}.tar.gz
  sudo chown -R 1000:1000 data files
  docker compose up -d
EOF
