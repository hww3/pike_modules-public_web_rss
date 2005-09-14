inherit "cachelib";
constant thread_safe=1;
#include <module.h>

inherit "module";
inherit "caudiumlib";

object conf;
object cache;

constant module_type = MODULE_PROVIDER|MODULE_PARSER;
constant module_name = "Emit: RSS";
constant module_doc  = "Provides an emit plugin for RSS files"
			"<p>Plugin name: rss<p>Arguments:<p> <b>url</b> - the url to load " 
"(file:///local/paths.xml or http://domain.com/remote/paths.xml<br>"
"<b>timeout</b> - number of seconds to cache the file" ;


mixed rss_fetch(string rssurl, int timeout)
{
  string rss;
  object r;

  if(has_prefix(rssurl, "file://"))
    rss = Stdio.read_file(rssurl[7..]);

  else rss = Protocols.HTTP.get_url_data(rssurl);

  if(rss && sizeof(rss))
    catch(r = Public.Web.RSS.parse(rss));

  if(r)
    cache->store(cache_pike(rssurl, r, timeout));

  return r;
}

array emit_rss(mapping args, object request_id)
{
  
  request_id->misc->cacheable=0;

  if(!cache)
    cache = caudium->cache_manager->get_cache(
               request_id->conf->query("MyWorldLocation") + "-emit_rss");

  if(!args->url) error("No RSS soruce URL provided.");

  object r = cache->retrieve(args->url, rss_fetch, ({args->url, 
         (int)(args->timeout || 1800) }));


  array retval = ({});
  Public.Web.RSS.Item item;
  if(r)
    foreach(r->items, item)
    {
      mapping d = ([]);

      d->rsschannel = r->data->title;
  
      d+=copy_value(item->data);

      retval += ({d});
    }

  return retval;
}

mixed query_emit_callers()
{
  return (["rss": emit_rss]);
}
