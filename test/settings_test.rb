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

$settingsRegistryKey = 'Components-Tests'
require_relative '../lib/settings'

require 'test/unit'
require 'Qt'

class SettingsTest < Test::Unit::TestCase
  BasketStruct = Struct.new :items do
    def add(products)
      self.items = products
    end
  end

  def setup
    Settings.deleteAll
  end

  def teardown
    Settings.deleteAll
  end

  def test_saveBasket
    Settings.saveBasket 'test.farnell.com', BasketStruct.new(['bla'])

    b = BasketStruct.new
    Settings.loadBasket 'test.farnell.com', b

    assert_equal ['bla'], b.items
  end

  def test_saveEmptyBasket
    Settings.saveBasket 'test.farnell.com', BasketStruct.new([])

    b = BasketStruct.new
    Settings.loadBasket 'test.farnell.com', b

    assert_equal [], b.items
  end

  def test_appendBasket
    Settings.saveBasket 'test1.farnell.com', BasketStruct.new(['bla1'])
    Settings.saveBasket 'test2.farnell.com', BasketStruct.new(['bla2'])

    b = BasketStruct.new
    Settings.loadBasket 'test1.farnell.com', b
    assert_equal ['bla1'], b.items

    Settings.loadBasket 'test2.farnell.com', b
    assert_equal ['bla2'], b.items
  end

  def test_nonExistingBasket
    b = BasketStruct.new
    Settings.loadBasket 'notThere', b

    assert_equal nil, b.items
  end
end