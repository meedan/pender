
# PenderClient

This package is a PHP client for pender, which defines itself as 'A parsing and rendering service'. It also provides mock methods to test it.

## Installation

Add this line to your application's `composer.json` `require` dependencies:

```php
"meedan/pender-client": "*"
```

And then execute:

    $ composer install

## Usage

With this package you can call methods from pender's API and also test them by using the provided mocks.

The available methods are:

* PenderClient::get_medias($url)

If you are going to test something that uses the 'pender' service, first you need to mock each possible response it can return, which are:

* PenderClient::mock_medias_returns_parsed_data()
* PenderClient::mock_medias_returns_url_not_provided()
* PenderClient::mock_medias_returns_access_denied()
      
