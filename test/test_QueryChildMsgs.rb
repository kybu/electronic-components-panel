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
require 'test-unit'

require_relative '../lib/comm'

class QueryChildMsgsTest < Test::Unit::TestCase
  include Base64Helpers

  def test_products
    msgs = QueryChildMsgs.new

    origStdout = $stdout
    begin
      $stdout = StringIO.new
      msgs.products ProductsHolder.new 'bla'

    ensure
      output = $stdout.string
      $stdout = origStdout
    end

    msgSize = (from64(output[0,8]).unpack 'L')[0]
    assert_equal output.size-8, msgSize

    assert_equal "bla", Marshal.load(
        CommMsgs::Msg.decode(
            from64 output[8..-1]).products.data)
  end

  def test_numberOfProducts
    msgs = QueryChildMsgs.new

    origStdout = $stdout
    begin
      $stdout = StringIO.new
      msgs.numberOfProducts 192

    ensure
      output = $stdout.string
      $stdout = origStdout
    end

    msgSize = (from64(output[0,8]).unpack 'L')[0]
    assert_equal output.size-8, msgSize

    assert_equal(
        192,
        CommMsgs::Msg.decode(
            from64 output[8..-1]).numberOfProducts.count)
  end
end