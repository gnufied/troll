require 'rubygems'
gem 'activesupport', '~> 2.3.4'
gem 'actionpack', '~> 2.3.4'
gem 'activerecord', '~> 2.3.4'
gem 'rails', '~> 2.3.4'

require "active_support"
require 'active_support/test_case'

require "action_controller"
require "action_view"
require "action_pack"
require "active_resource"

require "shoulda"
require "mocha"
require "ostruct"
require "troll"
require "uuidtools"

module Rails
  def self.configuration
    OpenStruct.new(:log_level => :debug)
  end
end
$:<< File.join(File.dirname(__FILE__), "models")

autoload :Article, "models/article"
