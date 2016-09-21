## Generated from error.proto for events
require "beefcake"


class Error
  include Beefcake::Message
  required :source, :string, 1
  required :code, :int32, 2
  required :message, :string, 3
end
