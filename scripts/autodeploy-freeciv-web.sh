#!/bin/bash
# Automatic deploy of Freeciv-web.
#
# Checks if Travis CI build is sucessful, then pulls from git,
# and builds, installs and restarts Freeciv-web.

#Requires: https://github.com/travis-ci/travis.rb

SCRIPT_DIR="$(dirname "$0")"
SCRIPT_USER="freeciv"
cd "$(dirname "$0")"
export FREECIV_WEB_DIR="${SCRIPT_DIR}/.."

rm -rf ${FREECIV_WEB_DIR}/logs/autodeploy.log
exec >> ${FREECIV_WEB_DIR}/logs/autodeploy.log
exec 2>&1

echo "Auto-deploy of Freeciv-web from master branch."
date

if travis status -qpx ; then
  echo "Travis CI build passed!"
else
  echo "Travis CI build failed!";
  exit 1;
fi 

cd ${FREECIV_WEB_DIR} && \
sudo -u ${SCRIPT_USER} git pull origin master | grep -q "up-to-date" && \
echo "Freeciv-web is already updated, nothing to build." && exit 1

echo "Freeciv-web updated. Start to rebuild." && \
echo "Building Freeciv..." && \
cd freeciv && \
sudo -u ${SCRIPT_USER} ./prepare_freeciv.sh && cd freeciv && make install && \
echo "Freeciv installed!" && \

echo "Running sync scripts." && \
cd ${FREECIV_WEB_DIR}/scripts/ && sudo -u ${SCRIPT_USER} ./sync-js-hand.sh && \
cd freeciv-img-extract && sudo -u ${SCRIPT_USER} ./sync.sh && \

echo "Building Freeciv-web." && \
cd ../../freeciv-web && sudo -u ${SCRIPT_USER} sh build.sh && \
sudo -u ${SCRIPT_USER} mvn compile flyway:migrate && \

echo "Restarting Freeciv C servers." && \
killall -9 freeciv-web
ps aux | grep -ie publite2 | awk '{print $2}' | xargs kill -9 && 
ps aux | grep -ie freeciv-proxy | awk '{print $2}' | xargs kill -9  
echo "Starting publite2" && \
cd ${FREECIV_WEB_DIR}/publite2/ && \
sudo -u ${SCRIPT_USER} ./run.sh && \

echo "Autodeploy of Freeciv-web is complete."

cat ${FREECIV_WEB_DIR}/logs/autodeploy.log >> /var/lib/tomcat8/webapps/data/autodeploy.log
