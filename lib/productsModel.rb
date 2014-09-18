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
class ProductsModel < Qt::AbstractTableModel
  def initialize(data, parent=nil)
    super(parent)
    @data = data
  end

  def rowCount(parent)
    data.size
  end

  def columnCount(parent)
    3
  end

  def data(index, role)
    if !index.valid?
      return Qt::Variant.new
    elsif role == Qt::ToolTipRole
      return Qt::Variant.new
    end

    return Qt::Variant.new(data[index.row])
  end
end
