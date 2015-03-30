require! <[fs cheerio request bluebird excel-parser]>


init = -> new bluebird (res, rej) ->
  (e,r,b) <- request {
    url: \http://admin.taiwan.net.tw/statistics/month.aspx?no=135
    method: \GET
  }, _
  if e or !b => return rej!
  $ = cheerio.load b.toString!
  params = {}
  for item in $("input")
    params[$(item).attr("name")] = $(item).attr("value")
  params <<< do
    # enlarge page size if it has been a long time since last update
    "ctl00$ctl00$ContentPlaceHolder1$ContentPlaceHolder1$Pager2$tbPageSize": 60
    "ctl00$ctl00$ContentPlaceHolder1$ContentPlaceHolder1$searItm": 51 # age and gendar
  res params

fetchlist = (params) -> new bluebird (res, rej) ->
  (e,r,b) <- request {
    url: \http://admin.taiwan.net.tw/statistics/month.aspx?no=135
    method: \POST
    form: params
  }, _
  if e or !b => return rej!
  $ = cheerio.load b.toString!
  urls = []
  $("a").map (idx, it) ->
    text = $(it).text!
    if !!!(/出國性別及年齡分析/.exec(text)) => return
    ret = /(\d+)\s*年\s*(\d+)\s*月/.exec text
    if !ret => return
    name = "#{ret.1}-#{if ret.2.length < 2 => \0 else ''}#{ret.2}.xls"
    urls.push {name, href: $(it).attr(\href)}
  #fs.write-file-sync \urls, JSON.stringify(urls)
  res urls

buildJSON = (name, res, rej) ->
  [infile, outfile] = ["raw/#{name}", "data/#{name.replace /\.xls/, '.json'}"]
  (e,r) <- excel-parser.parse { inFile: infile, worksheet: 3 }, _
  if r =>
    r = r.splice(1).filter(-> !(/註/.exec it.0))
    fs.write-file-sync outfile, JSON.stringify(r)
  else return rej!
  return res!

fetchFile = (item) -> new bluebird (res, rej) ->
  if fs.exists-sync("raw/#{item.name}") => return res!
  request({
    url: "http://admin.taiwan.net.tw#{item.href}"
    method: \GET
  }).pipe(fs.createWriteStream("raw/#{item.name}"))
    .on \finish, ->
      $ = cheerio.load fs.read-file-sync("raw/#{item.name}")toString!
      ret = $("a").map((idx,it) -> href = $(it).attr("href")).filter((idx,it)-> /\.xls$/.exec it).0
      if !ret => return buildJSON item.name, res, rej
      request({
        url: ret
        method: \GET
      }).pipe(fs.createWriteStream("raw/#{item.name}"))
        .on \finish, -> return buildJSON item.name, res, rej
        .on \error, -> return rej!
    .on \error, -> return rej!

_fetchFiles = (urls, res, rej) ->
  if urls.length == 0 => return res!
  url = urls.splice(0,1).0
  console.log "downloading #{url.name}..."
  fetchFile url 
    .then -> _fetchFiles urls, res, rej
    .catch -> 
      console.log "failed (#{url.name})"
      _fetchFiles urls, res, rej

fetchFiles = (urls) -> new bluebird (res, rej) ->
  _fetchFiles urls, res, rej

if !fs.exists-sync(\raw) => fs.mkdir-sync \raw
if !fs.exists-sync(\data) => fs.mkdir-sync \data

console.log "prepare http parameters..."
init!
  .then (params) ->
    console.log "retrieve xls urls..."
    fetchlist params
      .then (urls) ->
        console.log "total #{urls.length} links. downloading..."
        fetchFiles urls
          .then -> console.log "complete."
          .catch -> console.log "failed"
      .catch -> console.log "failed to get xls links."
  .catch -> console.log "failed to retrieve the web page."
