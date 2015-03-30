require! <[fs]>

files = fs.readdir-sync \data .map -> [it.replace(/\.json/, ""), "data/#it"]
hash = {}
for file in files => hash[file.0] = JSON.parse(fs.read-file-sync file.1 .toString!)
result = {}
for k,v of hash =>
  hint = v.splice(0,1).0
  continent = []
  country = []
  for idx from 0 til hint.length => hint[idx] = hint[idx].split \\n .0
  for item in v =>
    item.0 = item.0.replace /\s+.*$/, ""
    item.1 = item.1.replace /\s+.*$/, ""
    if item.0 => cur = item.0 else item.0 = cur
    if item.1 => country.push item else continent.push item
    for idx from 2 til item.length => item[idx] = parseInt(item[idx])
  result[k] = {country, continent, hint}

fs.write-file-sync \summary.json, JSON.stringify(result)
