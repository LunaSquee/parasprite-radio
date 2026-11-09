
# since liquidsoap doesn't have list[key] = value
# this keeps the assoc list clean of duplicate keys
# usage: list.set_pair((key, value), list)
def list.set_pair(p, l)
	l = list.assoc.remove(fst(p), l)
	list.cons(p, l)
end

# same as above but takes a list of pairs instead
def list.set_list(new, l)
	outl = ref(l)
	list.iter(fun(p) -> outl := list.assoc.remove(fst(p), outl()), new)
	list.append(new, outl())
end

# turn an assoc list into a JSON object string
def assoc_to_json(m)
	j = json.object()
	list.iter(fun(p) -> j.add(fst(p), snd(p)), m)
	json.stringify(compact=true, j)
end

# Add a skip function to a source
# when it does not have one
# by default
def register_skip_command(~command, s)
	# Register the command:
	server.register(
		description="Skip the current song in source.",
		command,
		fun(_) -> begin
			print("Skipping...")
			s.skip()
			"OK!"
		end
	)
end
