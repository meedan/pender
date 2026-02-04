require 'test_helper'

class TelegramIntegrationTest < ActiveSupport::TestCase
  test "should parse Telegram item URL and set unique title" do
    m = create_media url: 'https://t.me/rechtsanwaeltin_beate_bahner/13285'
    data = m.process_and_return_json
    assert_equal 'rechtsanwaeltin_beate_bahner', data['username']
    assert_equal 'item', data['type']
    assert_equal 'telegram', data['provider']
    assert_match /Rechtsanwältin Beate Bahner/, data['author_name']
    assert_equal 'https://t.me/rechtsanwaeltin_beate_bahner/13285', data['title']
    assert_match /Pfizer bestätigt vor EU-Covid-Ausschuss/, data['description']
    assert_nil data['error']
  end
end

class TelegramProfileUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end
end

class TelegramItemUnitTest <  ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  test "returns provider and type" do
    assert_equal Parser::TelegramItem.type, 'telegram_item'
  end

  test "matches known kwai URL patterns, and returns instance on success" do
    assert_nil Parser::TelegramItem.match?('https://example.com')

    match_one = Parser::TelegramItem.match?('https://t.me/rechtsanwaeltin_beate_bahner/13285')
    assert_equal true, match_one.is_a?(Parser::TelegramItem)

    match_one = Parser::TelegramItem.match?('https://telegram.me/rechtsanwaeltin_beate_bahner/13285')
    assert_equal true, match_one.is_a?(Parser::TelegramItem)
  end

  test "assigns values to hash from the HTML doc, and sets URL as title" do
    doc = response_fixture_from_file('telegram-item.html', parse_as: :html)

    data = Parser::TelegramItem.new('https://t.me/example_account/12345').parse_data(doc)
    assert_equal 'https://t.me/example_account/12345', data[:title]
    assert_match /❗ Pfizer bestätigt vor EU-Covid-Ausschuss/, data[:description]
    assert_match /Rechtsanwältin Beate Bahner/, data[:author_name]
    assert_equal 'example_account', data[:username]
    assert_equal '12345', data[:external_id]
    assert_match /cdn4.telegram-cdn.org\/file/, data[:picture]
  end
end
