# Copyright 2014 Peter Vrabel <kybu@kybu.org>
# This file is part of 'Electronic Components Panel'.
#
# 'Electronic Components Panel' is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# 'Electronic Components Panel' is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with 'Electronic Components Panel'. If not, see <http://www.gnu.org/licenses/>.
require_relative 'helpers'

require 'Qt'
require 'beefcake'
require 'base64'

module CommMsgs
  # Message sent through a pipe (or any other transport layer)
  class TransportMsg
    extend Base64Helpers
    include Base64Helpers

    def self.toSend(o)
      self.new o
    end

    def self.received(o)
      str = o.to_s
      size = str[0,8].unpack('L')[0]

      self.new from64(str[8..-1])
    end

    def to_s
      encMsg = to64 @data

      to64([encMsg.size].pack 'L')+encMsg
    end

    def toMsg
      Msg.decode @data
    end

    private
    def initialize(data)
      if !data.is_a? String and data.respond_to? :encode
        @data = data.encode.to_s
      else
        @data = data.to_s
      end
    end
  end

  #
  # Application messages, they are encoded / decoded when
  # they are sent / received by TransportMsg.

  class SearchResultFromCache
    ID = 1

    include Beefcake::Message
  end

  class Products
    ID = 2

    include Beefcake::Message

    required :data, :bytes, 1
  end

  class Msg
    include Beefcake::Message

    required :type, :uint32, 1

    optional :products, Products, 2
  end
end

class QueryChildMsgs < Qt::Object
  include Base64Helpers

  slots 'searchResultFromCache()',
           'products(QObject *)'

  def initialize
    super(nil)
  end

  def searchResultFromCache
    printMsg SearchResultFromCache.new
  end

  def products(p)
    products = p.products
    printMsg(
        CommMsgs::Products.new :data => Marshal.dump(products))
  end

  private

  def printMsg(msg)
    case msg.class::ID
      when CommMsgs::Products::ID
          wrapperMsg = CommMsgs::Msg.new(
              :type=> msg.class::ID,
              :products => msg)
    end

    print CommMsgs::TransportMsg.toSend(wrapperMsg)
  end
end