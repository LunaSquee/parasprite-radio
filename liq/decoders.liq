
# Decode music modules using the xmp binary: render them to a temporary
# wav file which liquidsoap then plays with its native decoder.
def xmp_decoder(~rlog, ~maxtime, fname)
	tmp = file.temp("xmp", ".wav")
	r = process.run(
		timeout=maxtime - time(),
		"xmp --nocmd -o #{process.quote(tmp)} -d wav #{process.quote(fname)} "
	)
	if r.status == "exit" and r.status.code == 0 then
		tmp.{temporary=true}
	else
		rlog("xmp failed: #{r.status} #{r.status.code} #{r.stderr}")
		file.remove(tmp)
		null
	end
end

decoder.add(
	name="XMP",
	description="Decode music modules using the xmp binary",
	file_extensions=["mod","s3m","xm","it","j2b"],
	xmp_decoder
)
