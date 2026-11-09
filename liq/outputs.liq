icecast_encoding = confstr("icecast.encoding", "")

def icecast_out(~id, ~mount, ~start=true, ~send_icy_metadata=null, ~format="", enc, s) =
	output.icecast(
		id = id,
		mount = mount,
		start = start,
		send_icy_metadata = send_icy_metadata,
		format = format,

		host     = confstr("icecast.host", "localhost"),
		port     = confint("icecast.port", 8000),
		user     = confstr("icecast.mount.user", "source"),
		password = confstr("icecast.mount.password", "hackme"),

		name        = confstr("radio.title", "Parasprite Radio"),
		description = confstr("radio.description", "Liquidsoap Radio!"),
		url         = confstr("radio.url", "https://www.liquidsoap.info/"),
		genre       = confstr("radio.genre", "Misc"),
		encoding    = (icecast_encoding == "" ? null : icecast_encoding),

		connection_timeout = 20.,
		fallible = true,
		enc,
		s
	)
end

# HLS streams (ffmpeg, see scripts/streams.sh)
def streams(s) =
	output.external(id="radio_streams",
		%wav(header=false, samplerate=48000),
		start=true,
		fallible=true,
		"scripts/streams.sh",
		s
	)
end

# Unused extras from the 1.x setup, kept for reference:
# - mumble: output.external(%external(channels=1, samplerate=48000, header=false,
#     restart_on_crash=true, process="node scripts/mumble.js"), "true", source)
# - alsa:   output.external(%wav(header=false), "aplay -f cd -", source)
# - opus via oggfwd: opusenc --quiet - - | oggfwd ... /radio_opus3

if inDev then
	streams(radio)
else
	streams(radio)

	icecast_out(
		id = "radio",
		mount = "radio",
		%mp3(
			bitrate = 320,
			stereo = true,
			stereo_mode = "joint_stereo",
			internal_quality = 0,
			id3v2 = true,
			samplerate = 48000
		),
		start = true,
		radio
	)

#	icecast_out(
#		id = "radio_mobile",
#		mount = "radio_mobile",
#		%fdkaac(
#			channels = 2,
#			samplerate = 48000,
#			bitrate = 64,
#			afterburner = true,
#			aot = "mpeg2_he_aac_v2"
#		),
#		start = false,
#		radio
#	)

	icecast_out(
		id = "radio_mobile_vorbis",
		mount = "radio_mobile_vorbis",
		%vorbis(
			channels = 2,
			quality = 0.1
		),
		start = false,
		radio
	)

	icecast_out(
		id = "radio_opus2",
		mount = "radio_opus2",
		%opus(
			vbr = "constrained",
			application = "audio",
			complexity = 10,
			max_bandwidth = "full_band",
			samplerate = 48000,
			frame_size = 20.,
			bitrate = 128,
			channels = 2,
			signal = "music"
		),
		start = false,
		merge_tracks(radio)
	)

	# a better OPUS encoder
	icecast_out(
		id = "radio_opus",
		mount = "radio_opus",
		%external(
			channels = 2,
			samplerate = 48000,
			header = true,
			restart_on_crash = true,
			"opusenc --ignorelength - -"
		),
		send_icy_metadata = false,
		format = "audio/ogg",
		start = false,
		merge_tracks(radio)
	)

	# a better FLAC encoder
#	icecast_out(
#		id = "radio_flac",
#		mount = "radio_flac",
#		%external(
#			channels = 2,
#			samplerate = 48000,
#			header = true,
#			restart_on_crash = true,
#			"flac --best --ogg --silent --stdout -"
#		),
#		send_icy_metadata = false,
#		format = "audio/ogg",
#		start = false,
#		radio
#	)
end
