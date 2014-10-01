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
require_relative 'logging'
require_relative 'globals'

require 'httparty'
require 'pp'
require 'fileutils'

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

# Farnell API is tempermental.
#
# It seems that JSON response format does not return product attributes when
# searching by keywords. XML response format behaves better.
#
# XML response format has a minor issue. If there is only one result, instead of
# an array with just one product hash element, the hash is returned. That breaks
# array loops. Such results have to be converted to one element arrays.
class Farnell < Qt::Object
  include Hatchet

  class Error < RuntimeError
  end

  attr_reader :cache, :id
  attr_accessor :apiKey, :ignoreReeled, :ignoreNonUK,
                       :retries, :retrySleep,
                       :attributesRetries, :attributesRetrySleep

  signals 'searchResultsFromCache()', 'products(QObject *)',
               'numberOfProducts(int)',
               'communicationIssue(const QString &)',
               'productsFetched(int)'

  CACHEDIR = APPDATA+'/cache'

  def initialize(storeId = 'uk.farnell.com')
    super(nil)

    @id = @storeId = storeId

    @retries = 3
    @retrySleep = 0.73

    @attributesRetries = 3
    @attributesRetrySleep = 3

    loadCache
  end

  def loadCache(query=nil)
    FileUtils.mkdir_p(CACHEDIR) unless Dir.exist?(CACHEDIR)

    if query.nil?
      @cache = {}
      Dir.glob("#{CACHEDIR}/#{@storeId}_*") do |f|
        @cache[File.basename(f)[@storeId.size+1..-1]] = Marshal.load(File.binread f)
      end

    else
      f = "#{CACHEDIR}/#{@storeId}_#{query}"
      @cache[File.basename(f)[@storeId.size+1..-1]] = Marshal.load(File.binread f)

    end
  end

  def searchFor(query, numberOfResults = 10)
    products = []
    if (products = fetchCache(query))
      log.debug { "Fetched from cache: #{query}"}

      if @ignoreReeled
        products = products.select {|p| !isReeled p}
      end
      emit productsFetched(products.size)

    else
      data = remoteCall 'any:'+query, 0, numberOfResults

      products, noAttributes = rawDataToProducts(data)
      log.debug {"Products with no attributes: #{noAttributes.size}"}

      if noAttributes.size != 0
        log.debug {"Going to fetch attributes."}

        products = products - noAttributes

        sku = noAttributes.map { |p| p['sku'] }
        data = remoteCall sku, 0, sku.size

        products2, noAttributes2 = rawDataToProducts(data)

        if noAttributes2.size != 0
          log.warn {"Products with no attributes: #{noAttributes2.size}"}
        end

        products.concat products2
      end

      storeCache query, products
    end

    emit products(h = ProductsHolder.new(products))
    h.dispose

    return products
  end

  def resultCount(query)
    if (t=fetchCache(query+'_resultCount'))
      log.debug { "Fetched from cache: #{query}_resultCount"}

      emit searchResultsFromCache()
      emit numberOfProducts(t)

      return t
    end

    data = remoteCall "any:#{query}", 0, 1 do |request|
      request['resultsSettings.responseGroup'] = 'none'
    end

    n = data['keywordSearchReturn']['numberOfResults'].to_i
    log.debug {"Number of results: #{n}"}
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
    log.debug {"Shop id: #{@storeId}"}
    ret = {}
    fetched = 0
    numberOfResults = numberOfResults.to_i

    while fetched < numberOfResults
      toFetch = numberOfResults - fetched
      toFetch = 50 if toFetch > 50

      retries = 0
      attributesRetries = 0
      # Retry
      while true
        log.debug { "Offset / ToFetch / Retries: #{fetched} #{toFetch} #{retries}" }

        term = query.kind_of?(Array) ?
                                  "id:#{query[fetched, toFetch].join ' '}"
                              :
                                  query.to_s

        request = {
            'callInfo.apiKey' => @apiKey,
            'storeInfo.id' => @storeId,

            'term' => term,

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
        # data is a string when HTTP 503 happens
        if data.is_a? String or data.has_key? 'Fault' or data.has_key? 'h1'
          prettified = ''
          PP.pp data, prettified

          log.warn { "Communication issues: #{prettified}"}

          emit communicationIssue(prettified)

          if retries == @retries
            raise Error.new 'Retries!'
          end

          retries += 1
          sleep @retrySleep

        else
          dataReturnKey = nil
          dataReturnKey = 'keywordSearchReturn' if data.has_key?('keywordSearchReturn')
          dataReturnKey = 'premierFarnellPartNumberReturn' if data.has_key?('premierFarnellPartNumberReturn')

          # When only one products is found, 'products' is not an array with one element
          # but a product info hash. it only happens with XML format.
          if data[dataReturnKey].has_key? 'products' and
             data[dataReturnKey]['products'].kind_of? Hash

            data[dataReturnKey]['products'] = [data[dataReturnKey]['products']]
          end

          if request['resultsSettings.responseGroup'] != 'none'
            log.debug {"Products with no attributes: #{noAttributesCount data}"}

            if query.kind_of?(Array) and noAttributesCount(data) != 0
              if attributesRetries == @attributesRetries
                raise Error.new 'Attribute retries!'
              end
              attributesRetries += 1

              log.debug {"Going to retry to get all attributes."}

              sleep @attributesRetries
              next
            end
          end

          fetched += toFetch

          if ret.empty?
            ret.merge! data
          else
            if data.has_key? 'keywordSearchReturn' and
               data['keywordSearchReturn'].has_key?('products')

              ret['keywordSearchReturn']['products'] += data['keywordSearchReturn']['products']

            elsif data.has_key? 'premierFarnellPartNumberReturn' and
                    data['premierFarnellPartNumberReturn'].has_key?('products')

              ret['premierFarnellPartNumberReturn']['products'] += data['premierFarnellPartNumberReturn']['products']

            else
              log.warn { "Returned search did not contain expected structure!" }
            end
          end

          emit productsFetched(toFetch)

          break
        end

        sleep 1.73
      end
    end

    return ret
  end

  def storeCache(query, data)
    @cache[query] = data

    File.binwrite "#{CACHEDIR}/#{@storeId}_#{query}", Marshal.dump(data)
  end

  def noAttributesCount(data)
    dataReturnKey = nil
    dataReturnKey = 'keywordSearchReturn' if data.has_key?('keywordSearchReturn')
    dataReturnKey = 'premierFarnellPartNumberReturn' if data.has_key?('premierFarnellPartNumberReturn')

    if dataReturnKey
      noAttributes = 0
      data[dataReturnKey]['products'].each do |p|
        noAttributes += 1 unless p.has_key? 'attributes'
      end

      return noAttributes
    end

  end

  def rawDataToProducts(data)
    products = []

    dataReturnKey = nil
    dataReturnKey = 'keywordSearchReturn' if data.has_key?('keywordSearchReturn')
    dataReturnKey = 'premierFarnellPartNumberReturn' if data.has_key?('premierFarnellPartNumberReturn')

    if dataReturnKey
      noAttributes = []
      ignoredNoUK = ignoredReeled = 0

      data[dataReturnKey]['products'].each do |p|
        # JSON
        #next if p.has_key?('reeling') and p['reeling']
        # XML
        #next if p.has_key?('reeling') and p['reeling'].strip == 'true'

        if @ignoreReeled and isReeled(p)
          ignoredReeled += 1
          next
        end

        if @ignoreNonUK and p.has_key? 'stock' and p['stock'].has_key? 'regionalBreakdown'
          if p['stock']['regionalBreakdown'].kind_of? Hash
            p['stock']['regionalBreakdown'] = [p['stock']['regionalBreakdown']]
          end

          notUk = p['stock']['regionalBreakdown'].detect do |r|
            r['warehouse'] == 'UK' and r['level'].to_i <= 0
          end

          if notUk
            ignoredNoUK += 1
            next
          end

        end

        unless p.has_key? 'attributes'
          p['attributes'] = []
          noAttributes << p
        end

        products << Product.new(p)
      end

      if @ignoreReeled
        if ignoredReeled != 0
          log.debug {"Ignoring #{ignoredReeled} reeled products."}
        end
      end

      if ignoredNoUK != 0
        log.debug {"Ignoring #{ignoredNoUK} non-UK stock products"}
      end

      return products, noAttributes
    end
  end

  def isReeled(product)
    # XML
    if product.has_key? 'reeling' and product['reeling'] != 'false' or
      product['displayName'] =~ /,\s+reel$/i

      return true
    end

    # JSON
    # product.has_key? 'reeling' and product['reeling']

    return false
  end
end