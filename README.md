Electronic Components Panel
===========================

GUI application querying electronic components suppliers stocks. Aimed at hobbyists to safe time when ordering components.

Video:

[![ScreenShot](http://img.youtube.com/vi/2gsDMFoP2yk/0.jpg)](http://youtu.be/2gsDMFoP2yk)

# Features

* GUI itself is a feature ;) No need to use supplier's slow web site.
* Advanced, context sensitive filters. They are written in Ruby so they can get quite complex to suit many filtering needs.
* Loads components from PADS netlists. PADS netlist can be exported from a SPICE simulation software.

# Roadmap

* User-friendly installer.
* Saving basket content with a specific name which can be useful for ordering components for different circuits.
* Stack-able filters.
* Additional APIs will be added like http://octopart.com , https://developers.tme.eu/en/ 

# Technicalities
Ruby 2.0.0+ and Qt were chosen for this application, main reason being the speed of development. The application is rough at the edges at the moment but that will get better.

Works only on Windows at the moment.

## Install

This application is written in Ruby. Ruby installer can be downloaded from http://rubyinstaller.org/

Download Electronic Components Panel and run `bundle install` to install required Ruby gems.

In order to use Farnell remote API, app key needs to be obtained. Each user needs
its own key which can be requested at https://partner.element14.com/member/register
