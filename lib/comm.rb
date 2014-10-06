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
      size = unpackMsgSize str

      self.new from64(str[8..-1])
    end

    def self.streamed
      self.new
    end

    # Returns the size of an encoded message (excluding the size field).
    def self.unpackMsgSize(rawData)
      (from64 rawData[0,8]).unpack('L')[0]
    end

    def to_s
      encMsg = to64 @data

      to64([encMsg.size].pack 'L')+encMsg
    end

    def toMsg
      Msg.decode @data
    end

    def received(rawData)
      return rawData if rawData.empty?
      return rawData if received?

      sizeOffset = 0

      if @streamSize.nil?
        # Message size can be decoded.
        if rawData.size >= 8
          @streamSize = self.class.unpackMsgSize rawData

          return '' if rawData.size == 8

          sizeOffset = 8
        else
          return rawData
        end
      end

      @stream += rawData.slice(
          sizeOffset,
          (processed = [@streamSize-@stream.size, rawData.size-sizeOffset].min))

      return rawData[sizeOffset+processed..-1]
    end

    def received?
      return true unless @data.empty?

      if !@streamSize.nil? and @stream.size == @streamSize
        @data = from64 @stream
        @streamSize, @stream = nil, ''

        return true
      end

      return false
    end

    def clear
      @streamSize, @stream = nil, ''
      @data = ''
    end

    private
    def initialize(data=nil)
      # Streamed
      if data.nil?
        clear

      elsif !data.is_a? String and data.respond_to? :encode
        @data = data.encode.to_s

      else
        @data = data.to_s
      end
    end
  end

  #
  # Application messages, they are encoded / decoded when
  # they are sent / received by TransportMsg.

  class Base
    include Beefcake::Message
  end

  class SearchResultsFromCache < Base
    ID = 1
  end

  class Products < Base
    ID = 2

    required :data, :bytes, 1
  end

  class NumberOfProducts < Base
    ID = 3

    required :count, :uint32, 1
  end

  class ProductsFetched < Base
    ID = 4

    required :count, :uint32, 1
  end

  class CommIssues < Base
    ID = 5

    required :issue, :bytes, 1
  end

  class TooManySearchResults < Base
    ID = 6

    required :count, :uint32, 1
  end

  class Msg < Base
    required :type, :uint32, 1

    optional :products, Products, 2
    optional :numberOfProducts, NumberOfProducts, 3
    optional :productsFetched, ProductsFetched, 4
    optional :commIssues, CommIssues, 5
    optional :tooManySearchResults, TooManySearchResults, 6
  end
end

class QueryChildMsgs < Qt::Object
  include Base64Helpers
  include Hatchet

  slots 'searchResultsFromCache()',
           'products(QObject *)',
           'numberOfProducts(int)',
           'productsFetched(int)',
           'commIssues(const QString &)',
           'tooManySearchResults(int)'

  def initialize
    super(nil)
  end

  def searchResultsFromCache
    printMsg CommMsgs::SearchResultsFromCache.new
  end

  def products(p)
    products = p.products
    printMsg(
        CommMsgs::Products.new data: Marshal.dump(products))
  end

  def numberOfProducts(count)
    printMsg(
        CommMsgs::NumberOfProducts.new count: count)
  end

  def productsFetched(count)
    printMsg(
        CommMsgs::ProductsFetched.new count: count)
  end

  def commIssues(issue)
    printMsg(
        CommMsgs::CommIssues.new issue: issue)
  end

  def tooManySearchResults(count)
    printMsg(
        CommMsgs::TooManySearchResults.new count: count)
  end

  private

  def printMsg(msg)
    case msg.class::ID

      when CommMsgs::Products::ID
          wrapperMsg = CommMsgs::Msg.new(
              :type=> msg.class::ID,
              :products => msg)

      when CommMsgs::NumberOfProducts::ID
        wrapperMsg = CommMsgs::Msg.new(
            :type => msg.class::ID,
            :numberOfProducts => msg)

      when CommMsgs::ProductsFetched::ID
        wrapperMsg = CommMsgs::Msg.new(
            :type => msg.class::ID,
            :productsFetched => msg)

      when CommMsgs::SearchResultsFromCache::ID
        wrapperMsg = CommMsgs::Msg.new(
            :type => msg.class::ID)

      when CommMsgs::CommIssues::ID
        wrapperMsg = CommMsgs::Msg.new(
            type: msg.class::ID,
            commIssues: msg)

      when CommMsgs::TooManySearchResults::ID
        wrapperMsg = CommMsgs::Msg.new(
            type: msg.class::ID,
            tooManySearchResults: msg)

    end

    print CommMsgs::TransportMsg.toSend(wrapperMsg)
    $stdout.flush
    $stdout.fsync
  end
end