module Kernel
  def puts(*args)
    require 'console'
    $console.log(*args)
  end
end
