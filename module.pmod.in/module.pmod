constant __author = "Bill Welliver <hww3@riverweb.com>";
constant __version = "1.0";

//! This is a parser for RSS files. Versions 0.92, 1.0 and 2.0 are 
//! supported.

import Public.Parser.XML2;

constant V10_NS = "http://purl.org/rss/1.0/";

//!
Channel parse(string xml)
{
  string version;
  Node rss_node;
  Node n = parse_xml(xml);

//  if(n->get_node_type() != XML_ROOT) error("invalid XML provided!\n");

  // we should look at the children; one of them must be the RSS element
  do
  {
    if(n->get_node_name() == "rss")
    {
      // eureka! we have found RSS! let's make sure it's a valid version...
      if(n->get_attributes()["version"])
      {
        version=n->get_attributes()["version"];
        rss_node=n;
        break;
      }    
    }

    if(n->get_node_name() == "RDF" && n->get_nss()["_default"] && 
          n->get_nss()["_default"]== V10_NS)
    {
      // eureka! we have found RSS 1.0! let's make sure it's a valid version...
      version="1.0";
      rss_node=n;
        break;
    }
    n = n->next();
  } while(n);
  
  if(!rss_node) error("no rss element present!\n");

  return Channel(rss_node, version);

}

//!
class Thing
{
  constant V10_NS = "http://purl.org/rss/1.0/";
  constant V20_NS = 0;
 
  string RSS_VER_CORE;

  static string type = "Thing";

  static multiset element_required_elements = (<>);
  static multiset element_subelements = (<>);

//!
  mapping data=([]);

  string version;

  final string _sprintf(int m)
  {
    if(data && data->title)
      return type + "(" + (data->title[0]||"") + ")";
    else return type + "(UNDEFINED)";
  }

  string get_element_text(Node xml)
  {
        return xml->get_text();
  }

  void set_version(string version)
  { 
    if(version="1.0") RSS_VER_CORE = V10_NS;
    else RSS_VER_CORE = 0;

    this->version = version;
  }

  static void create(void|Node xml, void|string version)
  {
    // let's look at each element.

    if(version);
      set_version(version);

    if(xml == UNDEFINED) return;

    foreach(xml->children(); int index; Node child)
    {
      if(child && child->get_node_type() == 1)
      {
         string e = child->get_node_name();
         string v;
        if(child->get_ns() && child->get_ns()!=RSS_VER_CORE)
        {
          handle_ns_element(child, child->get_ns(), version);
        }
	else if(element_subelements[e])
        {
          call_function(this_object()["parse_" +e], child, version);
        }
        else
        { 
          v = get_element_text(child);

          if(! data[e]) data[e] = ({});

          data[e] += ({ v });

        }

        element_required_elements-=(<e>);
      }

    }
     if(sizeof(element_required_elements))
       error("Incomplete " + type + " definition: missing " + ((array)(element_required_elements)*" ") + "\n");
  }

  static void handle_ns_element(Node element, string ns, string version)
  {
  }

}

//!
class Item
{
  inherit Thing;

  string type = "Item";
  static multiset element_subelements = (<"enclosure", "source", 
                                           "category", "guid"
					   "comments", "author", "pubDate">);

  static void create(void|Node xml, void|string version)
  {
write("create item\n");
    ::create(xml, version);

    if(xml != UNDEFINED)     
      if(!(data["title"] || data["description"]))
        error("Incomplete " + type + " definition: title or description must be provided.\n");
  }

  void parse_enclosure(Node xml, string version)
  {
    mapping a = xml->get_attributes();

    if(!(a->url && a->length && a->type))
      error("Error in " + type + " definition: enclosure is malformed.\n");

    data->enclosure = ([ "url": a->url, "length": a->length, "type": a->type ]);

  }

//!
  void set_enclosure(string url, string length, string type)
  {
    data->enclosure = ([ "url": url, "length": length, "type": type ]);

  }

//! we can have more than one category.
  void add_category(string name, string domain)
  {    
    if(!data->category) data->category = ({});
    data->category = ({ ([name: domain]) });
  }

//!
  void set_source(string name, string url)
  {
    data->source = ([name: url]);
  }

//!
  void set_guid(string name, int(0..1) permalink)
  {
    data->guid = ([name: permalink]);
  }

//!
  void set_author(string author)
  {
    data->author = author;
  }

//!
  void set_comments(string comments)
  {
    data->comments = comments;
  }

//!
  void set_pubDate(string pubDate)
  {
    data->pubDate = pubDate;
  }

  void parse_source(Node xml, string version)
  {
    string e, v;

    mapping a = xml->get_attributes();
    if(!a["url"]) error("Error in Item: source must provide a url.\n");

    v = a["url"];
  
    e = get_element_text(xml);
    
    data->source = ([e: v]);
  }
  
  void parse_category(Node xml, string version)
  {
    string e, v;

    mapping a = xml->get_attributes();
    if(a["domain"]) v = a["domain"];

    e = get_element_text(xml);

    if(!data->category) data->category = ({});

    data->category += ({ ([e: v]) });
  }

  void parse_comments(Node xml, string version)
  {
    string e, v;

    e = get_element_text(xml);

    data->comments = e;
  }

  void parse_author(Node xml, string version)
  {
    string e, v;

    e = get_element_text(xml);

    data->author = e;
  }
  
  void parse_pubDate(Node xml, string version)
  {
    string e, v;

    e = get_element_text(xml);

    data->pubDate = e;
  }
  
  void parse_guid(Node xml, string version)
  {
    string e; int v;

    mapping a = xml->get_attributes();
    if(a["isPermaLink"]) v = 1;

    e = get_element_text(xml);

    data->guid = ([e: v]);
    
  }
}

//!
class Channel
{
  inherit Thing;
  
  string type = "Channel";

  multiset element_required_elements = (<"title", "link", "description">);
  multiset element_subelements = (<"image", "cloud", "category">);

//!
  array(Item) items = ({});

  void create(Node|void xml, void|string _version)
  {
    if(version=="1.0") element_required_elements += (< "items">);
    if(version=="1.0") element_subelements += (< "items", "textinput">);
    else if(version=="2.0") element_subelements += (< "item", "textInput" >);
    else if(version=="0.91") element_subelements += (< "item" >);


/*
    if(xml == UNDEFINED)
    { 
      return;
    }
*/
    // next, we should look for channels.
    foreach(xml->children(); int index; Node child)
    {
write(child->get_node_name() + "\n");
      if(child->get_node_name() == "channel")
      {
        ::create(child, version);
        create(child, version);
      }
      if(child->get_node_name() == "item")
      {
        items+=({ Item(child, version) });
      }

    }

  }

  function parse_textInput = parse_textinput;

//!
  void add_item(Item i)
  {
    items += ({ i });
  }

  void parse_textinput(Node xml, string version)
  {
    mapping d = ([]);

    multiset required_elements = (<"title", "description", "name", "link">);
    
    foreach(xml->children() || ({}); int index; Node child)
    {

       if(child && child->get_node_type() == 1 && required_elements[child->get_node_name()])
         d[child->get_node_name()] = get_element_text(xml);

       if(!(d->link && d->name && d->description && d->title))
       {
          error("textInput missing required elements.\n");
       } 
    }
    if(! data->textInput)
      data->textInput = ({});

    data->textInput += ({ d });
  }

  void parse_items(Node xml, string version)
  {
  }

  void parse_category(Node xml, string version)
  {
    string e, v;

    mapping a = xml->get_attributes();
    if(a["domain"]) v = a["domain"];

        e = xml->get_text();

    if(!data->category) data->category = ({});
    
    data->category+=({ ([e: v]) });
  }

//!
  void add_category(string category, string description)
  {
    if(!data->category) data->category = ({});
    
    data->category+=({ ([category: description]) });
  }

  void parse_image(Node xml, string version)
  {
  }

  void parse_cloud(Node xml, string version)
  {

    mapping a = xml->get_attributes();

    if(!(a->domain && a->port && a->path && a->registerProcedure))
      error("Error in " + type + " definition: cloud is malformed.\n");

    if(!data->cloud) data->cloud = ({});
  
    data->cloud += ({ ([ "domain": a->domain, "port": a->port, "path": a->path, 
                         "registerProcedure": a->registerProcedure ]) });

  }

//!
  void add_cloud(string domain, string port, string path, string reg)
  {
    if(!data->cloud) data->cloud = ({});
  
    data->cloud += ({ ([ "domain": domain, "port": port, "path": path, 
                         "registerProcedure": reg ]) });
  }

  void parse_item(Node xml, string version)
  {
    items += ({ Item(xml, version) });
  }
}

