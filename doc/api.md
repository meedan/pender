### API

#### GET /api/about

Use this method to get the archivers enabled on this application

**Parameters**


**Response**

200: Information about the application
```json
{
  "type": "about",
  "data": {
    "name": "Keep",
    "archivers": [
      {
        "key": "archive_org",
        "label": "Archive.org"
      }
    ]
  }
}
```

401: Access denied
```json
{
  "type": "error",
  "data": {
    "message": "Unauthorized",
    "code": 1
  }
}
```


#### DELETE|PURGE /api/medias

Delete cache for the URL(s) passed as parameter, you can use the HTTP verbs DELETE or PURGE

**Parameters**

* `url`: URL(s) whose cache should be delete... can be an array of URLs, a single URL or a list of URLs separated by a space _(required)_

**Response**

200: Success
```json
{
  "type": "success"
}
```

401: Access denied
```json
{
  "type": "error",
  "data": {
    "message": "Unauthorized",
    "code": 1
  }
}
```


#### POST /api/medias

Create background jobs to parse each URL and notify the caller with the result

**Parameters**

* `url`: URL(s) to be parsed. Can be an array of URLs, a single URL or a list of URLs separated by commas
 _(required)_
* `refresh`: Force a refresh from the URL instead of the cache. Will be applied to all URLs
* `archivers`: List of archivers to target. Can be empty, `none` or a list of archives separated by commas. Will be applied to all URLs

**Response**

200: Enqueued URLs
```json
{
  "type": "success",
  "data": {
    "enqueued": [
      "https://www.youtube.com/user/MeedanTube",
      "https://twitter.com/meedan"
    ],
    "failed": [

    ]
  }
}
```

401: Access denied
```json
{
  "type": "error",
  "data": {
    "message": "Unauthorized",
    "code": 1
  }
}
```


#### GET /api/medias

Get parseable data for a given URL, that can be a post or a profile, from different providers

**Parameters**

* `url`: URL to be parsed/rendered _(required)_
* `refresh`: Force a refresh from the URL instead of the cache
* `archivers`: List of archivers to target. Can be empty, `none` or a list of archives separated by commas

**Response**

200: Parsed data
```json
{
  "type": "media",
  "data": {
    "published_at": "2009-03-06T00:44:31.000Z",
    "username": "meedantube",
    "title": "MeedanTube",
    "description": "",
    "picture": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
    "author_url": "",
    "author_picture": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
    "author_name": "MeedanTube",
    "screenshot": "",
    "raw": {
      "metatags": [
        {
          "http-equiv": "origin-trial",
          "data-feature": "Media Capabilities",
          "data-expires": "2018-04-12",
          "content": "AjLq5uNF7MpG/eM34tWcJD3h8yZY1Q72ckfwdKbUNKGtUNaZkrw55eq2tI60vG0IlsCNw33W9WmuV113EAsdHAwAAABpeyJvcmlnaW4iOiJodHRwczovL3lvdXR1YmUuY29tOjQ0MyIsImZlYXR1cmUiOiJNZWRpYUNhcGFiaWxpdGllcyIsImV4cGlyeSI6MTUyMzQ5MTIwMCwiaXNTdWJkb21haW4iOnRydWV9"
        },
        {
          "http-equiv": "origin-trial",
          "data-feature": "Long Task Observer",
          "data-expires": "2017-04-17",
          "content": "AgXf9faUpH8YmYNhInb5nw8BxXZaT8pZlj3At6FUrcvdBzs0I8VxKDkfinT4bbXfPZX8lXKfjotQZrhFVnpzFwYAAABZeyJvcmlnaW4iOiJodHRwczovL3d3dy55b3V0dWJlLmNvbTo0NDMiLCJmZWF0dXJlIjoiTG9uZ1Rhc2tPYnNlcnZlciIsImV4cGlyeSI6MTQ5MjQ3MzYwMH0="
        },
        {
          "property": "og:site_name",
          "content": "YouTube"
        },
        {
          "property": "og:url",
          "content": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ"
        },
        {
          "property": "og:title",
          "content": "MeedanTube"
        },
        {
          "property": "og:description"
        },
        {
          "property": "og:image",
          "content": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s200-mo-c-c0xffffffff-rj-k-no"
        },
        {
          "name": "apple-itunes-app",
          "content": "app-id=544007664",
          "app-argument": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ"
        },
        {
          "property": "al:ios:app_store_id",
          "content": "544007664"
        },
        {
          "property": "al:ios:app_name",
          "content": "YouTube"
        },
        {
          "property": "al:ios:url",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=applinks"
        },
        {
          "property": "al:android:url",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=applinks"
        },
        {
          "property": "al:android:app_name",
          "content": "YouTube"
        },
        {
          "property": "al:android:package",
          "content": "com.google.android.youtube"
        },
        {
          "property": "al:web:url",
          "content": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=applinks"
        },
        {
          "property": "al:web:should_fallback",
          "content": "true"
        },
        {
          "property": "og:type",
          "content": "yt-fb-app:channel"
        },
        {
          "property": "og:video:tag",
          "content": "Meedan"
        },
        {
          "property": "og:video:tag",
          "content": "Arabic"
        },
        {
          "property": "og:video:tag",
          "content": "English"
        },
        {
          "property": "og:video:tag",
          "content": "language"
        },
        {
          "property": "og:video:tag",
          "content": "translation"
        },
        {
          "property": "og:video:tag",
          "content": "social"
        },
        {
          "property": "og:video:tag",
          "content": "media"
        },
        {
          "property": "og:video:tag",
          "content": "news"
        },
        {
          "property": "og:video:tag",
          "content": "currentaffairs"
        },
        {
          "property": "og:video:tag",
          "content": "nonprofit"
        },
        {
          "property": "og:video:tag",
          "content": "dialogue"
        },
        {
          "property": "fb:app_id",
          "content": "87741124305"
        },
        {
          "property": "og:restrictions:age",
          "content": "18+"
        },
        {
          "name": "twitter:card",
          "content": "summary"
        },
        {
          "name": "twitter:site",
          "content": "@YouTube"
        },
        {
          "name": "twitter:url",
          "content": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ"
        },
        {
          "name": "twitter:title",
          "content": "MeedanTube"
        },
        {
          "name": "twitter:description"
        },
        {
          "name": "twitter:image",
          "content": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s200-mo-c-c0xffffffff-rj-k-no"
        },
        {
          "name": "twitter:app:name:iphone",
          "content": "YouTube"
        },
        {
          "name": "twitter:app:id:iphone",
          "content": "544007664"
        },
        {
          "name": "twitter:app:url:iphone",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=twitter-deep-link"
        },
        {
          "name": "twitter:app:name:ipad",
          "content": "YouTube"
        },
        {
          "name": "twitter:app:id:ipad",
          "content": "544007664"
        },
        {
          "name": "twitter:app:url:ipad",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=twitter-deep-link"
        },
        {
          "name": "twitter:app:name:googleplay",
          "content": "YouTube"
        },
        {
          "name": "twitter:app:id:googleplay",
          "content": "com.google.android.youtube"
        },
        {
          "name": "twitter:app:url:googleplay",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=twitter-deep-link"
        },
        {
          "name": "title",
          "content": "MeedanTube"
        },
        {
          "name": "nosnippet"
        },
        {
          "name": "keywords",
          "content": "Meedan, Arabic, English, language, translation, social, media, news, currentaffairs, nonprofit, dialogue"
        }
      ],
      "api": {
        "comment_count": "0",
        "country": null,
        "description": "",
        "title": "MeedanTube",
        "published_at": "2009-03-06T00:44:31.000Z",
        "subscriber_count": "148",
        "video_count": "29",
        "view_count": "30668",
        "thumbnails": {
          "default": {
            "url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s88-mo-c-c0xffffffff-rj-k-no",
            "width": 88,
            "height": 88
          },
          "medium": {
            "url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s240-mo-c-c0xffffffff-rj-k-no",
            "width": 240,
            "height": 240
          },
          "high": {
            "url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
            "width": 800,
            "height": 800
          }
        }
      },
      "oembed": {
        "type": "rich",
        "version": "1.0",
        "title": "MeedanTube",
        "author_name": "meedantube",
        "author_url": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ",
        "provider_name": "youtube",
        "provider_url": "http://www.youtube.com",
        "thumbnail_url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
        "html": "<iframe src=\"https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ\" width=\"800\" height=\"200\" scrolling=\"no\" border=\"0\" seamless>Not supported</iframe>",
        "width": 800,
        "height": 200
      }
    },
    "archives": {
    },
    "url": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ",
    "provider": "youtube",
    "type": "profile",
    "parsed_at": "2019-03-19T21:29:58.163+00:00",
    "favicon": "https://www.google.com/s2/favicons?domain_url=www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ",
    "country": null,
    "subtype": "channel",
    "playlists_count": 2,
    "video_count": "29",
    "subscriber_count": "148",
    "embed_tag": "<script src=\"http://www.example.com/api/medias.js?url=https%3A%2F%2Fwww.youtube.com%2Fuser%2FMeedanTube\" type=\"text/javascript\"></script>"
  }
}
```

400: URL not provided
```json
{
  "type": "error",
  "data": {
    "message": "Parameters missing",
    "code": 2
  }
}
```

401: Access denied
```json
{
  "type": "error",
  "data": {
    "message": "Unauthorized",
    "code": 1
  }
}
```

408: Timeout
```json
{
  "type": "media",
  "data": {
    "published_at": "2009-03-06T00:44:31.000Z",
    "username": "meedantube",
    "title": "MeedanTube",
    "description": "",
    "picture": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
    "author_url": "",
    "author_picture": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
    "author_name": "MeedanTube",
    "screenshot": "",
    "raw": {
      "metatags": [
        {
          "http-equiv": "origin-trial",
          "data-feature": "Media Capabilities",
          "data-expires": "2018-04-12",
          "content": "AjLq5uNF7MpG/eM34tWcJD3h8yZY1Q72ckfwdKbUNKGtUNaZkrw55eq2tI60vG0IlsCNw33W9WmuV113EAsdHAwAAABpeyJvcmlnaW4iOiJodHRwczovL3lvdXR1YmUuY29tOjQ0MyIsImZlYXR1cmUiOiJNZWRpYUNhcGFiaWxpdGllcyIsImV4cGlyeSI6MTUyMzQ5MTIwMCwiaXNTdWJkb21haW4iOnRydWV9"
        },
        {
          "http-equiv": "origin-trial",
          "data-feature": "Long Task Observer",
          "data-expires": "2017-04-17",
          "content": "AgXf9faUpH8YmYNhInb5nw8BxXZaT8pZlj3At6FUrcvdBzs0I8VxKDkfinT4bbXfPZX8lXKfjotQZrhFVnpzFwYAAABZeyJvcmlnaW4iOiJodHRwczovL3d3dy55b3V0dWJlLmNvbTo0NDMiLCJmZWF0dXJlIjoiTG9uZ1Rhc2tPYnNlcnZlciIsImV4cGlyeSI6MTQ5MjQ3MzYwMH0="
        },
        {
          "property": "og:site_name",
          "content": "YouTube"
        },
        {
          "property": "og:url",
          "content": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ"
        },
        {
          "property": "og:title",
          "content": "MeedanTube"
        },
        {
          "property": "og:description"
        },
        {
          "property": "og:image",
          "content": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s200-mo-c-c0xffffffff-rj-k-no"
        },
        {
          "name": "apple-itunes-app",
          "content": "app-id=544007664",
          "app-argument": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ"
        },
        {
          "property": "al:ios:app_store_id",
          "content": "544007664"
        },
        {
          "property": "al:ios:app_name",
          "content": "YouTube"
        },
        {
          "property": "al:ios:url",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=applinks"
        },
        {
          "property": "al:android:url",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=applinks"
        },
        {
          "property": "al:android:app_name",
          "content": "YouTube"
        },
        {
          "property": "al:android:package",
          "content": "com.google.android.youtube"
        },
        {
          "property": "al:web:url",
          "content": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=applinks"
        },
        {
          "property": "al:web:should_fallback",
          "content": "true"
        },
        {
          "property": "og:type",
          "content": "yt-fb-app:channel"
        },
        {
          "property": "og:video:tag",
          "content": "Meedan"
        },
        {
          "property": "og:video:tag",
          "content": "Arabic"
        },
        {
          "property": "og:video:tag",
          "content": "English"
        },
        {
          "property": "og:video:tag",
          "content": "language"
        },
        {
          "property": "og:video:tag",
          "content": "translation"
        },
        {
          "property": "og:video:tag",
          "content": "social"
        },
        {
          "property": "og:video:tag",
          "content": "media"
        },
        {
          "property": "og:video:tag",
          "content": "news"
        },
        {
          "property": "og:video:tag",
          "content": "currentaffairs"
        },
        {
          "property": "og:video:tag",
          "content": "nonprofit"
        },
        {
          "property": "og:video:tag",
          "content": "dialogue"
        },
        {
          "property": "fb:app_id",
          "content": "87741124305"
        },
        {
          "property": "og:restrictions:age",
          "content": "18+"
        },
        {
          "name": "twitter:card",
          "content": "summary"
        },
        {
          "name": "twitter:site",
          "content": "@YouTube"
        },
        {
          "name": "twitter:url",
          "content": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ"
        },
        {
          "name": "twitter:title",
          "content": "MeedanTube"
        },
        {
          "name": "twitter:description"
        },
        {
          "name": "twitter:image",
          "content": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s200-mo-c-c0xffffffff-rj-k-no"
        },
        {
          "name": "twitter:app:name:iphone",
          "content": "YouTube"
        },
        {
          "name": "twitter:app:id:iphone",
          "content": "544007664"
        },
        {
          "name": "twitter:app:url:iphone",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=twitter-deep-link"
        },
        {
          "name": "twitter:app:name:ipad",
          "content": "YouTube"
        },
        {
          "name": "twitter:app:id:ipad",
          "content": "544007664"
        },
        {
          "name": "twitter:app:url:ipad",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=twitter-deep-link"
        },
        {
          "name": "twitter:app:name:googleplay",
          "content": "YouTube"
        },
        {
          "name": "twitter:app:id:googleplay",
          "content": "com.google.android.youtube"
        },
        {
          "name": "twitter:app:url:googleplay",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=twitter-deep-link"
        },
        {
          "name": "title",
          "content": "MeedanTube"
        },
        {
          "name": "nosnippet"
        },
        {
          "name": "keywords",
          "content": "Meedan, Arabic, English, language, translation, social, media, news, currentaffairs, nonprofit, dialogue"
        }
      ],
      "api": {
        "comment_count": "0",
        "country": null,
        "description": "",
        "title": "MeedanTube",
        "published_at": "2009-03-06T00:44:31.000Z",
        "subscriber_count": "148",
        "video_count": "29",
        "view_count": "30668",
        "thumbnails": {
          "default": {
            "url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s88-mo-c-c0xffffffff-rj-k-no",
            "width": 88,
            "height": 88
          },
          "medium": {
            "url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s240-mo-c-c0xffffffff-rj-k-no",
            "width": 240,
            "height": 240
          },
          "high": {
            "url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
            "width": 800,
            "height": 800
          }
        }
      },
      "oembed": {
        "type": "rich",
        "version": "1.0",
        "title": "MeedanTube",
        "author_name": "meedantube",
        "author_url": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ",
        "provider_name": "youtube",
        "provider_url": "http://www.youtube.com",
        "thumbnail_url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
        "html": "<iframe src=\"https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ\" width=\"800\" height=\"200\" scrolling=\"no\" border=\"0\" seamless>Not supported</iframe>",
        "width": 800,
        "height": 200
      }
    },
    "archives": {
    },
    "url": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ",
    "provider": "youtube",
    "type": "profile",
    "parsed_at": "2019-03-19T21:29:58.163+00:00",
    "favicon": "https://www.google.com/s2/favicons?domain_url=www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ",
    "country": null,
    "subtype": "channel",
    "playlists_count": 2,
    "video_count": "29",
    "subscriber_count": "148",
    "embed_tag": "<script src=\"http://www.example.com/api/medias.js?url=https%3A%2F%2Fwww.youtube.com%2Fuser%2FMeedanTube\" type=\"text/javascript\"></script>"
  }
}
```

409: URL already being processed
```json
{
  "type": "media",
  "data": {
    "published_at": "2009-03-06T00:44:31.000Z",
    "username": "meedantube",
    "title": "MeedanTube",
    "description": "",
    "picture": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
    "author_url": "",
    "author_picture": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
    "author_name": "MeedanTube",
    "screenshot": "",
    "raw": {
      "metatags": [
        {
          "http-equiv": "origin-trial",
          "data-feature": "Media Capabilities",
          "data-expires": "2018-04-12",
          "content": "AjLq5uNF7MpG/eM34tWcJD3h8yZY1Q72ckfwdKbUNKGtUNaZkrw55eq2tI60vG0IlsCNw33W9WmuV113EAsdHAwAAABpeyJvcmlnaW4iOiJodHRwczovL3lvdXR1YmUuY29tOjQ0MyIsImZlYXR1cmUiOiJNZWRpYUNhcGFiaWxpdGllcyIsImV4cGlyeSI6MTUyMzQ5MTIwMCwiaXNTdWJkb21haW4iOnRydWV9"
        },
        {
          "http-equiv": "origin-trial",
          "data-feature": "Long Task Observer",
          "data-expires": "2017-04-17",
          "content": "AgXf9faUpH8YmYNhInb5nw8BxXZaT8pZlj3At6FUrcvdBzs0I8VxKDkfinT4bbXfPZX8lXKfjotQZrhFVnpzFwYAAABZeyJvcmlnaW4iOiJodHRwczovL3d3dy55b3V0dWJlLmNvbTo0NDMiLCJmZWF0dXJlIjoiTG9uZ1Rhc2tPYnNlcnZlciIsImV4cGlyeSI6MTQ5MjQ3MzYwMH0="
        },
        {
          "property": "og:site_name",
          "content": "YouTube"
        },
        {
          "property": "og:url",
          "content": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ"
        },
        {
          "property": "og:title",
          "content": "MeedanTube"
        },
        {
          "property": "og:description"
        },
        {
          "property": "og:image",
          "content": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s200-mo-c-c0xffffffff-rj-k-no"
        },
        {
          "name": "apple-itunes-app",
          "content": "app-id=544007664",
          "app-argument": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ"
        },
        {
          "property": "al:ios:app_store_id",
          "content": "544007664"
        },
        {
          "property": "al:ios:app_name",
          "content": "YouTube"
        },
        {
          "property": "al:ios:url",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=applinks"
        },
        {
          "property": "al:android:url",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=applinks"
        },
        {
          "property": "al:android:app_name",
          "content": "YouTube"
        },
        {
          "property": "al:android:package",
          "content": "com.google.android.youtube"
        },
        {
          "property": "al:web:url",
          "content": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=applinks"
        },
        {
          "property": "al:web:should_fallback",
          "content": "true"
        },
        {
          "property": "og:type",
          "content": "yt-fb-app:channel"
        },
        {
          "property": "og:video:tag",
          "content": "Meedan"
        },
        {
          "property": "og:video:tag",
          "content": "Arabic"
        },
        {
          "property": "og:video:tag",
          "content": "English"
        },
        {
          "property": "og:video:tag",
          "content": "language"
        },
        {
          "property": "og:video:tag",
          "content": "translation"
        },
        {
          "property": "og:video:tag",
          "content": "social"
        },
        {
          "property": "og:video:tag",
          "content": "media"
        },
        {
          "property": "og:video:tag",
          "content": "news"
        },
        {
          "property": "og:video:tag",
          "content": "currentaffairs"
        },
        {
          "property": "og:video:tag",
          "content": "nonprofit"
        },
        {
          "property": "og:video:tag",
          "content": "dialogue"
        },
        {
          "property": "fb:app_id",
          "content": "87741124305"
        },
        {
          "property": "og:restrictions:age",
          "content": "18+"
        },
        {
          "name": "twitter:card",
          "content": "summary"
        },
        {
          "name": "twitter:site",
          "content": "@YouTube"
        },
        {
          "name": "twitter:url",
          "content": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ"
        },
        {
          "name": "twitter:title",
          "content": "MeedanTube"
        },
        {
          "name": "twitter:description"
        },
        {
          "name": "twitter:image",
          "content": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s200-mo-c-c0xffffffff-rj-k-no"
        },
        {
          "name": "twitter:app:name:iphone",
          "content": "YouTube"
        },
        {
          "name": "twitter:app:id:iphone",
          "content": "544007664"
        },
        {
          "name": "twitter:app:url:iphone",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=twitter-deep-link"
        },
        {
          "name": "twitter:app:name:ipad",
          "content": "YouTube"
        },
        {
          "name": "twitter:app:id:ipad",
          "content": "544007664"
        },
        {
          "name": "twitter:app:url:ipad",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=twitter-deep-link"
        },
        {
          "name": "twitter:app:name:googleplay",
          "content": "YouTube"
        },
        {
          "name": "twitter:app:id:googleplay",
          "content": "com.google.android.youtube"
        },
        {
          "name": "twitter:app:url:googleplay",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=twitter-deep-link"
        },
        {
          "name": "title",
          "content": "MeedanTube"
        },
        {
          "name": "nosnippet"
        },
        {
          "name": "keywords",
          "content": "Meedan, Arabic, English, language, translation, social, media, news, currentaffairs, nonprofit, dialogue"
        }
      ],
      "api": {
        "comment_count": "0",
        "country": null,
        "description": "",
        "title": "MeedanTube",
        "published_at": "2009-03-06T00:44:31.000Z",
        "subscriber_count": "148",
        "video_count": "29",
        "view_count": "30668",
        "thumbnails": {
          "default": {
            "url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s88-mo-c-c0xffffffff-rj-k-no",
            "width": 88,
            "height": 88
          },
          "medium": {
            "url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s240-mo-c-c0xffffffff-rj-k-no",
            "width": 240,
            "height": 240
          },
          "high": {
            "url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
            "width": 800,
            "height": 800
          }
        }
      },
      "oembed": {
        "type": "rich",
        "version": "1.0",
        "title": "MeedanTube",
        "author_name": "meedantube",
        "author_url": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ",
        "provider_name": "youtube",
        "provider_url": "http://www.youtube.com",
        "thumbnail_url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
        "html": "<iframe src=\"https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ\" width=\"800\" height=\"200\" scrolling=\"no\" border=\"0\" seamless>Not supported</iframe>",
        "width": 800,
        "height": 200
      }
    },
    "archives": {
    },
    "url": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ",
    "provider": "youtube",
    "type": "profile",
    "parsed_at": "2019-03-19T21:29:58.163+00:00",
    "favicon": "https://www.google.com/s2/favicons?domain_url=www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ",
    "country": null,
    "subtype": "channel",
    "playlists_count": 2,
    "video_count": "29",
    "subscriber_count": "148",
    "embed_tag": "<script src=\"http://www.example.com/api/medias.js?url=https%3A%2F%2Fwww.youtube.com%2Fuser%2FMeedanTube\" type=\"text/javascript\"></script>"
  }
}
```

429: API limit reached
```json
{
  "type": "media",
  "data": {
    "published_at": "2009-03-06T00:44:31.000Z",
    "username": "meedantube",
    "title": "MeedanTube",
    "description": "",
    "picture": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
    "author_url": "",
    "author_picture": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
    "author_name": "MeedanTube",
    "screenshot": "",
    "raw": {
      "metatags": [
        {
          "http-equiv": "origin-trial",
          "data-feature": "Media Capabilities",
          "data-expires": "2018-04-12",
          "content": "AjLq5uNF7MpG/eM34tWcJD3h8yZY1Q72ckfwdKbUNKGtUNaZkrw55eq2tI60vG0IlsCNw33W9WmuV113EAsdHAwAAABpeyJvcmlnaW4iOiJodHRwczovL3lvdXR1YmUuY29tOjQ0MyIsImZlYXR1cmUiOiJNZWRpYUNhcGFiaWxpdGllcyIsImV4cGlyeSI6MTUyMzQ5MTIwMCwiaXNTdWJkb21haW4iOnRydWV9"
        },
        {
          "http-equiv": "origin-trial",
          "data-feature": "Long Task Observer",
          "data-expires": "2017-04-17",
          "content": "AgXf9faUpH8YmYNhInb5nw8BxXZaT8pZlj3At6FUrcvdBzs0I8VxKDkfinT4bbXfPZX8lXKfjotQZrhFVnpzFwYAAABZeyJvcmlnaW4iOiJodHRwczovL3d3dy55b3V0dWJlLmNvbTo0NDMiLCJmZWF0dXJlIjoiTG9uZ1Rhc2tPYnNlcnZlciIsImV4cGlyeSI6MTQ5MjQ3MzYwMH0="
        },
        {
          "property": "og:site_name",
          "content": "YouTube"
        },
        {
          "property": "og:url",
          "content": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ"
        },
        {
          "property": "og:title",
          "content": "MeedanTube"
        },
        {
          "property": "og:description"
        },
        {
          "property": "og:image",
          "content": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s200-mo-c-c0xffffffff-rj-k-no"
        },
        {
          "name": "apple-itunes-app",
          "content": "app-id=544007664",
          "app-argument": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ"
        },
        {
          "property": "al:ios:app_store_id",
          "content": "544007664"
        },
        {
          "property": "al:ios:app_name",
          "content": "YouTube"
        },
        {
          "property": "al:ios:url",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=applinks"
        },
        {
          "property": "al:android:url",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=applinks"
        },
        {
          "property": "al:android:app_name",
          "content": "YouTube"
        },
        {
          "property": "al:android:package",
          "content": "com.google.android.youtube"
        },
        {
          "property": "al:web:url",
          "content": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=applinks"
        },
        {
          "property": "al:web:should_fallback",
          "content": "true"
        },
        {
          "property": "og:type",
          "content": "yt-fb-app:channel"
        },
        {
          "property": "og:video:tag",
          "content": "Meedan"
        },
        {
          "property": "og:video:tag",
          "content": "Arabic"
        },
        {
          "property": "og:video:tag",
          "content": "English"
        },
        {
          "property": "og:video:tag",
          "content": "language"
        },
        {
          "property": "og:video:tag",
          "content": "translation"
        },
        {
          "property": "og:video:tag",
          "content": "social"
        },
        {
          "property": "og:video:tag",
          "content": "media"
        },
        {
          "property": "og:video:tag",
          "content": "news"
        },
        {
          "property": "og:video:tag",
          "content": "currentaffairs"
        },
        {
          "property": "og:video:tag",
          "content": "nonprofit"
        },
        {
          "property": "og:video:tag",
          "content": "dialogue"
        },
        {
          "property": "fb:app_id",
          "content": "87741124305"
        },
        {
          "property": "og:restrictions:age",
          "content": "18+"
        },
        {
          "name": "twitter:card",
          "content": "summary"
        },
        {
          "name": "twitter:site",
          "content": "@YouTube"
        },
        {
          "name": "twitter:url",
          "content": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ"
        },
        {
          "name": "twitter:title",
          "content": "MeedanTube"
        },
        {
          "name": "twitter:description"
        },
        {
          "name": "twitter:image",
          "content": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s200-mo-c-c0xffffffff-rj-k-no"
        },
        {
          "name": "twitter:app:name:iphone",
          "content": "YouTube"
        },
        {
          "name": "twitter:app:id:iphone",
          "content": "544007664"
        },
        {
          "name": "twitter:app:url:iphone",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=twitter-deep-link"
        },
        {
          "name": "twitter:app:name:ipad",
          "content": "YouTube"
        },
        {
          "name": "twitter:app:id:ipad",
          "content": "544007664"
        },
        {
          "name": "twitter:app:url:ipad",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=twitter-deep-link"
        },
        {
          "name": "twitter:app:name:googleplay",
          "content": "YouTube"
        },
        {
          "name": "twitter:app:id:googleplay",
          "content": "com.google.android.youtube"
        },
        {
          "name": "twitter:app:url:googleplay",
          "content": "vnd.youtube://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ?feature=twitter-deep-link"
        },
        {
          "name": "title",
          "content": "MeedanTube"
        },
        {
          "name": "nosnippet"
        },
        {
          "name": "keywords",
          "content": "Meedan, Arabic, English, language, translation, social, media, news, currentaffairs, nonprofit, dialogue"
        }
      ],
      "api": {
        "comment_count": "0",
        "country": null,
        "description": "",
        "title": "MeedanTube",
        "published_at": "2009-03-06T00:44:31.000Z",
        "subscriber_count": "148",
        "video_count": "29",
        "view_count": "30668",
        "thumbnails": {
          "default": {
            "url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s88-mo-c-c0xffffffff-rj-k-no",
            "width": 88,
            "height": 88
          },
          "medium": {
            "url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s240-mo-c-c0xffffffff-rj-k-no",
            "width": 240,
            "height": 240
          },
          "high": {
            "url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
            "width": 800,
            "height": 800
          }
        }
      },
      "oembed": {
        "type": "rich",
        "version": "1.0",
        "title": "MeedanTube",
        "author_name": "meedantube",
        "author_url": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ",
        "provider_name": "youtube",
        "provider_url": "http://www.youtube.com",
        "thumbnail_url": "https://yt3.ggpht.com/a-/AAuE7mDdj5bFTGGcXEzD82axKXNOOsP6HqpaV-e8yA=s800-mo-c-c0xffffffff-rj-k-no",
        "html": "<iframe src=\"https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ\" width=\"800\" height=\"200\" scrolling=\"no\" border=\"0\" seamless>Not supported</iframe>",
        "width": 800,
        "height": 200
      }
    },
    "archives": {
    },
    "url": "https://www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ",
    "provider": "youtube",
    "type": "profile",
    "parsed_at": "2019-03-19T21:29:58.163+00:00",
    "favicon": "https://www.google.com/s2/favicons?domain_url=www.youtube.com/channel/UCL6xkW90kBI76OuApogUbFQ",
    "country": null,
    "subtype": "channel",
    "playlists_count": 2,
    "video_count": "29",
    "subscriber_count": "148",
    "embed_tag": "<script src=\"http://www.example.com/api/medias.js?url=https%3A%2F%2Fwww.youtube.com%2Fuser%2FMeedanTube\" type=\"text/javascript\"></script>"
  }
}
```

