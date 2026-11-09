
confsrc = process.read("node scripts/get-config")

config =
  try
    let json.parse (c : [(string * string)] as json.object) = confsrc
    c
  catch _ do
    print("Failed to parse config JSON:")
    print(confsrc)
    shutdown()
    []
  end

def confstr(key, default="") =
  c = config[key]
  if c == "" then default else c end
end
def confint(key, default=0) = string.to_int(default=default, config[key]) end
def conffloat(key, default=0.0) = string.to_float(default=default, config[key]) end
def confbool(key, default=false) =
  c = config[key]
  if c == "" then default else c == "true" end
end
