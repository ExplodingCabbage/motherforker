class String
  old_strip = instance_method(:strip)
  
  define_method(:strip) do |chars=nil|
    if chars.nil?
      old_strip.bind(self).call
    else
      # chars can be either an array of characters or a string
      if chars.respond_to? :join
        chars = chars.join
      end
      
      # nicked from http://stackoverflow.com/a/3166005/1709587
      chars = Regexp.escape(chars)
      self.gsub(/\A[#{chars}]+|[#{chars}]+\Z/, "")
    end
  end
end