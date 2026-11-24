#!/usr/bin/env bash
# راه‌اندازی اولیه: ساخت .env، آماده‌سازی پوشه‌ها، گرفتن گواهی SSL و بالا آوردن سرویس
set -euo pipefail
cd "$(dirname "$0")"

say() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mخطا: %s\033[0m\n' "$*" >&2; exit 1; }

# ---------- 1) پیش‌نیازها ----------
command -v docker >/dev/null 2>&1 || die "Docker نصب نیست. راهنما: https://docs.docker.com/engine/install/"
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 نصب نیست (پلاگین compose)."

# ---------- 2) فایل .env ----------
if [ ! -f .env ]; then
  cp .env.example .env
  say "فایل .env ساخته شد. مقادیر DOMAIN و ACME_EMAIL و ADMIN_PASSWORD را داخل آن پر کنید و این اسکریپت را دوباره اجرا کنید:"
  echo "    nano .env"
  exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

[ -n "${DOMAIN:-}" ] || die "DOMAIN در .env خالی است."
[ -n "${ACME_EMAIL:-}" ] || die "ACME_EMAIL در .env خالی است."
[ -n "${ADMIN_PASSWORD:-}" ] || die "ADMIN_PASSWORD در .env خالی است."

case "$DOMAIN" in
  files.example.com|example.com|"") die "مقدار DOMAIN را در .env عوض کنید (فعلاً نمونه است)." ;;
esac
case "$ACME_EMAIL" in
  you@example.com|"") die "مقدار ACME_EMAIL را در .env عوض کنید." ;;
esac
case "$ADMIN_PASSWORD" in
  change-me-strong-password|admin) die "یک رمز ادمین قوی در .env بگذارید." ;;
esac
[ "${#ADMIN_PASSWORD}" -ge 12 ] || die "رمز ادمین باید حداقل ۱۲ کاراکتر باشد."

# ---------- 3) ساخت پوشه‌ها ----------
mkdir -p data files/users files/shared
[ -f data/config.yaml ] || die "data/config.yaml پیدا نشد. بسته را کامل کپی کنید."

# ---------- 4) مقداردهی دامنه و کلید JWT ----------
if grep -q '^  externalUrl:' data/config.yaml; then
  sed -i.bak "s|^  externalUrl: .*|  externalUrl: \"https://${DOMAIN}\"|" data/config.yaml && rm -f data/config.yaml.bak
  say "دامنه در data/config.yaml تنظیم شد: https://${DOMAIN}"
fi

chmod 600 .env || true

if grep -q '^JWT_SECRET=__GENERATE__' .env; then
  secret="$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  sed -i.bak "s|^JWT_SECRET=.*|JWT_SECRET=${secret}|" .env && rm -f .env.bak
  say "کلید JWT ساخته شد (با ری‌استارت شدن سرور، کاربران از حساب خارج نمی‌شوند)."
fi

# ---------- 5) مالکیت فایل‌ها (کانتینر با UID 1000 اجرا می‌شود) ----------
if [ "$(id -u)" -eq 0 ]; then
  chown -R 1000:1000 data files
else
  command -v sudo >/dev/null 2>&1 || die "برای تنظیم مالکیت پوشه‌ها به sudo نیاز است."
  sudo chown -R 1000:1000 data files
fi

# ---------- 6) هشدار پورت ----------
for p in 80 443; do
  if command -v ss >/dev/null 2>&1 && ss -ltn "( sport = :$p )" 2>/dev/null | grep -q LISTEN; then
    say "هشدار: پورت $p همین حالا اشغال است (nginx/apache؟). قبل از ادامه آن را متوقف کنید."
  fi
done

# ---------- 7) اجرا ----------
say "دریافت ایمیج‌ها..."
docker compose pull

say "بالا آوردن سرویس‌ها..."
docker compose up -d

say "وضعیت:"
docker compose ps

cat <<EOF

──────────────────────────────────────────────
آدرس پنل:      https://${DOMAIN}
کاربر ادمین:   admin
رمز ادمین:     همان ADMIN_PASSWORD در فایل .env

نکته‌ها:
 • اولین بار ۳۰ تا ۹۰ ثانیه طول می‌کشد تا Caddy گواهی SSL بگیرد.
   اگر خطا دیدید:  docker compose logs -f caddy
 • ساخت کاربر جدید:  ./add-user.sh ali
 • اگر سرور پشت NAT است، پورت‌های 80 و 443 باید به آن فوروارد شوند.
 • چک‌لیست امنیتی و بقیه‌ی کارها در README.fa.md
──────────────────────────────────────────────
EOF
