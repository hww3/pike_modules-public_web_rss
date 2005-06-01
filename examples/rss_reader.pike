inherit "cachelib";

object cache;

mixed parse(RequestID id)
{
  string retval="";

  if(!cache)
    cache = caudium->cache_manager->get_cache(id->conf->query("MyWorldLocation") + "hww3.rss_reader");

  string rssurl="http://www.riverweb.com:8080/changelog/%7Erss/cvs/pike_modules/Public_Web_RSS/rss.xml";

  if(id->variables->rssurl)
    rssurl = id->variables->rssurl;

  string rss = cache->retrieve(rssurl, rss_fetch, ({rssurl}));
 
  object r = Public.Web.RSS.parse(rss);
  retval+="<h1>" + r->data->title[0] + "</h1>\n";

  foreach(r->items, object i)
  {
    retval+="<li><A href=\"" + i->data->link[0] + "\">" + 
      i->data->title[0]  + "</a>\n";
  }
 
  return retval;
}

string rss_fetch(string rssurl)
{
  string rss = Protocols.HTTP.get_url_data(rssurl);

  cache->store(cache_string(rssurl, rss, 300));

  return rss;
}
