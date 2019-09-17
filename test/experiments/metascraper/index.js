const metascraper = require('metascraper')([
    require('metascraper-author')(),
    require('metascraper-date')(),
    require('metascraper-description')(),
    require('metascraper-publisher')(),
    require('metascraper-title')(),
    require('metascraper-url')(),
    require('metascraper-image')(),
    require('metascraper-lang')(),
    require('metascraper-logo')(),
    require('metascraper-logo-favicon')(),
    require('metascraper-media-provider')(),
    require('metascraper-readability')(),
    require('metascraper-soundcloud')(),
    require('metascraper-uol')(),
    require('metascraper-video')()
])
const got = require('got')
const penderData = require('./pender.json');
const parameters = { 'author_name': 'author', 'published_at': 'date', 'description': 'description', 'picture': 'image', 'provider': 'publisher', 'title': 'title', 'url': 'url', 'favicon': 'logo'}

async function getLink(link) {
    try {
      const {body: html, url} = await got(link);
      const metadata = await metascraper({html, url})
      return metadata;
    } catch(e) {
      console.log(e.url + ' : ' + e.statusCode + ' (' + e.statusMessage + ')');
    }
}

async function run() {
  for(const link in penderData) {
    const metascraper = await getLink(link);
    console.log(link)
    if (metascraper != undefined) {
      const pender = penderData[link];
      for(const p in parameters) {
        var penderValue = pender[p];
        var scraperValue = metascraper[parameters[p]]
        if (penderValue != scraperValue) {
          console.log('  ' + p + ': "' + penderValue + '" => "' + scraperValue + '"')
        }
      }
    }
    console.log('=========================================')
  }
}

run();
