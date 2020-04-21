#!/usr/bin/bash


### CONFIG: System nginx configuration directory
NGINX_CONFIG_DIR="/etc/nginx"

### CONFIG: Directory in the project that holds the webserver configuration
WS_CONFIG_DIR="ws_config"

### CONFIG: Projects directory (defauls to ${HOME}/projects)
PROJECTS_DIR=${PROJECTS_DIR:=${HOME}/projects}

### CONFIG: nginx web root
NGINX_WEB_ROOT="/var/www"

### CONFIG: SSL certificate directory
SSL_CERT_DIR="/etc/letsencrypt/live/retrounexpecto.com"

### CONFIG: SSL options files directory
SSL_OPTS_DIR="/etc/letsencrypt"

##############################################################################
#           ***** NO USER SERVICEABLE PARTS BELOW THIS LINE *****            #
##############################################################################

find_bin() {
    local bin_name=$1
    local bin_path=$2

    if [ -x "$2" ]
    then
        echo "$2"
    else
        bin_path="$(which $1 | cut -d' ' -f2)"
        if [ "$bin_path" == "not" ]
        then
            echo "$1"
        else
            echo $bin_path
        fi
    fi
}

LN=$(find_bin "ln" "/usr/bin/ln")
CP=$(find_bin "cp" "/usr/bin/cp")
RM=$(find_bin "rm" "/usr/bin/rm")
BASENAME=$(find_bin "basename" "/usr/bin/basename")
SYSTEMCTL=$(find_bin "systemctl" "/usr/bin/systemctl")
NGINX=$(find_bin "nginx" "/usr/sbin/nginx")

SITE_NAME="$(basename ${PWD%/*})"
CFG="${PROJECTS_DIR}/${SITE_NAME}/ws_config"

SUDO=""
if [ $(id -u) -ne 0 ]
then
    SUDO=$(find_bin "sudo" "/usr/bin/sudo")
fi

generate_nginx_config () {
    local out_file="${CFG}/${SITE_NAME}.nginx"
    echo "* Generating nginx configuration in ${out_file}"
    if [ -f "${out_file}" ]
    then
        echo "    - Preserving old configuration file as ${SITE_NAME}.nginx.save_$$"
        mv "${out_file}" "${CFG}/${SITE_NAME}.nginx.save_$$"
    fi
    echo "##############################################################################" > "${out_file}"
    echo "# nginx configuration for ${SITE_NAME}" >> "${out_file}"
    echo "# Generated at `date`" >> "${out_file}"
    echo "##############################################################################" >> "${out_file}"
    echo "server {" >> "${out_file}"
    echo "    listen [::]:443 ssl; # managed by Certbot" >> "${out_file}"
    echo "    listen 443 ssl; # managed by Certbot" >> "${out_file}"
    echo "" >> "${out_file}"
    echo "    server_name ${SITE_NAME}.com www.${SITE_NAME}.com ${SITE_NAME}.tammymakesthings.com;" >> "${out_file}"
    echo "" >> "${out_file}"
    echo "    root ${NGINX_WEB_ROOT}/${SITE_NAME};" >> "${out_file}"
    echo "" >> "${out_file}"
    echo "    index index.html;" >> "${out_file}"
    echo "" >> "${out_file}"
    echo "    location / {" >> "${out_file}"
    echo "        try_files \$uri \$uri/ =404;" >> "${out_file}"
    echo "    }" >> "${out_file}"
    echo "" >> "${out_file}"
    echo "    location ~ /\.ht {" >> "${out_file}"
    echo "        deny all;" >> "${out_file}"
    echo "    }" >> "${out_file}"
    echo "" >> "${out_file}"
    echo "    ssl_certificate ${SSL_CERT_DIR}/fullchain.pem;" >> "${out_file}"
    echo "    ssl_certificate_key ${SSL_CERT_DIR}/privkey.pem;" >> "${out_file}"
    echo "    include ${SSL_OPTS_DIR}/options-ssl-nginx.conf;" >> "${out_file}"
    echo "    ssl_dhparam ${SSL_OPTS_DIR}/ssl-dhparams.pem;" >> "${out_file}"
    echo "}" >> "${out_file}"
    echo "" >> "${out_file}"
    echo "server {" >> "${out_file}"
    echo "    listen 80;" >> "${out_file}"
    echo "    listen [::]:80;" >> "${out_file}"
    echo "" >> "${out_file}"
    echo "    server_name ${SITE_NAME}.com www.${SITE_NAME}.com ${SITE_NAME}.tammymakesthings.com;" >> "${out_file}"
    echo "" >> "${out_file}"
    echo "    return 301 https://${SITE_NAME}.com\$request_uri;" >> "${out_file}"
    echo "}" >> "${out_file}"
}

dump_vars () {
    echo "Script configuration:"
    echo "    - nginx system config dir: ${NGINX_CONFIG_DIR}"
    echo "    - site name              : ${SITE_NAME}"
    echo "    - project ws config dir  : ${CFG}"
    echo "    - project ws config file : ${CFG}/${SITE_NAME}.nginx"

    if [ "$1" == "verbose" ]
    then
        echo ""
        echo "Tool paths:"
        echo "    - ln        : ${LN}"
        echo "    - cp        : ${CP}"
        echo "    - rm        : ${RM}"
        echo "    - basename  : ${BASENAME}"
        echo "    - systemctl : ${SYSTEMCTL}"
        echo "    - nginx     : ${NGINX}"
        if [ $(id -u) -eq 0 ]
        then
            echo "    - sudo      : not needed"
        else
            echo "    - sudo      : ${SUDO}"
        fi
    fi
    echo ""
}

die () {
    echo "* Error: $2"
    rc=$1
    exit $(($rc + 0))
}

remove_available_cfg () {
    if [ -f "{$NGINX_CONFIG_DIR}/sites-available/${SITE_NAME}" ]
    then
        echo -n "* Removing nginx config from sites-available..."
        ${SUDO} ${RM} -f "${NGINX_CONFIG_DIR}/sites-available/${SITE_NAME}"
        echo "done."
    fi
}

remove_enabled_cfg () {
    if [ -f "{$NGINX_CONFIG_DIR}/sites-enabled/${SITE_NAME}" ]
    then
        echo -n "* Removing nginx config from sites-enabled..."
        ${SUDO} ${RM} -f "${NGINX_CONFIG_DIR}/sites-enabled/${SITE_NAME}"
        echo "done."
    fi
}

install_available_cfg () {
    if [ -f "${NGINX_CONFIG_DIR}/sites-available/${SITE_NAME}" ]
    then
        remove_available_cfg
    fi
    echo -n "* Adding nginx config to sites-available..."
    ${SUDO} ${LN} -s "${CFG}/${SITE_NAME}.nginx" "${NGINX_CONFIG_DIR}/sites-available/${SITE_NAME}"
    echo "done."
}

install_enabled_cfg () {
    if [ -f "${NGINX_CONFIG_DIR}/sites-enabled/${SITE_NAME}" ]
    then
        remove_enabled_cfg
    fi
    echo -n "* Adding nginx config to sites-enabled..."
    ${SUDO} ${LN} -s "${CFG}/${SITE_NAME}.nginx" "${NGINX_CONFIG_DIR}/sites-enabled/${SITE_NAME}"
    echo "done."
}

nginx_config_check () {
    echo "* Checking nginx configuration:"
    ${SUDO} ${NGINX} -t
}

nginx_status () {
    echo "* Checking nginx status:"
    ${SUDO} ${SYSTEMCTL} status nginx
}

nginx_restart () {
    echo -n "* Restarting nginx server..."
    ${SUDO} ${SYSTEMCTL} restart nginx
    echo "done."
}

echo "******************************************************************************"
echo "*                nginx web server configuration utility v1.00                *"
echo "*        Tammy Cravit <tammymakesthings@gmail.com>, v1.00 04/21/2020         *"
echo "******************************************************************************"
echo ""

echo -n "* Validating configuration..."
[ -z "${SITE_NAME}" ]             && die 251 "site name not known"
[ -d "${CFG}" ]                    || die 252 "local config dir ${CFG} not found"
[ -f "${CFG}/${SITE_NAME}.nginx" ] || die 253 "nginx site config file ${CFG}/${SITE_NAME}.nginx not found"

[ -d "${NGINX_CONFIG_DIR}" ]                 || die 210 "nginx config dir ${NGINX_CONFIG_DIR} not found"
[ -d "${NGINX_CONFIG_DIR}/sites-enabled" ]   || die 211 "nginx config dir ${NGINX_CONFIG_DIR}/sites-enabled not found"
[ -d "${NGINX_CONFIG_DIR}/sites-available" ] || die 212 "nginx config dir ${NGINX_CONFIG_DIR}/sites-available not found"

[ -x "${LN}" ]        || die 220 "could not find ln executable"
[ -x "${CP}" ]        || die 221 "could not find cp executable"
[ -x "${RM}" ]        || die 222 "could not find rm executable"
[ -x "${BASENAME}" ]  || die 223 "could not find basename executable"
[ -x "${SYSTEMCTL}" ] || die 224 "could not find systemctl executable"
[ -x "${NGINX}" ]     || die 225 "could not find nginx executable"

if [ $(id -u) -ne 0 ]
then
    [ -x "${SUDO}" ] || die 226, "could not find sudo executable"
fi

echo "done."
echo

case $1 in
    install | i)
        install_available_cfg
        install_enabled_cfg
        ;;
    uninstall | u)
        remove_available_cfg
        remove_enabled_cfg
        ;;
    check | c)
        nginx_config_check
        ;;
    restart | r)
        nginx_restart
        ;;
    status | s)
        nginx_status
        ;;
    enable | e)
        install_enabled_cfg
        ;;
    disable | d)
        remove_enabled_cfg
        ;;
    dumpvars)
        dump_vars "verbose"
        ;;
    genconfig | g)
        generate_nginx_config
        ;;
    *)
        echo "Usage: `basename $0` <command>"
        echo ""
        echo "Available commands:"
        echo ""
        echo "    check     - Verify the nginx configuration"
        echo "    disable   - Disable the nginx configuration"
        echo "    enable    - Enable the nginx configuration"
        echo "    genconfig - Generate an nginx confiugration file"
        echo "    install   - Install the nginx configuration"
        echo "    restart   - Restart nginx (via systemd)"
        echo "    status    - Display the nginx status (via systemd)"
        echo "    uninstall - Uninstall the nginx configuration"
        echo ""
        echo "The first letter of each command can also be used."
        echo ""
        echo "Configuration:"
        dump_vars "normal"
        ;;
esac
