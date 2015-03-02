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
      <p class=\"date\">
        <a href=\"%s\">by %s at %s </a>
      </p>
    </div>
  </div>
</div>
" url url url title blog_url blog_title blog_name content url author date

let mk_post_with_face ~url ~title ~blog_url ~blog_title ~blog_name ~author
                      ~date ~content ~face ~face_height : string =
  sprintf
"<div class=\"channelgroup\">
  <img style=\"float:right; padding-left: 20px;\" class=\"face\"
  src=\"%s\" width=\"\" height=\"%d\" alt=\"\" />
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
      <p class=\"date\">
        <a href=\"%s\">by %s at %s </a>
      </p>
    </div>
  </div>
</div>
" face face_height url url url title blog_url blog_title blog_name content url author date

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
  div#content-primary p img, div#content-primary img.right { float: none; }

  </style>
  </head>

  <body>

  <div id=\"container\">

  <h4>Recent Posts</h4>
  <table width=\"90%\">\n" ^ recentList ^
"</table>
" ^ postList ^
" </div>
  </body>"
