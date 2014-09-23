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

require 'httparty'
require 'xmlsimple'
require 'pp'

class Product < Hash
  attr_reader :attributes,
                      :price, :minQuant

  def initialize(data)
    merge! data

    @attributes = {}

    if has_key? 'attributes'
      self['attributes'].each do |attr|
        if attr.is_a? Hash
          @attributes[attr['attributeLabel'].strip] = attr['attributeValue'].strip
        else
          attr.delete 'attributes'
        end
      end
    end

    @price = data['prices'].is_a?(Array) ?
        data['prices'][0]['cost'].to_f
          :
        data['prices']['cost'].to_f
    @minQuant = data['translatedMinimumOrderQuality'].to_i
  end

  def totalPriceStr
    "%0.2f" % (@minQuant*@price*self['basketQuantity'])
  end
end

class Farnell < Qt::Object
  attr_reader :lastQuery, :cache, :id
  attr_accessor :apiKey

  signals 'searchResultsFromCache()', 'products(QObject *)',
               'numberOfProducts(int)',
               'communicationIssue(const QString &)',
               'productsFetched(int)'

  def initialize(storeId = 'uk.farnell.com')
    super(nil)

    @lastQuery = nil
    @id = @storeId = storeId

    loadCache
  end

  def loadCache(query=nil)
    Dir.mkdir('cache') unless Dir.exist?('cache')

    if query.nil?
      @cache = {}
      Dir.glob("cache/#{@storeId}_*") do |f|
        @cache[File.basename(f)[@storeId.size+1..-1]] = Marshal.load(File.binread f)
      end

    else
      f = "cache/#{@storeId}_#{query}"
      @cache[File.basename(f)[@storeId.size+1..-1]] = Marshal.load(File.binread f)

    end
  end

  def filter(filterBy)
    @cache[@lastQuery].select do |p|
      p.to_s =~ /#{filterBy}/i
    end
  end

  def searchFor(query, numberOfResults = 10)
    @lastQuery = query

    products = []
    if (products = fetchCache(query))
      emit productsFetched(products.size)

    else
      data = remoteCall 'any:'+query, 0, numberOfResults

      products, noAttributes = rawDataToProducts(data)

      if noAttributes != 0
        sku = products.map { |p| p['sku'] }
        data = remoteCall "id: #{sku.join ' '}", 0, sku.size

        products, noAttributes = rawDataToProducts(data)
      end

      storeCache query, products
    end

    emit products(h = ProductsHolder.new(products))
    h.dispose

    return products
  end

  def resultCount(query)
    if (t=fetchCache(query+'_resultCount'))
      emit searchResultsFromCache()
      emit numberOfProducts(t)

      return t
    end

    data = remoteCall "any:#{query}", 0, 1 do |request|
      request['resultsSettings.responseGroup'] = 'none'
    end

    n = data['keywordSearchReturn']['numberOfResults'].to_i
    storeCache query+'_resultCount', n
    emit numberOfProducts(n)

    return n
  end

  def fetchCache(query)
    if @cache.has_key?(query)
      return @cache[query]
    end

    return false
  end

  private

  def remoteCall(query, offset, numberOfResults)
    ret = {}
    fetched = 0
    numberOfResults = numberOfResults.to_i

    while fetched < numberOfResults
      toFetch = numberOfResults - fetched
      toFetch = 50 if toFetch > 50

      # Retry
      while true

        request = {
            'callInfo.apiKey' => @apiKey,
            'storeInfo.id' => @storeId,

            'term' => query,

            'resultsSettings.offset' => fetched,
            'resultsSettings.numberOfResults' => toFetch,
            'resultsSettings.responseGroup' => 'large',
            'resultsSettings.refinements.filters' => 'inStock',

            'callInfo.omitXmlSchema' => true,
            'callInfo.responseDataFormat' => 'XML'}

        yield request if block_given?

        data = HTTParty.get(
            'http://api.element14.com/catalog/products',
            {query: request}).parsed_response

        # h1 => 'Gateway Timeout'
        if data.has_key? 'Fault' or data.has_key? 'h1'
          prettified = ''
          PP.pp data, prettified

          emit communicationIssue(prettified)

          sleep 0.73

          # When HTTP 503 happens ...
        elsif data.is_a? String
          pp data

        else
          fetched += toFetch

          if ret.empty?
            ret.merge! data
          else
            if data.has_key? 'keywordSearchReturn' and
                data['keywordSearchReturn'].has_key?('products')

              ret['keywordSearchReturn']['products'] += data['keywordSearchReturn']['products']
            end
          end

          emit productsFetched(toFetch)

          break
        end

        sleep 0.73
      end
    end

    return ret
  end

  def storeCache(query, data)
    @cache[query] = data

    File.binwrite "cache/#{@storeId}_#{query}", Marshal.dump(data)
  end

  def rawDataToProducts(data)
    products = []

    dataReturnKey = nil
    dataReturnKey = 'keywordSearchReturn' if data.has_key?('keywordSearchReturn')
    dataReturnKey = 'premierFarnellPartNumberReturn' if data.has_key?('premierFarnellPartNumberReturn')

    if dataReturnKey
      noAttributes = 0
      data[dataReturnKey]['products'].each do |p|
        # JSON
        #next if p.has_key?('reeling') and p['reeling']
        # XML
        #next if p.has_key?('reeling') and p['reeling'].strip == 'true'

        unless p.has_key? 'attributes'
          noAttributes += 1
          p['attributes'] = []
        end

        products << Product.new(p)
      end

      return products, noAttributes
    end
  end
end