require 'bundler'

Bundler.require(:default)

require './get_dec_azim'

run Sinatra::Application
