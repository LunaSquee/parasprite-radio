# protocols

def first_line(lines)
	lines = list.filter(fun(l) -> string.trim(l) != "", lines)
	if lines == [] then null else string.trim(list.hd(lines)) end
end

# uses an external script to handle anything thrown at it!
def smart_protocol(~rlog:_, ~maxtime, arg)
	res = process.read.lines(timeout=maxtime - time(), "node scripts/smart "^process.quote(arg))
	print(res)
	first_line(res)
end
protocol.add("smart", smart_protocol, doc="Resolve URLs (YouTube, SoundCloud, ...) using scripts/smart.js", syntax="smart:url")

# copy: (copy a file to a temporary location before playing, used for
# NFS/SMB) is built into Liquidsoap 2.x now.

# Playlist entries may be absolute or relative to general.media_dir
# (MPD saves relative paths), so resolve both.
def media_protocol(~rlog:_, ~maxtime:_, arg)
	if string.sub(arg, start=0, length=1) == "/" then
		arg
	else
		confstr("general.media_dir")^"/"^arg
	end
end
protocol.add("media", static=fun(_) -> true, media_protocol, doc="Path relative to general.media_dir", syntax="media:path")

# say: is built in; use festival's text2wave (installed in the docker image)
settings.protocol.say.implementation := "text2wave"
