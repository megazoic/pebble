require 'bundler'

Bundler.require(:default)

require './pebble'

#require './test_env'

run Sinatra::Application
#run TestEnvApp
