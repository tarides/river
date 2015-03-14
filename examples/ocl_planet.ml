open Planet
open Nethtml
open Printf

let mk_recent ~date ~url ~author ~title : string =
  sprintf
"<tr>
    <td><i> %s </i></td>
    <td><a href=\"#%s\">%s</a></td>
    <td>%s</td>
 </tr>
" date url title author

let mk_post ~url ~title ~blog_url ~blog_title ~blog_name ~author
            ~date ~content : string =
  sprintf
"<div class=\"channelgroup\">
  <div class=\"entrygroup\" id=\"%s\">
    <a name=\"#%s\"> </a>
    <h1 class=\"posttitle\">
      <a href=\"%s\">%s</a>
      (<a href=\"%s\" title=\"%s\">%s</a>)
    </h1>
    <hr/>
    <div class=\"entry\">
      <div class=\"content\">
        <div>
          %s
        </div>
      </div>
      <div>
      <p class=\"date\">
        <a href=\"%s\">by %s at %s </a>
      </p>
      </div>
    </div>
  </div>
</div>
" url url url title blog_url blog_title blog_name content url author date

let mk_post_with_face ~url ~title ~blog_url ~blog_title ~blog_name ~author
                      ~date ~content ~face ~face_height : string =
  sprintf
"<div class=\"channelgroup\">
  <div class=\"entrygroup\" id=\"%s\">
    <a name=\"#%s\"> </a>
    <div>
    <img style=\"float:right; padding-left: 20px;\" class=\"face\" src=\"%s\" width=\"\" height=\"%d\" alt=\"\" />
    <h1 class=\"posttitle\">
      <a href=\"%s\">%s</a>
      (<a href=\"%s\" title=\"%s\">%s</a>)
    </h1>
    </div>
    <hr/>
    <div class=\"entry\">
      <div class=\"content\">
        <div>
          %s
        </div>
      </div>
      <div>
      <p class=\"date\">
        <a href=\"%s\">by %s at %s </a>
      </p>
      </div>
    </div>
  </div>
</div>
" url url face face_height url title blog_url blog_title blog_name content url author date

let mk_body ~recentList ~postList : string =
"<head> <title>Blogs</title>
  <link rel=\"alternate\" href=\"http://www.cl.cam.ac.uk/projects/ocamllabs/blogs/rss10.xml\" title=\"\" type=\"application/rss+xml\" />
  <style>
      a.icon-github {
    background: url(../github.png) no-repeat 0 0;
          background: url(../github.png) no-repeat 0 0;
    padding: 0 0 2px 2em;
      }
      a.icon-cloud {
    background: url(../cloud.png) no-repeat 0 0;
          background-size: 17px;
    padding: 0 0 2px 2em;
      }
      a.icon-bullhorn {
    background: url(../bullhorn.png) no-repeat 0 0;
          background-size: 17px;
    padding: 0 0 2px 2em;
      }
      a.icon-wrench {
    background: url(../wrench.png) no-repeat 0 0;
          background-size: 17px;
    padding: 0 0 2px 2em;
      }
      h2.posttitle {
          font-size: 120%;
      }
  div.toc {
      background-color: rgb(239, 239, 239);
      margin: 0.5em 0em 1.5em 1px;
      border: 1px solid black;
      font-size: 0.7em;
      padding: 0px 0px 1ex;
      font-size: 100%;
  }
    a.planet-toggle {
      font-size: 90%;
      padding: 5px 10px;
      margin-bottom: 2ex;
      color: #4b4b4b;
      background: #e6e6e6;
      border: 1px solid #dedede;
    }

    a.planet-toggle:hover, a.planet-toggle:focus {
      color: #ffffff;
      background: #c77a27;
    }

    .btn {
      display: inline-block;
      color: #ffffff;
      *display: inline;
      /* IE7 inline-block hack */

      *zoom: 1;
      padding: 10px 20px;
      margin-bottom: 0;
      font-family: Lato, sans-serif;
      font-weight: bold;
      font-size: 18px;
      line-height: 28px;
      text-align: center;
      vertical-align: middle;
      cursor: pointer;
      background: #8eaf20;
      border: 1px solid #8eaf20;
      *border: 0;
      -webkit-border-radius: 4px;
      -moz-border-radius: 4px;
      border-radius: 4px;
      *margin-left: .3em;
      text-shadow: rgba(0, 0, 0, 0.34) 1px 1px 2px;
      -webkit-box-shadow: rgba(0, 0, 0, 0.46) 0 2px 2px;
      -moz-box-shadow: rgba(0, 0, 0, 0.46) 0 2px 2px;
      box-shadow: rgba(0, 0, 0, 0.46) 0 2px 2px;
    }
    .btn:first-child {
      *margin-left: 0;
    }
    .btn:hover,
    .btn:focus {
      color: #ffffff;
      text-decoration: none;
      background-position: 0 -15px;
      -webkit-transition: background-position 0.1s linear;
      -moz-transition: background-position 0.1s linear;
      -o-transition: background-position 0.1s linear;
      transition: background-position 0.1s linear;
    }
    .btn:focus {
      outline: none;
    }
    .btn.active,
    .btn:active {
      background-image: none;
      outline: 0;
      -webkit-box-shadow: inset 0 2px 4px rgba(0,0,0,.15), 0 1px 2px rgba(0,0,0,.05);
      -moz-box-shadow: inset 0 2px 4px rgba(0,0,0,.15), 0 1px 2px rgba(0,0,0,.05);
      box-shadow: inset 0 2px 4px rgba(0,0,0,.15), 0 1px 2px rgba(0,0,0,.05);
    }
    .btn.disabled,
    .btn[disabled] {
      cursor: default;
      background-image: none;
      opacity: 0.65;
      filter: alpha(opacity=65);
      -webkit-box-shadow: none;
      -moz-box-shadow: none;
      box-shadow: none;
    }

  div#content-primary p img, div#content-primary img.right { float: none; }

  </style>
  <script type = \"text/javascript\">
    function switchContent(id1,id2) {
     // Get the DOM reference
     var contentId1 = document.getElementById(id1);
     var contentId2 = document.getElementById(id2);
     // Toggle
     contentId1.style.display = \"none\";
     contentId2.style.display = \"block\";
     }
  </script>
  </head>

  <body>

  <div id=\"container\">

  <h4>Recent Posts</h4>
  <table width=\"90%\">\n" ^ recentList ^
"</table>
" ^ postList ^
" </div>
  </body>"

let encode_document html = Nethtml.encode ~enc:`Enc_utf8 html

let date_of_post p =
  match p.date with
  | None -> "<Date Unknown>"
  | Some d ->
       let open Syndic.Date in
       sprintf "%s %02d, %d" (string_of_month(month d)) (day d) (year d)

let rec length_html html =
  List.fold_left (fun l h -> l + length_html_el h) 0 html
and length_html_el = function
  | Element(_, _, content) -> length_html content
  | Data d -> String.length d

let new_id =
  let id = ref 0 in
  fun () -> incr id; sprintf "ocamlorg-post%i" !id

(* [toggle html1 html2] return some piece of html with buttons to pass
   from [html1] to [html2] and vice versa. *)
let toggle ?(anchor="") html1 html2 =
  let button id1 id2 text =
    Element("a", ["onclick", sprintf "switchContent('%s','%s')" id1 id2;
                  "class", "btn planet-toggle";
                  "href", "#" ^ anchor],
            [Data text])
  in
  let id1 = new_id() and id2 = new_id() in
  [Element("div", ["id", id1],
           html1 @ [button id1 id2 "Read more..."]);
   Element("div", ["id", id2; "style", "display: none"],
           html2 @ [button id2 id1 "Hide"])]


let write_posts ?num_posts ?ofs ~out_file in_file =
  let posts = get_posts ?n:num_posts ?ofs in_file in
  let recentList =
    List.map (fun p ->
      let date = date_of_post p in
      let title = p.title in
      let url = match p.link with
        | Some u -> Uri.to_string u
        | None -> Digest.to_hex (Digest.string (p.title)) in
      let author = p.author in
      mk_recent date url author title) posts in
  let postList =
    List.map (fun p ->
      let title = p.title in
      let date = date_of_post p in
      let url = match p.link with
        | Some u -> Uri.to_string u
        | None -> Digest.to_hex (Digest.string (p.title)) in
      let author = p.author in
      let blog_name = p.contributor.name in
      let blog_title = p.contributor.title in
      let blog_url = p.contributor.url in
      (* Write contents *)
      let buffer = Buffer.create 0 in
      let channel = new Netchannels.output_buffer buffer in
      let desc = if length_html p.desc < 1000 then p.desc
                else toggle (prefix_of_html p.desc 1000) p.desc ~anchor:url in
      let _ = Nethtml.write channel @@ encode_document desc in
      let content = Buffer.contents buffer in
      mk_post url title blog_url blog_title blog_name author date content)
    posts in
  let body = mk_body (String.concat "\n" recentList)
                     (String.concat "\n<br/><br/><br/>\n" postList) in
  (* write to file *)
  let f = open_out out_file in
  let () = output_string f body in
  close_out f

let main () =
  let in_file = "examples/data_blog.txt" in
  let out_file = "index.html" in
  write_posts ?num_posts:(Some 50) ~out_file:out_file in_file

let () = main ()
