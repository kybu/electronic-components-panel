Electronic Components Panel
===========================

GUI application querying electronic components suppliers stocks. Aimed at hobbyist to safe time when ordering components.

Video:

[![ScreenShot](http://img.youtube.com/vi/w-hu01Cg7yE/0.jpg)](http://youtu.be/w-hu01Cg7yE)

# Features

* GUI itself is a feature ;) No need to use supplier's slow web site.
* Advanced, context sensitive filters. They are written in Ruby so they can get quite complex to suit many filtering needs.
* Loads components from PADS netlists. PADS netlist can be exported from a SPICE simulation software.

# Roadmap

Farnell api turned out to be temperamental and not well supported. It randomly does not return component attributes and that limits filters.
Additional APIs will be added like http://octopart.com , https://developers.tme.eu/en/ 

# Technicalities
Ruby 2.0.0+ and Qt were chosen for this application, main reason being the speed of development. The application is rough at the edges at the moment but that will get better.

Works only on Windows at the moment.

## Install

After downloading, run `bundle update` to update required Ruby gems. Add `$farnellApiKey = '<your_key>'` into `components.rb`.
