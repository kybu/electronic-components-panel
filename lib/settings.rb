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

$settingsRegistryKey ||= 'Components'

class Settings
  @settings = Qt::Settings.new(
      Qt::Settings.UserScope,
      Qt::Settings.NativeFormat,
      'kybu',
      $settingsRegistryKey)

  MAINWINDOW_STATE_REG = 'mainWindowState'
  MAINWINDOW_GEOMETRY_REG = 'mainWindowGeometry'
  FARNELLAPI_REG = 'farnellApiKey'
  FARNELLSHOP_REG = 'farnellShop'
  BASKET_REG = 'basket'

  def self.deleteAll
    @settings.remove ''
    @settings.sync
  end

  def self.restoreMainWindowSettings(mWindow)
    mainWindowState = @settings.value(MAINWINDOW_STATE_REG).toByteArray
    mainWindowGeometry = @settings.value(MAINWINDOW_GEOMETRY_REG).toByteArray

    mWindow.restoreState mainWindowState
    mWindow.restoreGeometry mainWindowGeometry
  end

  def self.saveMainWindowSettings(mWindow)
    @settings.setValue(
        MAINWINDOW_STATE_REG,
        Qt::Variant.fromValue(mWindow.saveState))
    @settings.setValue(
        MAINWINDOW_GEOMETRY_REG,
        Qt::Variant.fromValue(mWindow.saveGeometry))

    @settings.sync
  end

  def self.saveSettings(settingsDialog)
    @settings.setValue(
        FARNELLAPI_REG,
        Qt::Variant.fromValue(settingsDialog.farnellApiKey))
    @settings.setValue(
        FARNELLSHOP_REG,
        Qt::Variant.fromValue(settingsDialog.farnellShop))

    @settings.sync
  end

  def self.loadSettings(settingsDialog = nil)
    @farnellShop = @settings.value(FARNELLSHOP_REG).toString
    @farnellApiKey = @settings.value(FARNELLAPI_REG).toString

    if settingsDialog != nil
      settingsDialog.farnellShop = @farnellShop
      settingsDialog.farnellApiKey = @farnellApiKey
    end
  end

  def self.saveBasket(supplierId, basket)
    b = @settings.value(BASKET_REG).toByteArray

    oldBasket = {}
    if b and !b.empty?
      oldBasket = Marshal.load b.to_s
    end

    newBasket = {}
    newBasket[supplierId] = basket.items
    oldBasket.merge! newBasket

    @settings.setValue(
        BASKET_REG,
        Qt::Variant.fromValue(
            Qt::ByteArray.new(Marshal.dump oldBasket)))

    @settings.sync
  end

  def self.loadBasket(storeId, basket)
    ba = @settings.value(BASKET_REG).toByteArray
    if !ba.isEmpty
      baskets = Marshal.load ba.to_s

      if baskets.has_key? storeId
        basket.add baskets[storeId]
      end
    end
  end

  def self.farnellApiKey
    @farnellApiKey
  end
end

class SettingsDialog < Qt::Dialog
  include WidgetHelpers

  signals 'farnellApiKeyChanged(const QString &)',
                'supplierChanged(QObject *)'

  def initialize(parent=nil)
    super

    @farnellShops =%w{
bg.farnell.com
cz.farnell.com
dk.farnell.com
at.farnell.com
ch.farnell.com
de.farnell.com
cpc.farnell.com
cpcireland.farnell.com
export.farnell.com
onecall.farnell.com
ie.farnell.com
il.farnell.com
uk.farnell.com
es.farnell.com
ee.farnell.com
fi.farnell.com
fr.farnell.com
hu.farnell.com
it.farnell.com
lt.farnell.com
lv.farnell.com
be.farnell.com
nl.farnell.com
no.farnell.com
pl.farnell.com
pt.farnell.com
ro.farnell.com
ru.farnell.com
sk.farnell.com
si.farnell.com
se.farnell.com
tr.farnell.com
canada.newark.com
mexico.newark.com
www.newark.com
cn.element14.com
au.element14.com
nz.element14.com
hk.element14.com
sg.element14.com
my.element14.com
ph.element14.com
th.element14.com
in.element14.com
tw.element14.com
kr.element14.com}

    loadUi 'Settings'

    setWindowTitle 'Settings'

    @farnellApiKeyLE = findChild Qt::LineEdit, 'farnellApiKeyLE'
    @farnellShopsCB = findChild Qt::ComboBox, 'farnellShopsCB'
    @buttonBox = findChild Qt::DialogButtonBox, 'buttonBox'

    @farnellShops.each {|s| @farnellShopsCB.addItem s}

    connect @buttonBox, SIGNAL('accepted()'), self, SLOT('accept()')
    connect @buttonBox, SIGNAL('rejected()'), self, SLOT('reject()')
  end

  def farnellApiKey
    return @farnellApiKeyLE.text
  end

  def farnellApiKey=(value)
    @farnellApiKeyLE.setText(value)
    emit farnellApiKeyChanged(value)
  end

  def farnellShop
    return @farnellShopsCB.currentText
  end

  def farnellShop=(value)
    shop = @farnellShops.find_index value
    unless shop
      value = 'uk.farnell.com'
      shop = @farnellShops.find_index value
    end

    @farnellShopsCB.setCurrentIndex shop

    newFarnellSupplier value
  end

  def accept
    save

    newFarnellSupplier @farnellShopsCB.currentText
    emit farnellApiKeyChanged @farnellApiKeyLE.text

    super
  end

  def save
    Settings.saveSettings self
  end

  def load
    Settings.loadSettings self
  end

  private
  def newFarnellSupplier(shopId)
    if $supplier.nil? || $supplier.id != shopId
      $supplier.dispose if $supplier
      $supplier = Farnell.new shopId
      emit supplierChanged $supplier
    end
  end
end