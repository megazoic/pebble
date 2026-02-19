require 'bundler'

Bundler.require(:default)

require './get_dec_azim'

#require './test_env'

run Sinatra::Application
#run TestEnvApp
