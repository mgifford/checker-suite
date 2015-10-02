#!/bin/bash
# Download selenium server jar file.
selenium_version=2.47
selenium_minor_version=1
file_name=selenium-server-standalone-${selenium_version}.${selenium_minor_version}.jar
wget -N http://selenium-release.storage.googleapis.com/$selenium_version/$file_name
ln -sf $file_name selenium-server-standalone.jar
