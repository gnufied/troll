# Include hook code here
if ['cucumber','test'].include?(Rails.env)
  require "troll"
end

