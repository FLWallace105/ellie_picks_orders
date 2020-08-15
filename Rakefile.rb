require 'active_record'
require 'sinatra/activerecord/rake'

require_relative 'ellie_picks'

namespace :pull_orders do
    desc 'get all orders'
    task :get_all_orders do |t|
        EllieOrders::ElliePicks.new.download_ellie_picks_orders
    end

end