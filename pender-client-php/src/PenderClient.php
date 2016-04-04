<?php
namespace Meedan\PenderClient;

class PenderClient extends \Meedan\Lapis\LapisClient {

  function __construct($config = []) {
    $config['token_name'] = 'X-Pender-Token';
    parent::__construct($config);
  }
  
  // GET api/medias
  // Get the metadata for a given URL
  // @param $url
  //  URL to be parsed/rendered
  public function get_medias($url) {
    return $this->request('get', 'api/medias', [ 'url' => $url ]);
  }
  
  public static function mock_medias_returns_parsed_data() {
    $c = new PenderClient(['token_value' => 'test', 'client' => self::createMockClient(
      200, json_decode("{\"type\":\"error\",\"data\":{\"message\":\"Unauthorized\",\"code\":1}}", true)
    )]);
    return $c->get_medias("https://www.youtube.com/user/MeedanTube");
  }
  public static function mock_medias_returns_url_not_provided() {
    $c = new PenderClient(['token_value' => 'test', 'client' => self::createMockClient(
      400, json_decode("{\"type\":\"error\",\"data\":{\"message\":\"Unauthorized\",\"code\":1}}", true)
    )]);
    return $c->get_medias('');
  }
  public static function mock_medias_returns_access_denied() {
    $c = new PenderClient(['token_value' => '', 'client' => self::createMockClient(
      401, json_decode("{\"type\":\"error\",\"data\":{\"message\":\"Unauthorized\",\"code\":1}}", true)
    )]);
    return $c->get_medias("https://www.youtube.com/user/MeedanTube");
  }
}
