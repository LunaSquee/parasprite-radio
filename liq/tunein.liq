

# TuneIn Broadcaster API by djazz
def tunein_nowplaying(~partner_id="",~partner_key="",~station_id="",m)
	api = "http://air.radiotime.com/Playing.ashx"
	if partner_id != "" and partner_key != "" and station_id != "" then
		title = m["title"]
		artist = m["artist"]
		album = m["album"]

		if title != "" and artist != "" then
			req = "#{api}?partnerId="^url.encode(partner_id)^"&partnerKey="^url.encode(partner_key)^"&id="^url.encode(station_id)^"&title="^url.encode(title)^"&artist="^url.encode(artist)^"&album="^url.encode(album)
			try
				ignore(http.get(req))
			catch e do
				print("TuneIn request failed: #{e.message}")
			end
		end
	end
end
