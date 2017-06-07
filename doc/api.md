### API

#### GET /api/medias

Get parseable data for a given URL, that can be a post or a profile, from different providers

**Parameters**

* `url`: URL to be parsed/rendered _(required)_
* `refresh`: Force a refresh from the URL instead of the cache

**Response**

200: Parsed data
```json
{
  "type": "media",
  "data": {
    "published_at": "2009-03-06T00:44:31.000Z",
    "username": "MeedanTube",
    "title": "MeedanTube",
    "description": "",
    "picture": "https://yt3.ggpht.com/-MPd3Hrn0msk/AAAAAAAAAAI/AAAAAAAAAAA/I1ftnn68v8U/s88-c-k-no-mo-rj-c0xffffff/photo.jpg",
    "author_url": "",
    "author_picture": "",
    "url": "https://www.youtube.com/user/MeedanTube",
    "provider": "youtube",
    "type": "profile",
    "parsed_at": "2017-06-07T16:17:19.906-03:00",
    "favicon": "https://www.google.com/s2/favicons?domain_url=https://www.youtube.com/user/MeedanTube",
    "comment_count": 7,
    "subscriber_count": 141,
    "video_count": 21,
    "view_count": 29799,
    "thumbnail_url": "https://yt3.ggpht.com/-MPd3Hrn0msk/AAAAAAAAAAI/AAAAAAAAAAA/I1ftnn68v8U/s88-c-k-no-mo-rj-c0xffffff/photo.jpg",
    "country": null,
    "subtype": "user",
    "playlists_count": 2,
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
    "username": "MeedanTube",
    "title": "MeedanTube",
    "description": "",
    "picture": "https://yt3.ggpht.com/-MPd3Hrn0msk/AAAAAAAAAAI/AAAAAAAAAAA/I1ftnn68v8U/s88-c-k-no-mo-rj-c0xffffff/photo.jpg",
    "author_url": "",
    "author_picture": "",
    "url": "https://www.youtube.com/user/MeedanTube",
    "provider": "youtube",
    "type": "profile",
    "parsed_at": "2017-06-07T16:17:19.906-03:00",
    "favicon": "https://www.google.com/s2/favicons?domain_url=https://www.youtube.com/user/MeedanTube",
    "comment_count": 7,
    "subscriber_count": 141,
    "video_count": 21,
    "view_count": 29799,
    "thumbnail_url": "https://yt3.ggpht.com/-MPd3Hrn0msk/AAAAAAAAAAI/AAAAAAAAAAA/I1ftnn68v8U/s88-c-k-no-mo-rj-c0xffffff/photo.jpg",
    "country": null,
    "subtype": "user",
    "playlists_count": 2,
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
    "username": "MeedanTube",
    "title": "MeedanTube",
    "description": "",
    "picture": "https://yt3.ggpht.com/-MPd3Hrn0msk/AAAAAAAAAAI/AAAAAAAAAAA/I1ftnn68v8U/s88-c-k-no-mo-rj-c0xffffff/photo.jpg",
    "author_url": "",
    "author_picture": "",
    "url": "https://www.youtube.com/user/MeedanTube",
    "provider": "youtube",
    "type": "profile",
    "parsed_at": "2017-06-07T16:17:19.906-03:00",
    "favicon": "https://www.google.com/s2/favicons?domain_url=https://www.youtube.com/user/MeedanTube",
    "comment_count": 7,
    "subscriber_count": 141,
    "video_count": 21,
    "view_count": 29799,
    "thumbnail_url": "https://yt3.ggpht.com/-MPd3Hrn0msk/AAAAAAAAAAI/AAAAAAAAAAA/I1ftnn68v8U/s88-c-k-no-mo-rj-c0xffffff/photo.jpg",
    "country": null,
    "subtype": "user",
    "playlists_count": 2,
    "embed_tag": "<script src=\"http://www.example.com/api/medias.js?url=https%3A%2F%2Fwww.youtube.com%2Fuser%2FMeedanTube\" type=\"text/javascript\"></script>"
  }
}
```

