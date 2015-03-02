open Cow

let mk_recent ~date ~href ~author ~title : Html.t =
  <:html<
      <tr>
        <td><i>$title$</i></td>
        <td><a href="$href$">$title$</a></td>
        <td>$author$</td>
      </tr>
  >>

let mk_post ~content ~url ~title ~blog_url ~blog_title ~blog_name ~author ~date ~content : Html.t =
  <:html<
    <div class="channelgroup">
      <div class="entrygroup" id="$url$">
        <a name="$url$"> </a>
        <h1 class="posttitle">
          <a href="$url$">$title$</a>
          (<a href="$blog_url$" title="$blog_title$">$blog_name$</a>)
        </h1>
        <hr/>
        <div class="entry">
          <div class="content">
            <div>
              $content$
            </div>
          </div>
          <p class="date">
            <a href="$url$">by $author$ at $date$ </a>
          </p>
        </div>
      </div>
    </div>
  >>

let mk_post_with_face ~content ~url ~title ~blog_url ~blog_title ~blog_name ~author ~date ~content ~face ~face_height =
  <:html<
    <div class="channelgroup">
      <img style="float:right; padding-left: 20px;" class="face" src="$face$" width="" height="$face_height$" alt="" />
      <div class="entrygroup" id="$url$">
        <a name="$url$"> </a>
        <h1 class="posttitle">
          <a href="$url$">$title$</a>
          (<a href="$blog_url$" title="$blog_title$">$blog_name$</a>)
        </h1>
        <hr/>
        <div class="entry">
          <div class="content">
            <div>
              $content$
            </div>
          </div>
          <p class="date">
            <a href="$url$">by $author$ at $date$ </a>
          </p>
        </div>
      </div>
    </div>
  >>

let body ~recentList ~postList =
  <:html<
    <head> <title>Blogs</title>
    <link rel="alternate" href="http://www.cl.cam.ac.uk/projects/ocamllabs/blogs/rss10.xml" title="" type="application/rss+xml" />
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

    <div id="container">

    <h4>Recent Posts</h4>
    <table width="90%">
      $recentList$
    </table>

    $postList$
    </div>
    </body>
  >>
