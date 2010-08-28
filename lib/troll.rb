# Troll

module Troll
  autoload :MockActiveResourceConnection, "troll/mock_active_resource_connection"

  module TestUnitStuff
    def self.included(base)
      base.extend(CommonMethods)
      base.send(:include,CommonMethods)
      ActiveResource::Connection.send(:include, MockActiveResourceConnection)
    end

    module CommonMethods
      def http_mock(method, path, body_header = {}, response_header = {})
        key = "#{method.to_s.upcase}#{path.to_s.upcase}"
        ActiveResource::Connection.resource_mock.http_mock[key] ||= []
        ActiveResource::Connection.resource_mock.http_mock[key] << Troll::Responder.new(body_header, response_header)
      end

      def clear_all_http_mocks()
        ActiveResource::Connection.resource_mock.clear()
      end

      def fixture_file(file_name)
        IO.read("#{Rails.root}/test/fixtures/#{file_name}")
      end
    end
  end

  class ResourceMock
    @http_mocks = {}

    def http_mock
      self.class.instance_variable_get(:@http_mocks)
    end

    def clear; self.class.instance_variable_set(:@http_mocks,{}); end

    def fetch_match(request_method, request_path, request_body)
      key = "#{request_method.to_s.upcase}#{request_path.to_s.upcase}"
      mocked_responders = http_mock[key]
      return nil unless mocked_responders
      
      matched_responder = nil
      mocked_responders.reverse.each do |responder|
        if match_body(responder.body_header[:body], request_body) && responder.can_be_used?
          matched_responder = responder
          break
        end
      end
      
      decrement_responder_count(matched_responder,key)
      matched_responder
    end

    def decrement_responder_count(matched_responder,key)
      if (matched_responder && matched_responder.can_be_decremented?)
        matched_responder.times -= 1
      end
      if matched_responder && matched_responder.can_be_removed?
        old_responders = http_mock[key]
        old_responders.delete(matched_responder)
        http_mock[key] = old_responders
      end
    end

    def match_body(expected_body, request_body)
      return true unless expected_body
      CGI::unescape(request_body) =~ expected_body
    end
  end

  class Responder
    attr_accessor :body_header, :response_header, :times

    def initialize(body_header, response_header)
      @times = body_header[:times] || -1
      @body_header = body_header
      @response_header = response_header
    end

    def can_be_used?; self.times != 0; end
    def can_be_decremented?; self.times != 0 && self.times != -1; end
    def can_be_removed?; self.times == 0; end
  end

  class Response
    attr_accessor :body, :message, :code, :headers

    def initialize(body, message = 200, headers = {})
      @body, @message, @headers = body, message.to_s, headers
      @code = @message[0, 3].to_i

      resp_cls = Net::HTTPResponse::CODE_TO_OBJ[@code.to_s]
      if resp_cls && !resp_cls.body_permitted?
        @body = nil
      end

      if @body.nil?
        self['Content-Length'] = "0"
      else
        self['Content-Length'] = body.size.to_s
      end
    end

    def response
      self
    end

    def success?
      (200..299).include?(code)
    end

    def [](key)
      headers[key]
    end

    def []=(key, value)
      headers[key] = value
    end

    def ==(other)
      if (other.is_a?(Response))
        other.body == body && other.message == message && other.headers == headers
      else
        false
      end
    end
  end


end



