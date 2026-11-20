# Xray + NoobzVPN Panel (Railway + Cloudflare Tunnel)

Template deploy otomatis **NoobzVPN Panel**, **Xray-core**, dan **Cloudflare Tunnel** di dalam kontainer Railway.

## Persiapan
1. Akun **GitHub** dan **Railway**.
2. Domain aktif di **Cloudflare** beserta token **Cloudflare Tunnel**.

## 1. Konfigurasi Cloudflare Tunnel
1. Buka dashboard **Cloudflare Zero Trust** -> **Networks** -> **Tunnels** -> pilih tunnel kamu -> tab **Routes**.
2. Tambahkan **Public Hostname** (subdomain untuk VPN) dan arahkan langsung ke:
   - **Service:** `HTTP`
   - **URL:** `127.0.0.1:80`
3. *(Opsional)* Jika ingin memakai koneksi **Port 80 (Non-TLS)**, masuk ke menu **SSL/TLS** -> **Edge Certificates** di dashboard domain Cloudflare kamu, lalu matikan fitur **Always Use HTTPS**.

## 2. Deploy di Railway
1. **Fork** repository ini ke akun GitHub kamu.
2. Buka dashboard **Railway**, pilih **New Project** -> **Deploy from GitHub repo**, lalu pilih hasil *fork* repository ini.
3. Masuk ke tab **Variables** dan tambahkan variabel berikut:
   - **Name:** `CF_TOKEN`
   - **Value:** *(Tempel token Cloudflare Tunnel kamu)*
4. Masuk ke tab **Settings** -> bagian **Networking (Public networking)**, klik **Generate Domain** dan arahkan ke port **`3000`** untuk mengakses web panel.
5. Tunggu proses deploy selesai hingga status berubah menjadi **Active**.

## 3. Instalasi & Buat Akun VPN
1. Buka domain Railway (`*.up.railway.app`) di browser, lalu login menggunakan password bawaan: `noobzvpns`.
2. Pada halaman instalasi panel:
   - **Server Type:** `NAT VPS with Cloudflared`
   - **Domain:** Masukkan subdomain Cloudflare kamu
   - Klik **Start Installation** hingga selesai.
3. Buat akun **VLESS WebSocket** (`Path: /vless-ws`), lalu masukkan detail akun ke aplikasi client (Sing-box, v2rayNG, HTTP Custom, dll).
