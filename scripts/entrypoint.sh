#!/bin/bash

mount -o bind /tmp/chi/node_modules /chi/node_modules
mount -o bind /tmp/custom-elements/node_modules /chi/src/custom-elements/node_modules
mount -o bind /tmp/chi-vue/node_modules /chi/src/chi-vue/node_modules

mount -t tmpfs tmpfs /chi/src/custom-elements/.stencil
#mkdir /tmp/dist
#mount -o bind /tmp/dist /chi/dist
#mount -t tmpfs tmpfs /chi/dist

RED='\E[0;31m'
GREEN='\E[0;32m'
BLUE='\033[0;34m'
NC='\E[0m' # No Color
PREFIX_VUE="$(tput setaf 4)[VUE]$(tput sgr0) "

# if [ ! -h /chi/src/chi-vue/dist ]; then
#     if [ -d /chi/src/chi-vue/dist ]; then
#         echo -e "${RED}src/chi-vue/dist is a directory. Please, remove it${NC}";
#         exit 1;
#     fi
#     ln -s /chi/dist/js/vue /chi/src/chi-vue/dist || ( echo "Cannot create symbolic link from src/chi-vue/dist to dist/js/vue"; exit 1 )
# fi

if [ ! -h /chi/src/custom-elements/dist ]; then
    if [ -d /chi/src/custom-elements/dist ]; then
        echo -e "${RED}src/custom-elements/dist is a directory. Please, remove it${NC}";
        exit 1;
    fi
    ln -s /chi/dist/js/ce /chi/src/custom-elements/dist || ( echo "Cannot create symbolic link from src/custom-elements/dist to dist/js/ce"; exit 1 )
fi

addheader_chi() {
    while IFS= read -r line; do
        echo -e "${RED}[CHI]${NC} $line "
    done
    tput sgr0
}

addheader_custom_elements() {
    while IFS= read -r line; do
        echo -e "${GREEN}[CE]${NC} $line"
    done
}

addheader_vue() {
    while IFS= read -r line; do
        echo -e "${BLUE}[VUE]${NC} $line"
    done
}

start() {
    cd /chi
    unbuffer npm run start 2>&1 | addheader_chi &

    cd /chi/src/chi-vue
    while [ ! -d /chi/dist/js/vue ]; do sleep 1; done
    unbuffer npm run serve 2>&1 | addheader_vue &
    unbuffer npm run build:umd

    cd /chi/src/custom-elements
    while [ ! -d /chi/dist/js/ce ]; do sleep 1; done
    unbuffer npm run start 2>&1 | addheader_custom_elements
}

build() {
    cd /chi
    unbuffer npm run build 2>&1 | addheader_chi
    cd /chi/src/custom-elements
    unbuffer npm run build 2>&1 | addheader_custom_elements
    cd /chi/src/chi-vue
    unbuffer npm run build:component 2>&1 | sed "s/^[[:space:]]*..*\$/${PREFIX_VUE}&/"
    unbuffer npm run build:umd 2>&1 | sed "s/^[[:space:]]*..*\$/${PREFIX_VUE}&/"
    cd /chi
    unbuffer npm run sri 2>&1 | addheader_chi
    unbuffer npm run update:boilerplate:assets
}

build_tests() {
    cd /chi
    unbuffer npm run build 2>&1 | addheader_chi
    cd /chi/src/custom-elements
    unbuffer npm run build 2>&1 | addheader_custom_elements
    cd /chi/src/chi-vue
    unbuffer npm run build
    cd /chi
    unbuffer npm run sri 2>&1 | addheader_chi
    unbuffer npm run update:boilerplate:assets
}

test() {
    rm -rf /chi/reports /chi/test/bitmaps_test
    mkdir -p /chi/reports/html_report/non_responsive{,_ce}
    mkdir -p /chi/reports/html_report/responsive
    cp -a /chi/config/backstop_data/bitmaps_reference/non_responsive /chi/reports/html_report/non_responsive_ce/bitmaps_reference
    cp -a /chi/config/backstop_data/bitmaps_reference/non_responsive /chi/reports/html_report/non_responsive/bitmaps_reference
    cp -a /chi/config/backstop_data/bitmaps_reference/responsive /chi/reports/html_report/responsive/bitmaps_reference

    cd /chi
    npm run test
    unbuffer npm run sri 2>&1 | addheader_chi
    unbuffer npm run update:boilerplate:assets
}

test_vue() {
    mount -t tmpfs tmpfs /chi/dist
    build_tests
    cd /chi

    unbuffer npx gulp serve 2>&1 >/dev/null &
    unbuffer npx gulp serve:vue 2>&1 >/dev/null &
    unbuffer rm -rf /chi/reports /chi/test/bitmaps_test
    mkdir -p /chi/reports/html_report/non_responsive{,_ce}
    mkdir -p /chi/reports/html_report/responsive
    mkdir -p /chi/reports/html_report/vue

    cp -a /chi/config/backstop_data/bitmaps_reference/non_responsive /chi/reports/html_report/non_responsive_ce/bitmaps_reference
    cp -a /chi/config/backstop_data/bitmaps_reference/non_responsive /chi/reports/html_report/non_responsive/bitmaps_reference
    cp -a /chi/config/backstop_data/bitmaps_reference/responsive /chi/reports/html_report/responsive/bitmaps_reference
    cp -a /chi/config/backstop_data/bitmaps_reference/vue /chi/reports/html_report/vue/bitmaps_reference

    cd /chi
    unbuffer npx backstop test --configPath=backstop-vue.json
}

OPTION=$1
if [ -z ${OPTION} ]; then
    OPTION='start'
fi

case ${OPTION} in
    start)
        mount -t tmpfs tmpfs /chi/dist
        start
        ;;
    build)
        build
        ;;
    test)
        mount -t tmpfs tmpfs /chi/dist
        build
        test
        ;;
    test-vue)
        test_vue
        ;;
    test-e2e)
        mount -t tmpfs tmpfs /chi/dist
        build
        cd /chi
        npx gulp serve 2>&1 >/dev/null &
        ./node_modules/.bin/cypress run
        npx gulp serve:stop
        ;;
    test-e2e-vue)
        mount -t tmpfs tmpfs /chi/dist
        build_tests
        cd /chi
        echo "The current working directory: $PWD"
        npx gulp serve 2>&1 >/dev/null &
                
        npx gulp serve:vue 2>&1 >/dev/null &
        cd /chi/src/chi-vue
        echo "The current working directory: $PWD"
        ./node_modules/.bin/cypress run

        cd ../..
        npx gulp serve:stop
        ;;
    approve)
        cd /chi
        mount -o bind /chi/config/backstop_data/bitmaps_reference/non_responsive /chi/reports/html_report/non_responsive/bitmaps_reference
        mount -o bind /chi/config/backstop_data/bitmaps_reference/responsive /chi/reports/html_report/responsive/bitmaps_reference
        npm run approve
        ;;
    approve-vue)
        cd /chi
        mount -o bind /chi/config/backstop_data/bitmaps_reference/vue /chi/reports/html_report/vue/bitmaps_reference

        npm run approve:vue
        ;;
    *)
        exec "$@"
        ;;
esac