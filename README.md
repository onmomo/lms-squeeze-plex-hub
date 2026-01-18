# LMS Squeeze Plex Hub Plugin

**Squeeze Plex Hub Plugin** is a plugin for **Lyrion Music Server (LMS)** that enriches playback with **Plex Media Server (PMS) metadata** when tracks are loaded via the **Squeeze Plex Hub** application.

When audio is streamed into LMS through Squeeze Plex Hub, this plugin bridges the metadata gap by fetching and displaying the original Plex song information (title, artist, album, artwork, etc.) inside LMS and on connected players.

While optional, this plugin is strongly recommended when using the [Squeeze Plex Hub](https://github.com/onmomo/squeeze-plex-hub) project to unlock the best overall playback and metadata experience in LMS.

---

## ✨ Features

- Displays **Plex PMS metadata** in LMS
- Automatically detects tracks loaded via **Squeeze Plex Hub**
- Shows correct **title, artist, album, and artwork**

---

## 🔧 Requirements

- **Lyrion Music Server (LMS)**
- **Squeeze Plex Hub** application
- **Plex Media Server** reachable from Squeeze Plex Hub

---

## 🚀 Installation

### Manual Installation (Recommended for Development)

1. Clone this repository
2. Ensure the plugin directory is named exactly:
3. Restart LMS after any change
   > LMS does **not** hot-reload plugins

---

## 🧑‍💻 Local Development

### Unit Testing
From repo root:
```bash
cpanm --installdeps --notest .
prove -lr t
```

### macOS (LMS Package)

Install the Lyrion Music Server DMG for macOS, then symlink the plugin into LMS:

```bash
mkdir -p "/Users/$USER/Library/Application Support/Squeezebox/Plugins/SqueezePlexHub"
ln -sv "$(pwd)/SqueezePlexHub/"* "/Users/$USER/Library/Application Support/Squeezebox/Plugins/SqueezePlexHub"
```

Restart LMS after linking.

### 🐳 Docker (Development & Testing)

You can run LMS in Docker and mount the plugin directly:

```bash
docker run --rm -it \
  -e TZ=Europe/Zurich \
  -v $PWD/config:/config:rw \
  -v $PWD/SqueezePlexHub:/lms/Plugins/SqueezePlexHub:ro \
  -v $PWD/music:/music:ro \
  -v $PWD/playlist:/playlist:ro \
  -v /etc/localtime:/etc/localtime:ro \
  -p 9000:9000/tcp \
  -p 9090:9090/tcp \
  -p 3483:3483/tcp \
  -p 3483:3483/udp \
  lmscommunity/lyrionmusicserver
```

⚠️ Note:
I could LMS not to work properly with Docker Desktop (macOS) for development.
Native Linux Docker is recommended for best results.

## 🧠 How It Works

Squeeze Plex Hub injects tracks into LMS
The plugin detects those tracks
Metadata is fetched from Plex Media Server
LMS is updated in real-time with enriched metadata

## 🛠 Status

Actively developed
Stable for daily use
Open to improvements and contributions

## 🤝 Contributing

Pull requests, bug reports, and feature ideas are welcome.
If you enjoy extending LMS, Plex, or legacy Squeezebox hardware — contributions are appreciated.

## 📄 License

MIT

## ⚠️ Disclaimer

This project is not affiliated with or endorsed by Plex, Logitech, or Lyrion.
All trademarks belong to their respective owners.
