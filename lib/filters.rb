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
require_relative '../qrc_components'

require 'Qt'
require 'qtuitools'

class Filter < Qt::Widget
  include WidgetHelpers

  signals 'filterActivated(QWidget *)', 'filterDeactivated(QWidget *)'

  def initialize(filterName, isRelevant, filter)
    super(nil)

    @active = false

    loadUi 'filters_filter'
    layout.setContentsMargins 0, 0, 0, 0

    (@picAdd = Qt::Pixmap.new).load ':/pics/pics/add.png'
    (@picCancel = Qt::Pixmap.new).load ':/pics/pics/cancel.png'

    @picL = findChild Qt::Label, 'filterPicL'
    (findChild Qt::Label, 'filterNameL').setText filterName

    @filter = filter
    @isRelevant = isRelevant
  end

  def mousePressEvent(e)
    if not @active
      @active = true
      @picL.setPixmap @picCancel
      emit filterActivated(self)

    else
      @active = false
      @picL.setPixmap @picAdd
      emit filterDeactivated(self)
    end
  end

  def eval(product)
    return @filter.call(product)
  end

  def isRelevant(search)
    @isRelevant.call(search)
  end
end

class TextFilter
  def initialize(text)
    @text = text
  end

  def eval(product)
    product.to_s =~ /#{@text}/i
  end
end

class Filters < Qt::Widget
  include WidgetHelpers

  signals 'filterActivated(QWidget *)', 'filterDeactivated(QWidget *)'
  slots 'refreshFilterList(QString *)'

  def initialize(parent=nil)
    super

    loadUi 'filters'

    @filters = []

    @filtersLayout = findChild Qt::Layout, 'filtersLayout'
    @noFiltersL = findChild Qt::Label, 'noFiltersL'

    # Filters here
    addFilter(
      'Metal, thin film',
      lambda { |s| s =~ /resistor/i },
      lambda { |p|
        if p.attributes['Resistor Element Material']
          return ['Metal Film', 'Thin Film'].include?(
              p.attributes['Resistor Element Material'])
        end

        return false
      })

    addFilter(
      'Case Style',
      lambda { |s| s =~ /resistor/i },
      lambda { |p|
        if p.attributes.has_key? 'Resistor Case Style'
          return p.attributes['Resistor Case Style'][0..1].to_i >= 8
        end

        return false
      })

    addFilter(
        'Tolerance 2%',
        lambda { |s| s =~ /capacitor/i },
        lambda { |p|
          if p.attributes.has_key? 'Capacitance Tolerance'
            return p.attributes['Capacitance Tolerance'][/\d+/].to_i <= 2
          end

          return false
        })

    @noFiltersL.hide unless @filters.empty?

    @filtersLayout.addSpacerItem(
        Qt::SpacerItem.new(
            10, 10,
            Qt::SizePolicy::Minimum,
            Qt::SizePolicy::Expanding))

    @filtersLayout.setContentsMargins 0, 0, 0, 0

    refreshFilterList ''
  end

  def refreshFilterList(search)
    @filters.each do |f|
      if f.isRelevant(search)
        f.show
      else
        f.hide
      end
    end
  end

  private
  def addFilter(title, isRelevant, filter)
    f = Filter.new title, isRelevant, filter
    connect f, SIGNAL('filterActivated(QWidget *)') do |f|
      emit filterActivated(f)
    end
    connect f, SIGNAL('filterDeactivated(QWidget *)') do |f|
      emit filterDeactivated(f)
    end

    @filtersLayout.addWidget f

    @filters << f
  end
end