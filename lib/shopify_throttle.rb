#shopify_throttle.rb
module ShopifyThrottle
    def shopify_api_throttle
      return if ShopifyAPI.credit_left > 5
  
      puts "CREDITS LEFT: #{ShopifyAPI.credit_left}"
      puts "SLEEPING 20"
      sleep 20
    end
end