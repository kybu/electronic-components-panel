require_relative 'helpers'

require 'Qt'

class Settings
  @settings = Qt::Settings.new(
      Qt::Settings.UserScope,
      Qt::Settings.NativeFormat,
      'kybu',
      'Components')

  MAINWINDOW_STATE_REG = 'mainWindowState'
  MAINWINDOW_GEOMETRY_REG = 'mainWindowGeometry'
  FARNELLAPI_REG = 'farnellApiKey'

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

  def self.saveSettings(settings)
    @settings.setValue(
        FARNELLAPI_REG,
        Qt::Variant.fromValue(settings.farnellApiKey))
  end

  def self.loadSettings(settings)
    farnellApiKey = @settings.value(FARNELLAPI_REG).toString

    settings.farnellApiKey = farnellApiKey
  end
end

class SettingsDialog < Qt::Dialog
  include WidgetHelpers

  signals 'farnellApiKeyChanged(const QString &)'

  def initialize(parent=nil)
    super

    loadUi 'Settings'

    setWindowTitle 'Settings'

    @farnellApiKeyLE = findChild Qt::LineEdit, 'farnellApiKeyLE'
    @buttonBox = findChild Qt::DialogButtonBox, 'buttonBox'

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

  def save
    Settings.saveSettings self
  end

  def load
    Settings.loadSettings self
  end
end