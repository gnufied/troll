# Troll
module ActiveResource
  class Connection
    alias_method :old_request, :request

    def request(method, path, * arguments)
      puts "#{method.to_s.upcase} #{site.scheme}://#{site.host}:#{site.port}#{path}"
      request_body = arguments.first
      response = check_for_matching_mock(method, path, request_body)
      unless response
        response = old_request(method, path, * arguments)
        print_responses(method, path, arguments, response)
        response
      end
      return response
    end

    def check_for_matching_mock(method, path, body)
      ActiveSupport::TestCase.resource_mock.fetch_match(method, path, body) do |responder|
        if (responder)
          status = responder.response_header[:status]
          return Troll::Response.new(responder.response_header[:body])
        else
          return nil
        end
      end
    end

    def print_responses(method, path, arguments, response)
      if (response && (200...400).include?(response.code.to_i))
        puts("********** method is #{method.inspect} and path is #{path.inspect} **********")
        puts arguments
        puts "==== Response body ====="
        puts response.body
      end
      response
    end
  end
end

module Troll
  module TestUnitStuff
    def self.included(base)
      base.class_eval {
        @@resource_mock = Troll::ResourceMock.new()
        def self.resource_mock
          @@resource_mock
        end
      }
    end

    def http_mock(method, path, body_header = {}, response_header = {})
      key = "#{method.to_s.upcase}#{path.to_s.upcase}"
      @@resource_mock.http_mock[key] ||= []
      @@resource_mock.http_mock[key] << Troll::Responder.new(body_header, response_header)
    end

    def fixture_file(file_name)
      IO.read("#{Rails.root}/test/fixtures/#{file_name}")
    end
  end
  
  class Responder
    attr_accessor :body_header, :response_header, :times

    def initialize(body_header, response_header)
      @times = body_header[:times] || -1
      @body_header = body_header
      @response_header = response_header
    end
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

  class ResourceMock
    @http_mocks = {}

    def http_mock
      self.class.instance_variable_get(:@http_mocks)
    end

    def fetch_match(request_method, request_path, request_body, & block)
      key = "#{request_method.to_s.upcase}#{request_path.to_s.upcase}"
      mock_responder = http_mock[key]
      if mock_responder
        matched_responder = nil
        mock_responder.each do |responder|
          if match_body(responder.body_header[:body], request_body) && responder.times != 0
            matched_responder = responder
          end
        end
        decrement_responder_count(matched_responder, & block)
      else
        block.call(nil)
      end
    end

    def decrement_responder_count(matched_responder, & block)
      block.call(matched_responder)
    ensure
      if (matched_responder && (matched_responder.times != -1 || matched_responder.times != 0))
        matched_responder.times -= 1
      end
    end

    def match_body(expected_body, request_body)
      return true unless expected_body
      request_body =~ expected_body
    end

  end
end