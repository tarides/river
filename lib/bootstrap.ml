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
