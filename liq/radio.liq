#!/usr/bin/liquidsoap
# Parasprite Radio -- Liquidsoap 2.x

# Put the log file in some directory
settings.log.file.path := "./radio.log"
settings.log.file := false
settings.log.stdout := true
#settings.log.level := 4

%include "config.liq"

# to run in dev mode: liquidsoap radio.liq -- dev
inDev = argv(1) == "dev"

# Use the telnet server for requests
settings.server.telnet := true
settings.server.telnet.bind_addr := "0.0.0.0"
settings.server.telnet.port := confint("liquidsoap.port_telnet", 7004)

port_input = confint("liquidsoap.port_input", 7005)

settings.harbor.bind_addrs := ["0.0.0.0"]
settings.harbor.verbose := false
settings.harbor.reverse_dns := true

settings.frame.audio.samplerate := 48000
settings.audio.converter.samplerate.libsamplerate.quality := "best"

#settings.decoder.debug := true

def env_or(name, default) =
	v = environment.get(name)
	if v == "" then default else v end
end

serverport = env_or("SERVER_PORT", "#{confint('server.port', 8002)}")
serverhost = env_or("SERVER_HOST", confstr("server.host", "localhost"))
serverurl  = "http://#{serverhost}:#{serverport}"

%include "utils.liq"
%include "tunein.liq"
%include "protocols.liq"
%include "decoders.liq"

meta = ref([])
history = ref([])
history_size = 20
live_meta = ref([])
live_token = ref("")
live_busy = ref(false)

# Last.fm scrobbling (API 2.0) via scripts/lastfm.js; Liquidsoap 2.x has no
# built-in support and the old Audioscrobbler protocol it used is gone.
lastfm_enabled = confbool("lastfm.enable")
lastfm_track_start = ref(0.)

def lastfm(action, m, extra="") =
	keep = ["artist", "title", "album", "albumartist", "album_artist", "tracknumber", "duration"]
	data = assoc_to_json(list.filter(fun(p) -> list.mem(fst(p), keep), m))
	r = process.run(timeout=30., "node scripts/lastfm #{action} #{process.quote(data)} #{extra}")
	if r.status == "exit" and r.status.code == 0 then
		msg = string.trim(r.stdout)
		if msg != "" then print(msg) end
	else
		log.important("Last.fm #{action} failed (#{r.status}): #{string.trim(r.stderr)}")
	end
end

def scrobble_nowplaying(m)
	if lastfm_enabled then
		lastfm("nowplaying", m)
	end
	if confbool("tunein.enable") then
		print("Scrobbling now playing to TuneIn")
		tunein_nowplaying(partner_id=confstr("tunein.partnerId"), partner_key=confstr("tunein.partnerKey"), station_id=confstr("tunein.stationId"), m)
	end
end

# send metadata to server and print the response
def send_metadata(m)
	data = assoc_to_json(m)
	# print("Sending metadata: "^data)
	try
		resp = http.post(
			data    = data,
			headers = [("Content-Type", "application/json; charset=utf-8")],
			timeout = 10.0,
			"#{serverurl}/internal/meta"
		)
		print("META: #{resp.status_code} #{resp}")
	catch e do
		print("META: could not reach server at #{serverurl}: #{e.message}")
	end
end

def update_nowplaying(m)
	# drop embedded cover art (binary) and liquidsoap-internal fields
	m = list.filter(fun(p) -> not list.mem(fst(p), ["cover", "picture", "apic", "metadata_block_picture", "coverart"]), m)

	m =
		if m != [] then
			list.set_list([
				("start", string(time())),
				("on_air", time.string("%Y/%m/%d %H:%M:%S"))
			], m)
		else
			m
		end

	meta := m

	# keep a short history for the "history.get" command
	h = list.cons(m, history())
	history := if list.length(h) > history_size then list.prefix(history_size, h) else h end

	send_metadata(m)
end

server.register(
	usage="sendmetadata",
	description="Triggers a HTTP request to the server with metadata.",
	"sendmetadata",
	fun(_) -> begin
		send_metadata(meta())
		"OK!"
	end
)

# replacement for store_metadata(id="history") from Liquidsoap 1.x
server.register(
	usage="history.get",
	description="Show the metadata of the last played tracks.",
	"history.get",
	fun(_) -> begin
		def fmt(acc, m) =
			let (i, acc_out) = acc
			lines = list.map(fun(p) -> "#{fst(p)}=#{json.stringify(snd(p))}", list.rev(m))
			(i + 1, acc_out ^ "--- #{i} ---\n" ^ string.concat(separator="\n", lines) ^ "\n")
		end
		let (_, res) = list.fold(fmt, (1, ""), history())
		res
	end
)

def auth_live(login)
	print("LIVE: A user is connecting...")
	current_token = live_token()

	if current_token == "" or current_token == login.password or live_busy() == false then
		ret =
			try
				data = http.post(
					data    = json.stringify(compact=true, {username=login.user, password=login.password}),
					headers = [("Content-Type", "application/json; charset=utf-8")],
					timeout = 5.0,
					"#{serverurl}/internal/authlive"
				)
				if data.status_code != 200 then
					[("error", "server at #{serverurl} returned HTTP #{data.status_code}")]
				else
					let json.parse (r : [(string * string)] as json.object) = data
					r
				end
			catch e do
				[("error", "auth request failed: #{e.message}")]
			end

		if ret["error"] == "" then
			print("LIVE: User "^ret["live_username"]^" authenticated successfully")
			live_meta := ret
			live_token := login.password
			true
		else
			print("LIVE: Authentication error: "^ret["error"])
			false
		end
	else
		print("LIVE: Another user is already connected!")
		false
	end
end

def user_connected(headers)
	print("LIVE: Headers")
	print(headers)
	m = list.set_list([
		("live_ice_name", headers["ice-name"]),
		("live_ice_description", headers["ice-description"]),
		("live_ice_genre", headers["ice-genre"]),
		("live_ice_url", headers["ice-url"])
	], live_meta())

	# cleanup
	def keep(x)
		value = snd(x)
		not (value == "" or value == "(none)" or value == " ")
	end

	live_meta := list.filter(keep, m)
end

def user_disconnected()
	m = live_meta()
	print("LIVE: User "^m["live_username"]^" disconnected")
end


# playlists
# entries can be absolute or relative to general.media_dir (see media: protocol)
default = stereo(mksafe(playlist(id="default", reload_mode="seconds", reload=600, prefix="media:", "/data/audio/playlists/radio.m3u")))
#extra = stereo(playlist(id="extra", reload_mode="seconds", reload=600, prefix="media:", "/data/audio/playlists/extra.m3u"))
#friendship = stereo(amplify(1.1, playlist(id="friendship", reload_mode="watch", "friendship.m3u")))

# queues: requests; announce: plays over music
# (request.queue registers <id>.push, <id>.queue, <id>.skip ... telnet commands)
queue1 = stereo(request.queue(id="queue1", timeout=1000.))
queue2 = stereo(request.queue(id="queue2", timeout=1000.))
queue3 = stereo(request.queue(id="queue3", timeout=1000.))
announce = stereo(request.queue(id="announce", timeout=60.))

#default = random(weights=[3,1], [extra,default])

music = fallback(id="music", [queue1, queue2, queue3, default])

# scrobble music (last.fm & tunein) but not jingles, announcements or live
music.on_track(synchronous=true, fun(_) -> lastfm_track_start := time())
music.on_track(synchronous=false, scrobble_nowplaying)

# Last.fm rules: only tracks longer than 30s, scrobbled once half the track
# or 4 minutes has actually played (unknown duration: after 4 minutes).
# Position only advances while music plays, so live shows don't count.
def lastfm_threshold() =
	d = music.duration()
	if d <= 0. then
		240.
	elsif d <= 30. then
		# past the end of the track, so never reached (allow_partial=false).
		# Not `infinity`: on_position fires immediately with that.
		d + 60.
	else
		min(240., d / 2.)
	end
end

if lastfm_enabled then
	music.on_position(
		synchronous=false,
		remaining=false,
		allow_partial=false,
		position=lastfm_threshold,
		fun(_, m) -> lastfm("scrobble", m, string(int_of_float(lastfm_track_start())))
	)
end

# TODO: replace with jingles
#music = rotate(weights=[1,7], [friendship,music])

register_skip_command(command="skip", music)


# Live input
live = stereo(input.harbor(
	"/", # supporting shoutcast and icecast (empty mount) sources
	id = "live",
	buffer = 10.,
	max = 15.,
	port = port_input,
	auth = auth_live,
	icy = true, # enables Shoutcast support (untested, uses port_input+1)
	icy_metadata_charset = "UTF-8",
	metadata_charset = "UTF-8",
	on_connect = user_connected,
	on_disconnect = user_disconnected
))

# insert_missing: also apply the DJ info when their client sends no metadata
live = metadata.map(id="live_meta", insert_missing=true, fun(_) -> live_meta(), live)

live = metadata.map(id="live_title", fun(m) -> begin
	if m["song"] != "" then
		info = r/(.*?) - (.*)$/.exec(m["song"])
		[("title", info[2]), ("artist", info[1])]
	elsif m["live_name"] != "" then
		[("title", m["live_name"])]
	else
		[]
	end
end, live)

# Record the live stream. The output is fallible, so it starts when a DJ
# connects and stops (closing the file) when they disconnect.
archiveEncoder = %mp3.vbr(quality=0, stereo_mode="joint_stereo", internal_quality=0, id3v2=true)

def archive_filename() =
	mm = live_meta()
	time.string("../archive/"^mm["live_username"]^"-"^mm["live_name"]^"/%Y-%m-%d/%Y-%m-%d-%H_%M_%S "^mm["live_name"]^".mp3")
end

output.file(
	id="live_archive",
	archiveEncoder,
	fallible=true,
	on_start=fun() -> begin
		live_busy := true
		print("LIVE: Starting recording...")
		# skip currently playing song
		music.skip()
		# tell the server we're live right away; the DJ's client may not
		# send any stream metadata
		m = live_meta()
		m = if m["live_name"] != "" then list.set_pair(("title", m["live_name"]), m) else m end
		thread.run(fun() -> update_nowplaying(m))
	end,
	on_stop=fun() -> begin
		print("LIVE: Stream ended!")
		live_busy := false
		live_token := ""
	end,
	on_close=fun(f) -> print("LIVE: Recording finished! #{f}"),
	archive_filename,
	live
)


def to_live(old, new)
	sequence([fade.out(duration=2., old), fade.in(duration=2., new)])
end

def to_songs(old, new)
	add(normalize=false, [
		sequence([blank(duration=3.), fade.in(duration=3., new)]),
		fade.out(duration=8., old)
	])
end

radio = fallback(id="main", track_sensitive=false, transition_length=8., transitions=[to_live, to_songs], [live, music])

radio = metadata.map(id="mediainfo", fun (m) -> begin
	if m["filename"] != "" then
		try
			let json.parse (r : [(string * string)] as json.object) =
				process.read("node scripts/metadata "^process.quote(m["filename"]))
			r
		catch _ do
			[]
		end
	else
		[]
	end
end, radio)

# update now playing (and generate cover art..)
radio.on_metadata(synchronous=false, update_nowplaying)

# crossfade songs!
radio = crossfade(fade_in=2., fade_out=3., width=5., radio)

# play announcements over the music
radio = smooth_add(duration=0.3, p=0.3, normal=radio, special=amplify(1.5, nrj(announce)))
#radio = add(normalize=false, [radio, amplify(1.8, nrj(announce))])

# audio tweaking
#radio = normalize(gain_max=3., gain_min=-3., radio)


%include "outputs.liq"
#output.dummy(radio)
