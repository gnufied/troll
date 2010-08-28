require 'test_helper'

class TrollTest < ActiveSupport::TestCase
  include Troll::TestUnitStuff
  context "Get request mocks with path" do
    setup do
      @guid = get_guid()
      http_mock(:get,"/articles/1.xml",{:times => 1},{:status => 200, :body => one_article(@guid)})
      @article = Article.find(1)
    end

    should "be matched correctly" do
      assert_equal 'World', @article.content
      assert_equal @guid, @article.guid
    end


  end

  context "Keeping matcher counter" do

    should "apply recent mock first and remove the mocks" do
      guid_1 = get_guid()
      http_mock(:get,"/articles/1.xml",{:times => 2},{:status => 200, :body => one_article(guid_1)})

      guid_2 = get_guid()
      http_mock(:get,"/articles/1.xml",{:times => 1},{:status => 200, :body => one_article(guid_2)})
      article1 = Article.find(1)

      assert_equal guid_2, article1.guid

      article2 = Article.find(1)
      assert_equal guid_1, article2.guid

      existing_mocks = ActiveResource::Connection.resource_mock.http_mock["GET/ARTICLES/1.XML"]
      assert_equal 1, existing_mocks.size

      responder_body = CGI.unescape(existing_mocks.first.response_header[:body])
      assert_match /#{guid_1}/, responder_body
    end
  end

  context "Post request mocks with body regular expression" do
    should "be matched correctly" do
      clear_all_http_mocks()
      mocks = ActiveResource::Connection.resource_mock.http_mock
      assert mocks.empty?
      guid = get_guid()
      http_mock(:post,"/articles.xml",{:times => 1, :body => /#{guid}/},
                                       {:status => 200, :body => one_article(guid)})
      article = Article.new(:guid => guid, :content => "Wow")
      article.save
      assert_equal guid, article.guid
    end
  end

  def one_article(guid)
    xml =<<-EOD
<?xml version="1.0" encoding="UTF-8"?>
<article>
  <content>World</content>
  <created-at type="datetime">2010-08-23T11:44:07Z</created-at>
  <guid>#{guid}</guid>
  <id type="integer">100</id>
  <title>hello</title>
  <updated-at type="datetime">2010-08-23T11:44:07Z</updated-at>
</article>
    EOD
  end

  def get_guid
    UUIDTools::UUID.timestamp_create.to_s
  end
end
