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
Dir.chdir File.dirname(__FILE__)

require 'Qt'
require 'pp'
require 'base64'

require_relative 'lib/main'
require_relative 'lib/farnell'
require_relative 'lib/filters'
require_relative 'lib/settings'
require_relative 'lib/searchCache'
require_relative 'lib/netlists'
require_relative 'lib/basket'

app = Qt::Application.new(ARGV)

$supplier = nil

class Components < Qt::MainWindow
  def initialize(parent=nil)
    super

    setWindowTitle 'Components'

    @products = Main.new
    @basket = Basket.new

    @stackedWidget = Qt::StackedWidget.new
    @stackedWidget.addWidget @products
    @stackedWidget.addWidget @basket
    @stackedWidget.setCurrentWidget @products

    setCentralWidget @stackedWidget

    @settings = SettingsDialog.new
    connect @settings, SIGNAL('supplierChanged(QObject *)'),
                  @products, SLOT('supplierChanged(QObject *)')
    connect @settings, SIGNAL('farnellApiKeyChanged(const QString &)') do |apiKey|
      $supplier.apiKey = apiKey
    end

    # Basket
    addDock(
        @basketInfo = BasketInfo.new(@basket),
        'Basket', 'basket')

    connect(
        @products, SIGNAL('productRightClick(QObject *)'),
        @basket, SLOT('add(QObject *)'))
    connect @basketInfo, SIGNAL('showCompleteBasket()') do
      @filters.setEnabled false
      @searchCache.setEnabled false

      @stackedWidget.setCurrentWidget @basket
    end
    connect @basket, SIGNAL('closeBasket()') do
      @filters.setEnabled true
      @searchCache.setEnabled true

      @stackedWidget.setCurrentWidget @products
    end
    connect(
        @basket, SIGNAL('basketUpdated()'),
        @basketInfo, SLOT('basketUpdated()'))

    # Filters
    addDock(
        @filters = Filters.new,
        'Filters',
        'filters')

    connect(
        @filters, SIGNAL('filterActivated(QWidget *)'),
        @products, SLOT('filterActivated(QWidget *)'))
    connect(
        @filters, SIGNAL('filterDeactivated(QWidget *)'),
        @products, SLOT('filterDeactivated(QWidget *)'))
    connect(
        @products, SIGNAL('search(QString *)'),
        @filters, SLOT('refreshFilterList(QString *)'))

    # Search cache
    addDock(
        @searchCache = SearchCache.new,
        'Search cache', 'searchCache')

    connect(
        @settings, SIGNAL('supplierChanged(QObject *)'),
        @searchCache, SLOT('supplierChanged(QObject *)'))
    connect(
        @searchCache, SIGNAL('cacheSelected(const QString &)'),
        @products, SLOT('searchFor(const QString &)'))
    connect(
        @products, SIGNAL('search(QString *)'),
        @searchCache, SLOT('refreshCache()'))

    # Netlists
    addDock(
        @netlists = Netlists.new,
        'Netlists', 'netlists',
        Qt::BottomDockWidgetArea)

    connect $qApp, SIGNAL('lastWindowClosed()') do gone end

    # Menu
    settingsA = menuBar.addAction '&Settings'

    connect settingsA, SIGNAL('triggered()') do settings end

    Settings.restoreMainWindowSettings self

    @settings.load
  end

  def gone
    Settings.saveMainWindowSettings self
  end

  def settings
    @settings.save if @settings.exec == Qt::Dialog::Accepted
  end

  private
  def addDock(widget, title, objectName, dockWidgetArea=Qt::LeftDockWidgetArea)
    dock = Qt::DockWidget.new title, self
    dock.setObjectName objectName
    dock.allowedAreas = Qt::AllDockWidgetAreas
    dock.widget = widget

    addDockWidget dockWidgetArea, dock
    menuBar.addAction (toggle=dock.toggleViewAction)

    yield dock, toggle if block_given?
  end
end

if ARGV.include? '-q'
  $supplier = Farnell.new ARGV[1]
  query = ARGV[2]

  resultCount = $supplier.resultCount query
  print Base64.encode64(
              Marshal.dump(
                $supplier.searchFor query, resultCount))

else
  Components.new.show
  app.exec
end


