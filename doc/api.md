### API

#### GET /api/medias

Get parseable data for a given URL, that can be a post or a profile, from different providers

**Parameters**

* `url`: URL to be parsed/rendered _(required)_

**Response**

200: Parsed data
```json
{
  "type": "media",
  "data": {
    "url": "https://www.youtube.com/user/MeedanTube",
    "provider": "youtube",
    "type": "profile",
    "title": "MeedanTube",
    "description": "",
    "published_at": "2009-03-06T00:44:31.000Z",
    "thumbnail_url": "https://yt3.ggpht.com/-MPd3Hrn0msk/AAAAAAAAAAI/AAAAAAAAAAA/I1ftnn68v8U/s88-c-k-no/photo.jpg",
    "view_count": 29101,
    "subscriber_count": 137
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

