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

class Netlists < Qt::Widget
  include WidgetHelpers

  def initialize(parent=nil)
    super

    loadUi 'netlists'
    layout.setContentsMargins 0, 0, 0, 0

    @loadNetlistPB = findChild Qt::PushButton, 'loadNetlistPB'
    @partsT = findChild Qt::TableWidget, 'partsT'

    connect @loadNetlistPB, SIGNAL('clicked()') do loadNetlist end
  end

  def loadNetlist
    netList = Qt::FileDialog.getOpenFileName(
        self, 'Choose a netlist')

    if netList
      File.open(netList) do |f|
        f.read[%r{\*PART\*(.*)\*NET\*}m]
        content = $1.strip

        parts = content.each_line.reduce([]) do |m, line|
          if line =~ /^([^\s]+)\s+(.*)$/
            m << [$1, $2]
          end
        end

        @partsT.setSortingEnabled false
        @partsT.setRowCount parts.size
        @partsT.setColumnCount 2

        row = 0
        parts.each do |part, value|
          row += 1

          i = Qt::TableWidgetItem.new(part)
          @partsT.setItem(row-1, 0, i)

          i = Qt::TableWidgetItem.new(value)
          @partsT.setItem(row-1, 1, i)
        end

        @partsT.setSortingEnabled true
      end
    end
  end
end