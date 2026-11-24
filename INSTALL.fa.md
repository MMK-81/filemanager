# نصب صفر تا صد — فایل‌منیجر تیمی روی سرور

این راهنما فرض می‌کند یک سرور خالی (VPS) دارید و می‌خواهید تا آخر خط بروید. هر گام: دستور، توضیح اینکه چه اتفاقی می‌افتد، و روش مطمئن شدن از درستی کار.

**نمادها:** دستورها را در ترمینال سرور بزنید. اگر با کاربر `root` وارد شده‌اید، `sudo` لازم نیست.

---

## گام ۰ — چه چیزی لازم دارید

| مورد | حداقل | پیشنهاد |
|---|---|---|
| سرور | Ubuntu 22.04/24.04 یا Debian 12، ۱ هسته، ۵۱۲ مگ رم | ۱ هسته، ۱ گیگ رم |
| فضا | ۱۰ گیگ | به حجم فایل‌ها بستگی دارد |
| دامنه | یک دامنه یا زیردامنه | `files.example.com` |
| پورت‌ها | 22 (SSH)، 80، 443 | همان |

اگر دامنه ندارید: می‌توانید فعلاً از `IP.sslip.io` استفاده کنید (مثلاً `203.0.113.10.sslip.io`). این دامنه‌ی رایگان بدون تنظیم DNS به IP شما اشاره می‌کند و Let's Encrypt برایش گواهی می‌دهد. بعداً دامنه‌ی واقعی را جایگزین کنید.

منابع مصرفی نهایی: FileBrowser حدود ۵۰–۱۰۰ مگ رم و Caddy حدود ۳۰ مگ. ایمیج‌ها حدود ۲۲۰ مگ دیسک.

---

## گام ۱ — اتصال دامنه به سرور (DNS)

در پنل ثبت دامنه (ایرنیک، Cloudflare، Namecheap، …):

| Type | Name | Value | TTL |
|---|---|---|---|
| A | `files` | `IP سرور` | 300 |

- اگر رکورد `AAAA` قدیمی برای همین نام دارید و سرور IPv6 ندارد، **پاکش کنید**؛ وگرنه گواهی SSL گرفته نمی‌شود.
- اگر از Cloudflare استفاده می‌کنید، ابر نارنجی (Proxy) را برای این رکورد **خاموش** کنید (DNS only) تا گواهی گرفته شود. بعد از راه‌اندازی می‌توانید روشن کنید.
- `example.com` را با دامنه‌ی خودتان عوض کنید.

بررسی از روی سیستم خودتان (نه سرور):

```bash
nslookup files.example.com
# یا
dig +short files.example.com
```

باید **همان IP سرور** را برگرداند. اگر خالی بود، ۵ تا ۱۰ دقیقه صبر کنید (گاهی تا ۱ ساعت).

---

## گام ۲ — ورود به سرور و به‌روزرسانی سیستم

```bash
ssh root@SERVER_IP
```

اولین بار پیام `The authenticity of host ... can't be established` می‌آید؛ `yes` بزنید.

```bash
apt update && apt upgrade -y
timedatectl          # ساعت سرور باید درست باشد، وگرنه گواهی SSL مشکل می‌خورد
```

ساختن کاربر غیرروت (اختیاری ولی توصیه‌شده):

```bash
adduser deploy
usermod -aG sudo deploy
# از این به بعد: ssh deploy@SERVER_IP
```

---

## گام ۳ — نصب Docker و Compose

```bash
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker
docker --version
docker compose version
```

خروجی باید چیزی شبیه `Docker version 27.x` و `Docker Compose version v2.x` باشد.

اگر کاربر غیرروت هستید:

```bash
sudo usermod -aG docker $USER
```

بعد **یک‌بار از SSH خارج و دوباره وارد شوید** (یا `newgrp docker`) تا گروه اعمال شود. تست:

```bash
docker run --rm hello-world
```

اگر `permission denied while trying to connect to the Docker daemon` دیدید، یعنی هنوز logout/login نکرده‌اید.

---

## گام ۴ — فایروال

روی سرور:

```bash
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
ufw status
```

**مهم:** اگر سرور از یک ارائه‌دهنده‌ی ابری است (Hetzner، AWS، Oracle، …)، فایروال/ Security Group پنل آن‌ها هم باید ۸۰ و ۴۴۳ را باز کند. بیشتر «گواهی گرفته نمی‌شود» ها از همین‌جاست.

اگر روی سرور از قبل nginx یا apache دارید که پورت ۸۰ را گرفته:

```bash
systemctl stop nginx apache2 2>/dev/null
systemctl disable nginx apache2 2>/dev/null
```

---

## گام ۵ — کپی بسته روی سرور

**از ویندوز (PowerShell):**

```powershell
scp -r "C:\Users\Kashi\Documents\Default Project\filemanager" root@SERVER_IP:/opt/
```

اگر روی ویندوز zip ساختید، ساده‌تر:

```powershell
scp "C:\Users\Kashi\Documents\Default Project\filemanager.zip" root@SERVER_IP:/opt/
ssh root@SERVER_IP
cd /opt && apt install -y unzip && unzip filemanager.zip
```

**روی سرور بررسی کنید:**

```bash
cd /opt/filemanager
ls -la
file setup.sh
```

باید `setup.sh`, `add-user.sh`, `backup.sh`, `docker-compose.yml`, `Caddyfile`, `.env.example`, `data/config.yaml`, `README.fa.md` را ببینید و `file` باید بگوید `ASCII text` **بدون** `CRLF`. اگر `CRLF` دید:

```bash
sed -i 's/\r$//' *.sh
```

---

## گام ۶ — ساخت فایل تنظیمات `.env`

```bash
cd /opt/filemanager
cp .env.example .env
nano .env
```

محتوا را این‌طور کنید:

```ini
DOMAIN=files.darkfamily.ir
ACME_EMAIL=admin@files.darkfamily.ir
ADMIN_PASSWORD=GENERATE_A_STRONG_PASSWORD
JWT_SECRET=__GENERATE__
```

> فایل `.env` از قبل با همین مقادیر ساخته شده است؛ فقط اگر رمز را عوض کردید، همین‌جا هم عوض کنید. کاربر ادمین: `admin` / `GENERATE_A_STRONG_PASSWORD`.

- `ADMIN_PASSWORD` را با `openssl rand -hex 16` بسازید (۳۲ کاراکتر، بدون کاراکتر خاص که در `.env` مشکل بسازد).
- در `.env` از فاصله و `#` و کوتیشن استفاده نکنید؛ فقط حروف/عدد/`-_.` مجاز است.
- ذخیره: `Ctrl+O` → `Enter` → `Ctrl+X`.

محافظت از فایل:

```bash
chmod 600 .env
```

---

## گام ۷ — اجرای نصب

```bash
chmod +x *.sh
./setup.sh
```

اسکریپت به‌ترتیب:

1. وجود Docker و Compose را چک می‌کند.
2. `.env` را می‌خواند و مقادیر نمونه/ضعیف را رد می‌کند.
3. پوشه‌های `data/`, `files/users/`, `files/shared/` را می‌سازد.
4. دامنه را در `data/config.yaml` می‌نویسد (`https://files.example.com`).
5. کلید `JWT_SECRET` را می‌سازد تا با هر ری‌استارت کاربران خارج نشوند.
6. مالکیت فایل‌ها را به `1000:1000` می‌دهد (کاربر داخل کانتینر).
7. هشدار می‌دهد اگر پورت ۸۰/۴۴۳ اشغال است.
8. ایمیج‌ها را می‌گیرد و `docker compose up -d` می‌زند.

خروجی موفق شبیه این است:

```
NAME                      IMAGE                                    STATUS
filemanager-caddy-1       caddy:2-alpine                           Up
filemanager-filebrowser-1 ghcr.io/gtsteffaniak/filebrowser:stable  Up
```

اگر خطا گرفتید، بخش «عیب‌یابی» پایین را ببینید.

---

## گام ۸ — گرفتن گواهی SSL و اولین ورود

```bash
docker compose ps
docker compose logs --tail=40 caddy
```

دنبال `certificate obtained successfully` بگردید. اولین بار ۳۰ تا ۹۰ ثانیه طول می‌کشد.

مرورگر را باز کنید:

```
https://files.example.com
```

قفل سبز/قفل بسته یعنی HTTPS درست است. ورود:

| کاربر | رمز |
|---|---|
| `admin` | همان `ADMIN_PASSWORD` در `.env` |

**اگر رمز را اشتباه زدید یا `.env` را خالی گذاشتید:** رمز تصادفی یک‌بار در لاگ چاپ می‌شود:

```bash
docker compose logs filebrowser 2>&1 | grep -i "initial admin password"
```

بعد از ورود باید در پنل کنار هم دو فضا ببینید: **«پوشه من»** و **«مشترک»**.

**تست سریع سلامت:** در «پوشه من» یک فایل کوچک آپلود کنید، سپس یک فایل در «مشترک» بگذارید. اگر آپلود خطا داد، بخش عیب‌یابی مورد «آپلود ناموفق».

---

## گام ۹ — ساخت کاربر برای هر نفر

```bash
cd /opt/filemanager
./add-user.sh ali
```

رمزی که می‌خواهید را وارد کنید (حداقل ۱۰ کاراکتر؛ پیشنهاد ۱۲+). اسکریپت سرور را یک لحظه stop می‌کند، کاربر را می‌سازد، پوشه‌ی `files/users/ali` را می‌سازد و دوباره بالا می‌آورد.

از پنل هم می‌شود: **Settings → User management → Add user** (نام، رمز، ادمین بودن، و sourceهای مجاز).

بررسی جداسازی: در یک پنجره‌ی ناشناس (Incognito) با `ali` وارد شوید — باید فقط «پوشه من» (خالی) و «مشترک» را ببیند و فایل‌های کاربران دیگر را نبیند.

تغییر رمز یک کاربر = همان دستور با همان نام کاربری. حذف کاربر: **User management → Delete** (فایل‌هایش روی دیسک می‌مانند).

---

## گام ۱۰ — آپلود و اشتراک‌گذاری

**آپلود:** دکمه‌ی `+` یا Upload در فضای موردنظر؛ می‌توانید فایل را با ماوس بکشید و رها کنید. آپلود پوشه و چند فایل هم پشتیبانی می‌شود.

**ساخت لینک اشتراک:**

1. روی فایل یا پوشه کلیک کنید → منوی `⋯` → **Share**.
2. گزینه‌ها:
   - **Password**: رمز روی لینک
   - **Expires**: تاریخ/ساعت انقضا
   - **Permissions**: دیدن / دانلود / آپلود / ویرایش
   - **Who can access**: همه (مهمان) یا فقط کاربران لاگین‌کرده
3. **Create** و کپی لینک (`https://files.example.com/public/share/...`).

لینک مهمان **بدون لاگین** باز می‌شود؛ برای تست، همان لینک را در پنجره‌ی ناشناس باز کنید.

**دریافت فایل از مشتری بدون اکانت:** یک پوشه بسازید (مثلاً `files/shared/inbox`)، لینک Share با اجازه‌ی **آپلود** بدهید؛ طرف مقابل فقط می‌تواند بریزد.

**لغو دسترسی:** در پنل، بخش Shares → حذف. حذف فایل هم لینک را از کار می‌اندازد.

---

## گام ۱۱ — اتصال به‌عنوان درایو (WebDAV)

| سیستم | کار |
|---|---|
| ویندوز | File Explorer → Map network drive → `https://files.example.com/dav` با همان یوزر/پس |
| مک | Finder → Go → Connect to Server → `https://files.example.com/dav` |
| موبایل | هر اپ WebDAV (Documents، Solid Explorer، …) با همان آدرس |

با `rclone`:

```bash
rclone config
# n → name: files → storage: webdav → url: https://files.example.com/dav
# vendor: other → user/pass → y
rclone ls files:
```

---

## گام ۱۲ — کارهای بعد از نصب

**دیدن همه‌ی پوشه‌های شخصی توسط ادمین (اختیاری):** در `data/config.yaml` source سوم (کامنت‌شده) را از کامنت خارج کنید، `docker compose restart filebrowser`، بعد در User management برای `admin` آن source را فعال کنید. توجه: ایندکس تکراری می‌شود.

**برداشتن رمز ادمین از `.env` (تا رمز پنل پایدار بماند):**

```bash
nano .env                 # خط ADMIN_PASSWORD را پاک/کامنت کنید
nano docker-compose.yml   # خط FILEBROWSER_ADMIN_PASSWORD را هم کامنت کنید
docker compose up -d --force-recreate
```

**ورود دو مرحله‌ای (2FA):**

```bash
openssl rand -base64 32     # خروجی را در .env بگذارید: TOTP_SECRET=...
nano docker-compose.yml     # خط FILEBROWSER_TOTP_SECRET را از کامنت خارج کنید
docker compose up -d
```

برای اجباری‌کردن، در `data/config.yaml`:

```yaml
auth:
  enforcedOtp: true
```

بعد `docker compose restart filebrowser`. (عوض‌کردن این کلید بعداً، 2FA همه را باطل می‌کند.)

**تغییر دامنه:**

```bash
nano .env                    # DOMAIN=...
./setup.sh                   # externalUrl را هم به‌روز می‌کند
docker compose up -d --force-recreate
```

**بکاپ:**

```bash
./backup.sh
# خروجی: backups/data-YYYYmmdd-HHMMSS.tar.gz
```

بکاپ خودکار شبانه:

```bash
crontab -e
0 3 * * * cd /opt/filemanager && ./backup.sh >> /var/log/filebrowser-backup.log 2>&1
```

فایل‌های کاربران با `rsync` جدا:

```bash
rsync -a --delete /opt/filemanager/files/ user@backup-host:/backup/files/
```

**ری‌استور:**

```bash
cd /opt/filemanager
docker compose down
tar -xzf backups/data-YYYYmmdd-HHMMSS.tar.gz
chown -R 1000:1000 data files
docker compose up -d
```

**به‌روزرسانی:**

```bash
cd /opt/filemanager
./backup.sh
docker compose pull
docker compose up -d
docker compose ps
```

---

## گام ۱۳ — عیب‌یابی

| نشانه | تشخیص | راه‌حل |
|---|---|---|
| سایت 502 می‌دهد | FileBrowser بالا نیست یا کرش می‌کند | `docker compose logs --tail=100 filebrowser` |
| گواهی SSL گرفته نمی‌شود | DNS یا پورت ۸۰ | `dig +short DOMAIN` و `curl -I http://DOMAIN`؛ لاگ: `docker compose logs caddy` |
| `address already in use` | پورت ۸۰/۴۴۳ اشغال است | `ss -ltnp \| grep -E ':80\|:443'` → سرویس مهاجم را stop کنید |
| آپلود ناموفق / فایل صفر بایتی | مالکیت پوشه یا دیسک پر | `chown -R 1000:1000 files data` و `df -h` |
| لیست فایل خالی است | مسیر source با mount نمی‌خواند | `docker compose exec filebrowser ls /data/users` و `data/config.yaml` |
| کاربر «مشترک» را نمی‌بیند | کاربر قبل از افزودن source ساخته شده | `docker compose restart filebrowser` |
| با رمز درست لاگین نمی‌شود | دامنه/`externalUrl` ناهماهنگ = کوکی ست نمی‌شود | `grep externalUrl data/config.yaml` باید با آدرس مرورگر برابر باشد |
| هر ری‌استارت همه logout می‌شوند | `JWT_SECRET` تنظیم نشده | `.env` → `JWT_SECRET=$(openssl rand -hex 32)` → `up -d` |
| کانتینر مدام restart می‌شود | خطای config.yaml | `docker compose logs filebrowser \| tail -50` |
| `permission denied` روی docker | کاربر در گروه docker نیست | `sudo usermod -aG docker $USER` + logout/login |
| `bad interpreter` | اسکریپت CRLF شده | `sed -i 's/\r$//' *.sh` |

لاگ‌های همیشگی:

```bash
docker compose logs -f filebrowser
docker compose logs -f caddy
tail -f /opt/filemanager/data/tmp/*.log        # لاگ داخلی FileBrowser
docker compose exec caddy tail -f /data/access.log   # دسترسی‌ها
```

---

## گام ۱۴ — چک‌لیست پذیرش نهایی

- [ ] `https://دامنه` باز می‌شود و قفل SSL سالم است (بدون هشدار مرورگر).
- [ ] `admin` وارد می‌شود و دو فضا را می‌بیند.
- [ ] آپلود و دانلود در «پوشه من» و «مشترک» کار می‌کند.
- [ ] کاربر دوم ساخته شده و در Incognito فقط فضای خودش را می‌بیند.
- [ ] یک لینک Share با رمز ساخته و در Incognito باز شده است.
- [ ] یک لینک Share حذف شده و دیگر باز نمی‌شود.
- [ ] `./backup.sh` فایل می‌سازد و یک‌بار ری‌استور روی محیط تست جواب می‌دهد.
- [ ] `ufw status` فقط 22/80/443 را باز نشان می‌دهد.
- [ ] `ADMIN_PASSWORD` در `.env` یا حذف شده یا در جای امن نگهداری می‌شود.
- [ ] cron بکاپ فعال است.

---

## پیوست — دستورهای روزمره

```bash
cd /opt/filemanager
docker compose ps                 # وضعیت
docker compose restart            # ری‌استارت
docker compose down               # خاموش
docker compose up -d              # روشن
docker compose logs -f caddy      # SSL
./add-user.sh <user>              # کاربر جدید
./backup.sh                       # بکاپ
du -sh files/*                    # حجم فایل‌ها
```

مستندات رسمی: <https://filebrowserquantum.com/>
