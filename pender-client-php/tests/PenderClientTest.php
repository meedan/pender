<?php
namespace Meedan\PenderClient;

class PenderClientTest extends \PHPUnit_Framework_TestCase {

  public function test_medias_returns_parsed_data() {
    $res = PenderClient::mock_medias_returns_parsed_data();
    $this->assertEquals("error", $res->type);
    $this->assertEquals("Unauthorized", $res->data->message);
    $this->assertEquals(1, $res->data->code);
  }
  public function test_medias_returns_url_not_provided() {
    $res = PenderClient::mock_medias_returns_url_not_provided();
    $this->assertEquals("error", $res->type);
    $this->assertEquals("Unauthorized", $res->data->message);
    $this->assertEquals(1, $res->data->code);
  }
  public function test_medias_returns_access_denied() {
    $res = PenderClient::mock_medias_returns_access_denied();
    $this->assertEquals("error", $res->type);
    $this->assertEquals("Unauthorized", $res->data->message);
    $this->assertEquals(1, $res->data->code);
  }
}
