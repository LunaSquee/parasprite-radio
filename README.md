![Parasprite Radio](https://i.imgbox.com/GARLVsXm.png)

Under development! See the live site: http://radio.djazz.se

## Running with Docker

The easiest way to run the whole station is Docker Compose. It starts:

| Service      | What it does                                         | Port(s)                                     |
|--------------|------------------------------------------------------|---------------------------------------------|
| `server`     | Node web server (website, API, HLS streams)          | 8002                                        |
| `liquidsoap` | Liquidsoap 2.x: playout, encoding, live DJ input     | 7004 (telnet), 7005 (live input), 7006 (Shoutcast metadata) |
| `icecast`    | Icecast streaming server                             | 8000                                        |
| `mpd`        | Music database, used by the website for search/browse | 6600                                        |
| `mysql`      | MariaDB, for users and shows                         | 3306                                        |

You need Docker with the Compose plugin (`docker compose`). You don't need Node,
Liquidsoap or anything else installed on the host.

### 1. Music and playlist

Put your music in `docker/music`, or make it a symlink to your music folder:

```
ln -s /path/to/your/music docker/music
```

Liquidsoap plays the playlist `docker/playlists/radio.m3u`. MPD also reads this
folder, so the site knows which tracks are in rotation. Entries can be relative
to the music folder (as MPD writes them) or absolute paths starting with
`/music/`. To put every track in rotation:

```
mkdir -p docker/playlists
(cd docker/music/ && find -L . -type f \( -iname '*.mp3' -o -iname '*.flac' -o -iname '*.ogg' -o -iname '*.opus' -o -iname '*.m4a' \) | sed 's|^\./||' | sort) > docker/playlists/radio.m3u
```

Liquidsoap reloads the playlist every 10 minutes. MPD scans the music folder
when its container starts, so run `docker compose restart mpd` after adding music.

### 2. Icecast config

Start from the image's default config, and raise the source limit: the radio
uses several mounts, and the default only allows 2.

```
docker run --rm --entrypoint cat pltnk/icecast2 /etc/icecast2/icecast.xml \
  | sed 's|<sources>2</sources>|<sources>10</sources>|' > docker/icecast.xml
```

Change the passwords in `docker/icecast.xml` (`source-password`, `relay-password`,
`admin-password`) and set `<hostname>` to the public host name if you're not
running locally.

### 3. Radio config

```
cp conf/radio.default.toml conf/radio.toml
```

Edit `conf/radio.toml`. The services find each other by their Compose service
names, so set:

```toml
[general]
media_dir = "/music"

[icecast]
host = "icecast"
[icecast.mount]
password = "..."         # same as source-password in docker/icecast.xml
[icecast.admin]
password = "..."         # same as admin-password in docker/icecast.xml

[liquidsoap]
host = "liquidsoap"

[mpd]
host = "mpd"

[server]
host = "server"
cookieSecret  = "..."    # any long random string
sessionSecret = "..."    # any long random string

[mysql]
host     = "mysql"
user     = "paraspriteradio"
password = "..."         # same as MYSQL_PASSWORD in docker-compose.yml
database = "paraspriteradio"
```

Leave `server.streams_dir` at `/tmp/pr/streams`: that's where the containers
share the HLS stream. Change the MariaDB passwords in `docker-compose.yml`
(`MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`) **before the first start**: they're only
applied when the database is created.

Optional:

* **Last.fm scrobbling:** set `lastfm.enable = true`, your Last.fm `username` and
  `password`, and an API `key` and `secret` under `[lastfm.api]`. You can create
  those at https://www.last.fm/api/account/create.
* **TuneIn now playing:** fill in `[tunein]`.

### 4. Start it

Create the folders the containers write to, so they are owned by you and not
by root. Docker creates missing folders as root.

```
mkdir -p docker/streams docker/database archive
docker compose up -d --build
```

The first build takes a few minutes. Then open:

* the website: http://localhost:8002
* the MP3 stream: http://localhost:8000/radio

The database tables are created automatically when the server starts.

Liquidsoap runs as uid/gid 1000, so it can write live show recordings to
`archive/`. If your user has a different id, start it with:

```
LIQ_UID=$(id -u) LIQ_GID=$(id -g) docker compose up -d
```

### Live DJs

DJs connect to port **7005** as an Icecast source with an empty mount (`/`).
The username is `source`, and the password is their show's auth token from the
website. The station fades over to the live show and records it to
`archive/<user>-<show>/<date>/`. When the DJ disconnects, it goes back to music.

### Day to day

```
docker compose logs -f liquidsoap server   # follow the logs
docker compose restart liquidsoap          # after editing liq/*.liq or conf/radio.toml
docker compose up -d --build server        # after changing server/ or src/ code
docker compose down                        # stop everything (data is kept)
```

The `liquidsoap` container runs straight from the repo, so a restart picks up
changes. The `server` image has the code and the built frontend baked in, so it
needs a rebuild.

To run Liquidsoap in dev mode (HLS stream only, no Icecast), change its
`command` in `docker-compose.yml` to `["radio.liq", "--", "dev"]`.

### Security

The Compose file publishes every port on all interfaces, including the
Liquidsoap telnet port (7004), which has no authentication and controls the
station, and MariaDB (3306). That's fine on your own machine. Before running it
anywhere reachable from the internet, remove those `ports:` entries or bind
them to `127.0.0.1` (for example `127.0.0.1:7004:7004`), and change every
default password.

## Manual installation

Note: Installation instructions are not complete!

### Install dependencies

#### Ubuntu

TODO

#### Arch Linux

`sudo pacman -S nodejs npm mariadb mpd icecast mediainfo graphicsmagick flac opus-tools curl festival sox`

Now [install Liquidsoap](https://www.liquidsoap.info/) from [AUR](https://aur.archlinux.org/packages/liquidsoap/) or [OPAM](https://opam.ocaml.org/packages/liquidsoap/).

Install [ffmpeg-git](https://aur.archlinux.org/packages/ffmpeg-git/) from AUR or build it yourself. Any recent ffmpeg version with fdkaac enabled should work. You could also install the [ffmpeg-full](https://aur.archlinux.org/packages/ffmpeg-full/) or [ffmpeg-full-git](https://aur.archlinux.org/packages/ffmpeg-full-git/) package, or possibly [ffmpeg-libfdk_aac](https://aur.archlinux.org/packages/ffmpeg-libfdk_aac/).

Follow [these instructions](https://wiki.archlinux.org/index.php/MySQL#Installation) to set up the MySQL service.

### Set up
```
# Install Gulp globally:
sudo npm install -g gulp

# Install nodejs dependencies and build the app in debug mode:
./install

# Create structure for MPD:
mkdir -p ~/.mpd/playlists
touch ~/.mpd/playlists/radio.m3u
```

Edit `/etc/icecast.xml` and increase `<sources>` from 2 to 10. Also, change passwords! Create a MySQL database for the radio. Edit `conf/radio.toml` and `conf/mpd.conf`. Start Icecast and MySQL services.

## Usage

Start MPD: `bin/startmpd`

Start Liquidsoap: in development `bin/startliq dev` or production `bin/startliq`

Start node server: in development `bin/startserver -d` or production `bin/startserver`

If you haven't changed the default port, you can view the radio page here: [http://localhost:8002](http://localhost:8002)

For debugging with BrowserSync, run `gulp watch`, `bin/startserver -d` and open [http://localhost:3000](http://localhost:3000)

To build the app for production: `gulp -p`
