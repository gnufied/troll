module Troll
  module MockActiveResourceConnection

    def self.included(base)
      base.class_eval do
        cattr_accessor :resource_mock
        self.resource_mock = Troll::ResourceMock.new()
        alias_method :old_request,:request
        remove_method :request
      end
    end

    def request(method, path, * arguments)
      request_body = arguments.first
      new_path,query_string = path.split("?",2)
      response = nil

      if request_body.blank? && !query_string.blank? && mocked_request_has_body?(method)
        request_body = query_string
        response = check_for_matching_mock(method, new_path, request_body)
      else
        response = check_for_matching_mock(method, path, request_body)
      end


      unless response
        debug_resource_calls("~~~~~~ Original Request #{method.to_s.upcase} #{site.scheme}://#{site.host}:#{site.port}#{path} ~~~~~")
        response = old_request(method, path, * arguments)
        print_responses(method, path, arguments, response)
        response
      else
        debug_resource_calls("### Original Request #{method.to_s.upcase} #{site.scheme}://#{site.host}:#{site.port}#{path} returning mocked response###")
        handle_response(response)
      end
    end

    def mocked_request_has_body?(method)
      ['POST','PUT'].include(method.to_s.upcase)
    end

    def check_for_matching_mock(method, path, body)
      responder = resource_mock.fetch_match(method, path, body)
      return nil unless responder
      status = responder.response_header[:status] || 200
      Troll::Response.new(responder.response_header[:body],status)
    end

    def print_responses(method, path, arguments, response)
      if (response && (200...500).include?(response.code.to_i))
        debug_resource_calls("********** method is #{method} and path is #{path} **********")
        debug_resource_calls("==== Response body =====")
        debug_resource_calls(response.body)
      end
      response
    end

    def debug_resource_calls(data)
      if Rails.configuration.log_level == :debug
        puts data
      end
    end
  end
end
