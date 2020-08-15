#reserve_process.rb

require 'dotenv'
require 'httparty'
require 'shopify_api'
require 'active_record'
require 'sinatra/activerecord'
#require 'logger'

Dotenv.load
Dir[File.join(__dir__, 'lib', '*.rb')].each { |file| require file }
Dir[File.join(__dir__, 'models', '*.rb')].each { |file| require file }

module EllieOrders
  class ElliePicks
    include ShopifyThrottle

    def initialize
      @shopname = ENV['SHOPIFY_SHOP_NAME']
      @api_key = ENV['SHOPIFY_API_KEY']
      @password = ENV['SHOPIFY_API_PASSWORD']
      #@reserve_process_log = Logger.new File.new('logs/reserve_process.log', 'w')
    end

    def provide_min_max(my_min, my_max)
        #puts "my_min = #{my_min}, #{my_max}"
        if (my_min.to_i == 0) && (my_max.to_i == 0)
            my_now = Date.today
            my_yesterday = my_now - 1
            local_min = my_yesterday.strftime("%Y-%m-%dT00:00:00-04:00") 
            local_max = my_now.strftime("%Y-%m-%dT23:58:00-4:00")
            stuff_to_return = {"my_min" => local_min, "my_max" => local_max}


        else
            stuff_to_return = {"my_min" => my_min, "my_max" => my_max}
        end
        #puts stuff_to_return.inspect
        return stuff_to_return
    end


    def download_ellie_picks_orders
        my_args = provide_min_max(0, 0)
        my_min = my_args['my_min']
        my_max = my_args['my_max']
        puts "my_min = #{my_min}, my_max = #{my_max}"
        #2020-08-13T00:00:00-04:00
        #exit

        shop_url = "https://#{@api_key}:#{@password}@#{@shopname}.myshopify.com/admin"
        ShopifyAPI::Base.site = shop_url
        ShopifyAPI::Base.api_version = '2020-04'
        ShopifyAPI::Base.timeout = 180

        order_count = ShopifyAPI::Order.count( created_at_min: my_min, created_at_max: my_max, status: 'any')
        puts "We have #{order_count} orders"

        num_orders = 0
        num_pages = 0
        num_ellie_picks = 0
        #Headers for CSV
        column_header = ["order_name", "first_name", "last_name", "email", "product_collection"]
        File.delete('ellie_picks_orders.csv') if File.exist?('ellie_picks_orders.csv')

        orders = ShopifyAPI::Order.find(:all, params: {limit: 250, created_at_min: my_min, created_at_max: my_max, status: 'any'})

        CSV.open('ellie_picks_orders.csv','a+', :write_headers=> true, :headers => column_header) do |hdr|
            column_header = nil
        #First page
        orders.each do |myord|
            puts "#{myord.id}, #{myord.name}, #{myord.fulfillments&.first&.tracking_numbers.inspect}, #{myord.fulfillments&.first&.tracking_urls.inspect}"
            temp_line_items = myord.line_items
            #puts "XXXXXXXXXXXXXXXX"
            #puts temp_line_items.inspect
            #puts "XXXXXXXXXXXXXXXXX"
            temp_line_items.each do |myline|
                #product_collection_title = myline['properties'].select {|property| property['name'] == 'product_collection'}
                #puts product_collection_title.inspect
                #if product_collection_title.first['value'].length > 0
                #    puts "product_collection_title is present"
                #end
                #puts "************"
                #puts myline.attributes['properties'].inspect
                
                my_prod_coll = nil
                myline.attributes['properties'].each do |myl|
                    if myl.attributes['name'] == 'product_collection'
                        my_prod_coll = myl.attributes['value']
                    end
                end
               # puts "***********"
                if !my_prod_coll.nil?
                    puts "product_collection = #{my_prod_coll}"
                    if my_prod_coll =~ /ellie\spick/i
                        puts "found ellie picks"
                        csv_data_out = [myord.name, myord.customer.first_name, myord.customer.last_name, myord.customer.email, my_prod_coll  ]
                        hdr << csv_data_out
                        num_ellie_picks += 1
                        
                    end
                end

            end
            
            num_orders += 1

        end
        num_pages += 1
        puts "-------------------"
        puts "Page #{num_pages}"
        puts "-------------------"
        shopify_api_throttle
        

        #next pages
        while orders.next_page?
            orders = orders.fetch_next_page

            orders.each do |myord|
                puts "#{myord.id}, #{myord.name}, #{myord.fulfillments&.first&.tracking_numbers.inspect}, #{myord.fulfillments&.first&.tracking_urls.inspect}"
                temp_line_items = myord.line_items
                
                temp_line_items.each do |myline|
                    
                    my_prod_coll = nil
                    myline.attributes['properties'].each do |myl|
                        if myl.attributes['name'] == 'product_collection'
                            my_prod_coll = myl.attributes['value']
                        end
                    end
                   
                    if !my_prod_coll.nil?
                        puts "product_collection = #{my_prod_coll}"
                        if my_prod_coll =~ /ellie\spick/i
                            puts "found ellie picks"
                            puts myord.customer.email
                            csv_data_out = [myord.name, myord.customer.first_name, myord.customer.last_name, myord.customer.email, my_prod_coll  ]
                            hdr << csv_data_out
                            num_ellie_picks += 1
                            
                            
                        end
                    end
    
                end


                num_orders += 1
            end
            num_pages += 1
            puts "-------------------"
            puts "Page #{num_pages}"
            puts "-------------------"
            shopify_api_throttle
        end

        end
        #of CSV part
        
        puts "We have #{num_orders} downloaded"
        puts "We have #{num_ellie_picks} ellie picks to Shopify"




    end



  end
end