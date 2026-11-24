# فایل‌منیجر تیمی روی سرور

**FileBrowser Quantum + Caddy** — یک پنل وب سبک برای آپلود، دانلود، مدیریت و اشتراک‌گذاری فایل، با اکانت جداگانه برای هر نفر، پوشه‌ی شخصی و پوشه‌ی مشترک، و HTTPS خودکار.

| نیاز شما | این بسته |
|---|---|
| آپلود فایل از مرورگر | ✅ آپلود تکی/گروهی، Drag & Drop، آپلود پوشه |
| اشتراک‌گذاری | ✅ لینک عمومی با رمز، تاریخ انقضا و تعیین سطح دسترسی |
| همه فایل‌ها یک‌جا | ✅ دو فضای کنار هم: «پوشه من» و «مشترک» |
| اکانت جدا برای هر نفر | ✅ کاربر و رمز مجزا، ادمین برای مدیریت |
| دسترسی از اینترنت | ✅ دامنه + گواهی SSL رایگان (Let's Encrypt) |
| پیش‌نمایش و ویرایش | ✅ عکس، ویدیو، PDF، فایل آفیس، ویرایش فایل متنی |
| اتصال به‌عنوان درایو شبکه | ✅ WebDAV |

> اگر بعداً Sync خودکار بین دستگاه‌ها، تقویم و تماس، یا ویرایش آنلاین گروهی خواستید، Nextcloud گزینه‌ی بعدی است (سنگین‌تر: دیتابیس + حداقل ۲ گیگ رم). برای «فایل‌منیجر تیمی» همین بسته کافی و بسیار سبک‌تر است.

---

## ۱. پیش‌نیازها

روی سرور لینوکس (Ubuntu/Debian):

```bash
# Docker + Compose plugin
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"   # بعد از این یک‌بار logout/login کنید
docker compose version            # باید نسخه ۲ را نشان دهد
```

- **دامنه:** یک رکورد `A` بسازید که `files.example.com` را به IP عمومی سرور وصل کند.
  بررسی: `dig +short files.example.com` باید IP سرور را بدهد.
- **پورت‌ها:** `80` و `443` در فایروال و (اگر پشت NAT هستید) در روتر به سرور فوروارد شوند.
  ```bash
  sudo ufw allow 80,443/tcp
  ```
- **منابع:** ۵۱۲ مگ رم کافی است؛ فضا به حجم فایل‌ها بستگی دارد.

---

## ۲. نصب در سه گام

کل پوشه‌ی `filemanager` را روی سرور کپی کنید (مثلاً به `/opt/filemanager`):

```bash
scp -r filemanager user@SERVER_IP:/tmp/
ssh user@SERVER_IP
sudo mv /tmp/filemanager /opt/filemanager
cd /opt/filemanager
```

**گام ۱ — تنظیمات:**

```bash
cp .env.example .env
nano .env
```

```ini
DOMAIN=files.example.com          # دامنه‌ی خودتان
ACME_EMAIL=you@example.com        # ایمیل شما برای گواهی SSL
ADMIN_PASSWORD=ChangeMe-Strong-2026   # حداقل ۱۲ کاراکتر، بدون فاصله و #
```

**گام ۲ — اجرا:**

```bash
chmod +x *.sh
./setup.sh
```

اسکریپت این کارها را انجام می‌دهد: ساخت پوشه‌ها، تنظیم مالکیت فایل‌ها برای کانتینر (UID 1000)، نوشتن دامنه در `data/config.yaml`، ساخت کلید JWT، گرفتن ایمیج‌ها و بالا آوردن سرویس.

> اگر با خطای `bad interpreter` مواجه شدید (فایل‌ها با ویندوز کپی شده‌اند):
> `sed -i 's/\r$//' *.sh`

**گام ۳ — اولین ورود:**

آدرس `https://files.example.com` را باز کنید. اولین بار ۳۰ تا ۹۰ ثانیه طول می‌کشد تا Caddy گواهی SSL بگیرد.

| | |
|---|---|
| کاربر | `admin` |
| رمز | همان `ADMIN_PASSWORD` در `.env` |

بعد از ورود، از منوی کاربری می‌توانید رمز را عوض کنید؛ ولی تا وقتی `ADMIN_PASSWORD` در `.env` هست، با هر ری‌استارت همان رمز قبلی برمی‌گردد. بعد از اینکه مطمئن شدید همه‌چیز کار می‌کند، اگر می‌خواهید رمز از پنل مدیریت شود:

```bash
nano .env                 # خط ADMIN_PASSWORD=... را پاک یا کامنت کنید
nano docker-compose.yml   # خط FILEBROWSER_ADMIN_PASSWORD را هم کامنت کنید
docker compose up -d --force-recreate
```

از این به بعد رمزی که در پنل عوض می‌کنید پایدار می‌ماند (کاربر admin از قبل در دیتابیس هست، پس رمز تصادفی جدید ساخته نمی‌شود).

---

## ۳. ساخت کاربر برای هر نفر

```bash
./add-user.sh ali
# رمز را تعاملی می‌پرسد. یا:
./add-user.sh ali 'Ramz-e-Ghovi-123'
```

پوشه‌ی `files/users/ali` ساخته می‌شود و کاربر با دو فضا وارد می‌شود:

| فضای کاربر | مسیر روی سرور | چه کسی می‌بیند |
|---|---|---|
| **پوشه من** | `files/users/<username>` | فقط خودش |
| **مشترک** | `files/shared` | همه‌ی کاربران |

مدیریت از پنل هم ممکن است: **Settings → User management → Add user**. هنگام ساخت، رمز، ادمین بودن و sourceهای هر کاربر را می‌توانید تعیین کنید.

> کاربری که قبل از اضافه‌شدن پوشه‌ی «مشترک» ساخته شده، با یک‌بار ری‌استارت (`docker compose restart filebrowser`) آن را می‌گیرد.

**کاربر ادمین چه می‌بیند؟** ادمین هم مثل بقیه «مشترک» و پوشه‌ی خودش را می‌بیند. برای دیدن همه‌ی پوشه‌های شخصی، یا از SSH استفاده کنید، یا در `data/config.yaml` source سوم (که کامنت شده) را فعال کنید و در تنظیمات کاربر به admin بدهید — توجه کنید که باعث ایندکس تکراری می‌شود.

---

## ۴. ساختار روی سرور

```
/opt/filemanager
├── docker-compose.yml      # FileBrowser + Caddy
├── Caddyfile               # HTTPS و پروکسی
├── .env                    # دامنه، رمز ادمین، کلیدها (محرمانه)
├── data/                   # تنظیمات و دیتابیس — بکاپ بگیرید
│   ├── config.yaml
│   └── database.sqlite
├── files/
│   ├── users/<username>/   # پوشه‌ی شخصی هر کاربر
│   └── shared/             # پوشه‌ی مشترک
├── backups/
├── setup.sh
├── add-user.sh
└── backup.sh
```

کانتینر FileBrowser با UID/GID `1000:1000` اجرا می‌شود؛ اگر پوشه‌ای را دستی روی هاست ساختید، مالکیتش را اصلاح کنید:

```bash
sudo chown -R 1000:1000 /opt/filemanager/files /opt/filemanager/data
```

---

## ۵. اشتراک‌گذاری

**لینک اشتراک:** روی فایل یا پوشه → منوی `⋯` → **Share**:
- رمز دلخواه برای لینک
- تاریخ انقضا
- سطح دسترسی: فقط دیدن / دانلود / آپلود / ویرایش
- محدود کردن به کاربران لاگین‌کرده یا آزاد برای همه

لینک روی مسیر `/public/share/...` ساخته می‌شود و **بدون لاگین** هم برای مهمان باز می‌شود — پس Caddy این مسیر را از احراز هویت جدا نگه داشته است.

**دریافت فایل از مشتری (بدون اکانت):** یک پوشه بسازید و Share با اجازه‌ی **آپلود** بدهید؛ طرف مقابل فقط می‌تواند فایل بریزد و فایل‌های دیگران را نمی‌بیند.

**لغو دسترسی:** همان‌جا در لیست Shareها حذف کنید. حذف فایل هم لینک را از کار می‌اندازد.

---

## ۶. اتصال به‌عنوان درایو (WebDAV)

آدرس: `https://files.example.com/dav` — با همان نام کاربری و رمز پنل.

- **ویندوز:** File Explorer → Map network drive → `https://files.example.com/dav`
- **مک:** Finder → Go → Connect to Server → همان آدرس
- **rclone / موبایل:** از نوع WebDAV استفاده کنید

---

## ۷. تنظیمات رایج

| کار | جای تغییر |
|---|---|
| تغییر دامنه | `.env` و `data/config.yaml` (`http.externalUrl`) → `docker compose up -d --force-recreate` |
| ثبت‌نام آزاد کاربران | `data/config.yaml` → `auth.methods.password.signup: true` (برای سرور عمومی توصیه نمی‌شود) |
| حداقل طول رمز | همان‌جا `minLength` |
| نام و لوگو | Settings → Branding (در پنل) |
| ورود دو مرحله‌ای (2FA) | در `.env` مقدار `TOTP_SECRET=$(openssl rand -base64 32)` را بگذارید، خط `FILEBROWSER_TOTP_SECRET` را در `docker-compose.yml` از کامنت خارج کنید و در `data/config.yaml` مقدار `auth.enforcedOtp: true` بگذارید (اجباری) — تغییر بعدی این کلید همه‌ی 2FAها را باطل می‌کند |
| محدود کردن حجم/سهم هر کاربر | در نسخه‌ی v2.1 (بتا) اضافه شده؛ در نسخه‌ی پایدار فعلی نیست |
| حذف کاربر | Settings → User management → Delete |

بعد از هر تغییر در `data/config.yaml`:

```bash
docker compose restart filebrowser
```

---

## ۸. به‌روزرسانی

```bash
cd /opt/filemanager
./backup.sh
docker compose pull
docker compose up -d
docker compose ps
```

نسخه‌ی پایدار روی تگ `stable` است. اگر می‌خواهید نسخه را قفل کنید، در `docker-compose.yml` به‌جای `stable` بنویسید مثلاً `2.0-stable`.

---

## ۹. پشتیبان‌گیری

```bash
./backup.sh
```

- `backups/data-*.tar.gz` → تنظیمات + دیتابیس (کاربران، Shareها)
- فایل‌های کاربران با `rsync` جدا بکاپ گرفته می‌شوند (در خروجی اسکریپت دستورش می‌آید)

**ری‌استور:**

```bash
cd /opt/filemanager
docker compose down
tar -xzf backups/data-YYYYmmdd-HHMMSS.tar.gz
sudo chown -R 1000:1000 data files
docker compose up -d
```

برای بکاپ خودکار روزانه، یک cron بگذارید:

```bash
crontab -e
# هر شب ۳ بامداد
0 3 * * * cd /opt/filemanager && ./backup.sh >> /var/log/filebrowser-backup.log 2>&1
```

---

## ۱۰. عیب‌یابی

| نشانه | علت / راه‌حل |
|---|---|
| سایت باز نمی‌شود (502) | `docker compose ps` و `docker compose logs filebrowser`؛ معمولاً خطای config یا مالکیت پوشه |
| گواهی SSL گرفته نمی‌شود | DNS دامنه به IP سرور اشاره نمی‌کند، یا پورت ۸۰ بسته است. `docker compose logs caddy` |
| «ورود ناموفق» با رمز درست | `http.externalUrl` با دامنه‌ای که در مرورگر باز کرده‌اید یکی نیست (کوکی ست نمی‌شود) |
| آپلود خطا می‌دهد | مالکیت: `sudo chown -R 1000:1000 files data`؛ فضای دیسک: `df -h` |
| لیست فایل‌ها خالی است | مسیر source در `data/config.yaml` با mountها نمی‌خواند؛ `defaultEnabled` خاموش است |
| کاربر «مشترک» را نمی‌بیند | `docker compose restart filebrowser` (sourceهای پیش‌فرض در استارت‌آپ merge می‌شوند) |
| پورت ۸۰ اشغال است | اگر nginx/apache دارید، سرویس Caddy را حذف کنید و همان nginx را پروکسی کنید (نمونه در مستندات) |
| خروج خودکار کاربران با هر ری‌استارت | `JWT_SECRET` در `.env` تنظیم نشده؛ `./setup.sh` آن را می‌سازد |

لاگ‌ها:

```bash
docker compose logs -f filebrowser
docker compose logs -f caddy
tail -f /opt/filemanager/data/tmp/*.log 2>/dev/null
```

---

## ۱۱. چک‌لیست امنیتی

- [ ] `signup: false` باشد (پیش‌فرض همین است) تا کسی خودش ثبت‌نام نکند.
- [ ] رمز ادمین قوی و یونیک؛ بعد از پیکربندی، `ADMIN_PASSWORD` را از `.env` بردارید.
- [ ] `ADMIN_PASSWORD` و `.env` را در git یا چت عمومی نگذارید (`chmod 600 .env`).
- [ ] فقط پورت‌های ۸۰ و ۴۴۳ باز باشند؛ FileBrowser هیچ پورتی روی هاست باز نکرده و فقط از طریق Caddy در دسترس است.
- [ ] برای کاربران حساس 2FA را فعال کنید.
- [ ] بکاپ خودکار + تست ری‌استور.
- [ ] به‌روزرسانی ماهانه‌ی ایمیج و سیستم.
- [ ] اگر فایل‌های خیلی حساس دارید، پوشه‌ی شخصی هر کاربر را با `private: true` از اشتراک‌گذاری منع کنید (در `data/config.yaml`).

---

## ۱۲. دستورهای پرکاربرد

```bash
docker compose ps                 # وضعیت
docker compose restart            # ری‌استارت همه
docker compose down               # خاموش کردن
docker compose up -d              # روشن کردن
docker compose logs -f caddy      # لاگ SSL
./add-user.sh <user>              # کاربر جدید
./backup.sh                       # بکاپ
```

مستندات رسمی: <https://filebrowserquantum.com/>
