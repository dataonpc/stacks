#!/bin/bash

#error and force-exit
function die(){
    echo -e "\033[33mERROR: $1 \033[0m" > /dev/null 1>&2
    exit 0
}

#info echo
function print_info(){
    echo -n -e '\e[1;36m'
    echo -n $1
    echo -e '\e[0m'
}

##### echo
function print_xxxx(){
    xXxX="#############################"
    echo
    echo "$xXxX$xXxX$xXxX$xXxX"
    echo
}

#warn echo
function print_warn(){
    echo -n -e '\033[41;37m'
    echo -n $1
    echo -e '\033[0m'
}

#color line
color_line(){
    echo
    while read line
    do
        echo -e "\e[1;33m$line"
        echo
    done
    echo -en "\e[0m"
}

#get random word 
function get_random_word(){
    D_Num_Random="8"
    Num_Random=${1:-$D_Num_Random}
    str=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c $Num_Random`
    echo $str
}

#Default_Ask "what's your name?" "li" "The_name"
#echo $The_name
function Default_Ask(){
    echo
    Temp_question=$1
    Temp_default_var=$2
    Temp_var_name=$3
    if [  -f ${CONFIG_PATH_VARS} ]; then
        New_temp_default_var=`cat $CONFIG_PATH_VARS | grep "^$Temp_var_name=" | cut -d "'" -f 2`
        Temp_default_var=${New_temp_default_var:-$Temp_default_var}
    fi
#if yes or no 
    echo -e -n "\e[1;36m$Temp_question\e[0m""\033[31m(Default:$Temp_default_var)\033[0m"
    echo
    read Temp_var
    if [ "$Temp_default_var" = "y" ] || [ "$Temp_default_var" = "n" ]; then
        Temp_var=$(echo $Temp_var | sed 'y/YESNO0/yesnoo/')
        case $Temp_var in
            y|ye|yes)
                Temp_var=y
                ;;
            n|no)
                Temp_var=n
                ;;
            *)
                Temp_var=$Temp_default_var
                ;;
        esac
    else
        Temp_var=${Temp_var:-$Temp_default_var}        
    fi
    Temp_cmd="$Temp_var_name='$Temp_var'"
    eval $Temp_cmd
    print_info "Your answer is : ${Temp_var}"
    echo
    print_xxxx
}

#Press any key to start 
function press_any_key(){
    echo
    print_info "Press any key to start...or Press Ctrl+C to cancel"
    get_char_ffff(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }    
    get_char_fffff=`get_char_ffff`
    echo
}

function fast_Default_Ask(){
    if [ "$fast_install" = "y" ]; then
        print_info "In the fast mode, $3 will be loaded from $CONFIG_PATH_VARS"
    else
        Default_Ask "$1" "$2" "$3"
        [ -f ${CONFIG_PATH_VARS} ] && sed -i "/^${Temp_var_name}=/d" $CONFIG_PATH_VARS
        echo $Temp_cmd >> $CONFIG_PATH_VARS
    fi
}


function character_Test(){
sed 's/^[ \t]*//' "$1" | grep -v '^#' | grep "$2" > /dev/null 2>&1
[ $? -eq 0 ] && return 0
}


function check_install(){
    exec_name="$1"
    deb_name="$2"
    Deb_N=""
    deb_name=`echo "$deb_name"|sed "s/^${Deb_N}[ \t]*\(.*\)/\1/"`
    for Exe_N in $exec_name
    do
        Deb_N=`echo "$deb_name"|sed 's/^\([^ ]*\).*/\1/'`
        deb_name=`echo "$deb_name"|sed "s/^${Deb_N}[ \t]*\(.*\)/\1/"`
        if (which "$Exe_N" > /dev/null 2>&1);then
            print_info "Check [ $Deb_N ] ok"
        else
            DEBIAN_FRONTEND=noninteractive apt-get -qq -y install "$Deb_N" > /dev/null 2>&1
            apt-get clean
            print_info "Install [ $Deb_N ] ok"
        fi
    done
}



function install_OpenConnect_VPN_server(){
#get base info and base tools
    check_Required
#custom-configuration or not 
    fast_Default_Ask "Install ocserv with Custom Configuration?(y/n)" "n" "Custom_config_ocserv"
    clear && print_xxxx
    [ "$Custom_config_ocserv" = "y" ] && {
        print_info "Install ocserv with custom configuration."
        print_xxxx
        get_Custom_configuration
    }
    [ "$Custom_config_ocserv" = "n" ] && {
        print_info "Automatic installation,choose the plain login."
        print_xxxx
        self_signed_ca="y" && ca_login="n"
    }        
#add a user 
    add_a_user
#press any key to start 
    press_any_key
#install dependencies 
    pre_install
#install ocserv 
    tar_ocserv_install
#make self-signd server-ca 
    [ "$self_signed_ca" = "y" ] && make_ocserv_ca
#make a client cert 
    [ "$ca_login" = "y" ] && {
        [ "$self_signed_ca" = "y" ] && {
            ca_login_clientcert
        }
    }
#configuration 
    set_ocserv_conf
#stop all 
    stop_ocserv
#no certificate,no start 
    [ "$self_signed_ca" = "y" ] && start_ocserv
#show result 显示结果
    show_ocserv    
}


function install_Oneclientcer(){
    [ ! -f ${Script_Dir}/ca-cert.pem ] && die "${Script_Dir}/ca-cert.pem NOT Found."
    [ -f ${Script_Dir}/crl.pem ] && CRL_ADD="y"
    self_signed_ca="y" && ca_login="y"
    check_Required
    Default_Ask "Input your own domain for ocserv." "$ocserv_hostname" "fqdnname"
    get_Custom_configuration_2
    press_any_key
    pre_install && tar_ocserv_install
    make_ocserv_ca
    cd ${Script_Dir}
    rm -rf /etc/ocserv/ca-cert.pem && rm -rf /etc/ocserv/CAforOC
    mv ${Script_Dir}/ca-cert.pem /etc/ocserv
    set_ocserv_conf
    [ "$CRL_ADD" = "y" ] || {
        sed -i 's|^crl =.*|#&|' ${LOC_OC_CONF}
    }
    [ "$CRL_ADD" = "y" ] && {
        mv ${Script_Dir}/crl.pem /etc/ocserv
    }
    stop_ocserv && start_ocserv
    ps cax | grep ocserv > /dev/null 2>&1
    if [ $? -eq 0 ]; then
    print_info "Your install was successful!"
    else
    print_warn "Ocserv start failure,ocserv is offline!"
    print_info "You could check ${Script_Dir}/ocinstall.log"
    fi
}


function check_Required(){
#check root
    [ $EUID -ne 0 ] && die 'Must be run by root user.'
    print_info "Root ok"
#debian-based only
    [ ! -f /etc/debian_version ] && die "Must be run on a Debian-based system."
    print_info "Debian-based ok"
#tun/tap
    [ ! -e /dev/net/tun ] && die "TUN/TAP is not available."
    print_info "TUN/TAP ok"
#check install
    [ -f /usr/sbin/ocserv ] && die "Ocserv has been installed."
    print_info "Not installed ok"
#install base-tools 
    print_info "Installing base-tools......"
    apt-get update  -qq
    check_install "curl vim sudo gawk sed insserv nano" "curl vim sudo gawk sed insserv nano"
    check_install "dig lsb_release" "dnsutils lsb-release"
    insserv -s  > /dev/null 2>&1 || ln -s /usr/lib/insserv/insserv /sbin/insserv
    print_info "Get base-tools ok"
#check systemd
    ocserv_systemd="n"
    pgrep systemd-journal > /dev/null 2>&1 && ocserv_systemd="y"
    print_info "Systemd status : $ocserv_systemd"
#sources check
    source_wheezy_backports="y" && source_jessie="y" && source_stretch="y"
    character_Test "/etc/apt/sources.list" "wheezy-backports" || source_wheezy_backports="n"
    character_Test "/etc/apt/sources.list" "jessie" || source_jessie="n"
	character_Test "/etc/apt/sources.list" "stretch" || source_stretch="n"
    print_info "Sources check ok"
#get info from net 
    print_info "Getting info from net......"
    get_info_from_net
    print_info "Get info ok"
    clear
}

function log_Start(){
    echo "SYS INFO" >${Script_Dir}/ocinstall.log
    echo "" >>${Script_Dir}/ocinstall.log
    sed '/^$/d' /etc/issue >>${Script_Dir}/ocinstall.log
    uname -r >>${Script_Dir}/ocinstall.log
    echo "" >>${Script_Dir}/ocinstall.log
    echo "INSTALL INFO" >>${Script_Dir}/ocinstall.log
    echo "" >>${Script_Dir}/ocinstall.log
}

function get_info_from_net(){
    ocserv_hostname=$(wget -qO- ipv4.icanhazip.com)
    if [ $? -ne 0 -o -z $ocserv_hostname ]; then
        ocserv_hostname=`dig +short +tcp myip.opendns.com @resolver1.opendns.com`
    fi
    OC_version_latest=$(curl -sL "http://ocserv.gitlab.io/www/download.html" | sed -n 's/^.*version is <b>\(.*$\)/\1/p')
}

function get_Custom_configuration(){
#whether to use the certificate login 
    fast_Default_Ask "Whether to choose the certificate login?(y/n)" "n" "ca_login"
#whether to generate a Self-signed CA 
    fast_Default_Ask "Generate a Self-signed CA for your server?(y/n)" "y" "self_signed_ca"
    if [ "$self_signed_ca" = "n" ]; then
        Default_Ask "Input your own domain for ocserv." "$ocserv_hostname" "fqdnname"
    else 
        fast_Default_Ask "Your CA's name?" "ocvpn" "caname"
        fast_Default_Ask "Your Organization name?" "ocvpn" "ogname"
        fast_Default_Ask "Your Company name?" "ocvpn" "coname"
        Default_Ask "Your server's domain?" "$ocserv_hostname" "fqdnname"
    fi
#question part 2
    get_Custom_configuration_2
}

function get_Custom_configuration_2(){
#Which ocserv version to install ocserv
    [ "$OC_version_latest" = "" ] && {
        print_warn "Could not connect to the official website,download ocserv from github."
        print_xxxx
    } || {
        fast_Default_Ask "$OC_version_latest is the latest,but default version is recommended.Which to choose?" "$Default_oc_version" "oc_version"
    }
#which port to use for verification 
    fast_Default_Ask "Which port to use for verification?(Tcp-Port)" "4443" "ocserv_tcpport_set"
#tcp-port only or not ，udp
    fast_Default_Ask "Only use tcp-port or not?(y/n)" "n" "only_tcp_port"
#which port to use for data transmission udp 
    if [ "$only_tcp_port" = "n" ]; then
        fast_Default_Ask "Which port to use for data transmission?(Udp-Port)" "1999" "ocserv_udpport_set"
    fi
#boot from the start 
    fast_Default_Ask "Start ocserv when system is started?(y/n)" "y" "ocserv_boot_start"
#Save user vars or not 
    fast_Default_Ask "Save the vars for fast mode or not?" "n" "save_user_vars"
}

#add a user 
function add_a_user(){
    if [ "$ca_login" = "n" ]; then
        Default_Ask "Input your username for ocserv." "$(get_random_word 4)" "username"
        Default_Ask "Input your password for ocserv." "$(get_random_word 6)" "password"
    fi
    if [ "$ca_login" = "y" ] && [ "$self_signed_ca" = "y" ]; then
        Default_Ask "Input a name for your p12-cert file." "$(get_random_word 4)" "name_user_ca"
        while [ -d /etc/ocserv/CAforOC/user-${name_user_ca} ]; do
            Default_Ask "The name already exists,change one please!" "$(get_random_word 4)" "name_user_ca"
        done
        Default_Ask "Input your password for your p12-cert file." "$(get_random_word 4)" "password"
#set expiration days for client p12-cert 
        Default_Ask "Input the number of expiration days for your p12-cert file." "7777" "oc_ex_days"
    fi
}

#dependencies onebyone
function Dependencies_install_onebyone(){
    for OC_DP in $oc_dependencies
    do
        print_info "Installing $OC_DP "
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $TEST_S $OC_DP
        if [ $? -eq 0 ]; then
            print_info "Install [ ${OC_DP} ] ok!"
            apt-get clean
        else
            print_warn "[ ${OC_DP} ] not be installed!"
        fi
    done
}

#lz4 from github
function tar_lz4_install(){
    print_info "Installing lz4 from github"
    DEBIAN_FRONTEND=noninteractive apt-get -y -qq remove --purge liblz4-dev
    mkdir lz4
    LZ4_VERSION=`curl -sL "https://github.com/Cyan4973/lz4/releases/latest" | sed -n 's/^.*tag\/\([^"]*\).*/\1/p' | head -n1` 
    curl -SL "https://github.com/Cyan4973/lz4/archive/$LZ4_VERSION.tar.gz" -o lz4.tar.gz
    tar -xf lz4.tar.gz -C lz4 --strip-components=1 
    rm lz4.tar.gz 
    cd lz4 
    make -j"$(nproc)" && make install
    cd ..
    rm -r lz4
    if [ `getconf WORD_BIT` = '32' ] && [ `getconf LONG_BIT` = '64' ]; then
        ln -sf /usr/local/lib/liblz4.* /usr/lib/x86_64-linux-gnu/
    else
        ln -sf /usr/local/lib/liblz4.* /usr/lib/i386-linux-gnu/
    fi
    print_info "[ lz4 ] ok"
}

#install freeradius-client
function tar_freeradius_client_install(){
    print_info "Installing freeradius-client"
    DEBIAN_FRONTEND=noninteractive apt-get -y -qq remove --purge freeradius-client*
    unzip freeradius-client-master.zip
    cd freeradius-client-master
    ./configure --prefix=/usr --sysconfdir=/etc
    make -j"$(nproc)" && make install
    cd ..
    rm -rf freeradius-client-master*
    print_info "[ freeradius-client ] ok"
}

function test_source_install(){
    [ "$1" = "n" ] && {
        echo "deb http://ftp.debian.org/debian $2 main contrib non-free" >> /etc/apt/sources.list.d/ocserv.list
        apt-get update
    }
    oc_dependencies="$3" && TEST_S="-t $2 -f --force-yes"
    Dependencies_install_onebyone
    [ "$1" = "n" ] && {
        rm -rf /etc/apt/sources.list.d/ocserv.list
        apt-get update
    }
}

#install dependencies 
function pre_install(){
#keep kernel 
    echo linux-image-`uname -r` hold | dpkg --set-selections > /dev/null 2>&1
    apt-get upgrade -y
    echo linux-image-`uname -r` install | dpkg --set-selections > /dev/null 2>&1
#no upgrade from test sources 
    [ ! -d /etc/apt/preferences.d ] && mkdir /etc/apt/preferences.d
    [ ! -d /etc/apt/apt.conf.d ] && mkdir /etc/apt/apt.conf.d
    [ ! -d /etc/apt/sources.list.d ] && mkdir /etc/apt/sources.list.d    
    cat > /etc/apt/preferences.d/my_ocserv_preferences<<'EOF'
Package: *
Pin: release wheezy
Pin-Priority: 900
Package: *
Pin: release wheezy-backports
Pin-Priority: 90
EOF
    cat > /etc/apt/apt.conf.d/77ocserv<<'EOF'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APT::Get::Install-Recommends "false";
APT::Get::Install-Suggests "false";
EOF
#gnutls-bin(certtool) is too old on wheezy/trusty/utopic,bugs with only one OU etc
#gnutls-bin（certtool）于wheezy/trusty/utopic，OU
    [ "$oc_D_V" = "wheezy" ] || {
        oc_add_dependencies="libgnutls28-dev libseccomp-dev libhttp-parser-dev libkrb5-dev"
        [ "$oc_D_V" = "trusty" ] || {
            oc_add_dependencies="$oc_add_dependencies libprotobuf-c-dev"
            [ "$oc_D_V" = "utopic" ] || {
                oc_add_dependencies="$oc_add_dependencies gnutls-bin"
            }
        }     
    }
    oc_dependencies="openssl autogen gperf pkg-config make gcc m4 build-essential libgmp3-dev libwrap0-dev libpam0g-dev libdbus-1-dev libnl-route-3-dev libopts25-dev libnl-nf-3-dev libreadline-dev libpcl1-dev libtalloc-dev libev-dev liboath-dev $oc_add_dependencies"
    TEST_S=""
    Dependencies_install_onebyone   
#install dependencies from wheezy-backports for debian wheezy
    [ "$oc_D_V" = "wheezy" ] && {
        test_source_install "$source_wheezy_backports" "wheezy-backports" "gnutls-bin libgnutls28-dev libseccomp-dev"  
    }
#install dependencies from jessie for ubuntu 14.04
    [ "$oc_D_V" = "trusty" ] && {
        test_source_install "$source_jessie" "jessie" "gnutls-bin libtasn1-6-dev libtasn1-3-dev libtasn1-3-bin libtasn1-6-dbg libtasn1-bin libtasn1-doc"
    }
#install dependencies from jessie for ubuntu 14.10
    [ "$oc_D_V" = "utopic" ] && {
        test_source_install "$source_jessie" "jessie" "gnutls-bin"
    }
#install freeradius-client-1.1.7
    tar_freeradius_client_install
#install lz4
    tar_lz4_install
#clean
    apt-get autoremove -qq -y && apt-get clean
    rm -f /etc/apt/preferences.d/my_ocserv_preferences
    rm -f /etc/apt/apt.conf.d/77ocserv
    print_info "Dependencies  ok"
}

#install ocserv 
function tar_ocserv_install(){
    cd ${Script_Dir}
#default version
    oc_version=${oc_version:-${Default_oc_version}}
    [ "$OC_version_latest" = "" ] && {
#dummy version
        oc_version='1.1.6'
        curl -SOL "https://raw.githubusercontent.com/dataonpc/stacks/master/oc.zip"
    } || {
        wget -c ftp://ftp.infradead.org/pub/ocserv/ocserv-1.1.6.tar.xz
    }
    tar xvf ocserv-1.1.6.tar.xz
    rm -rf ocserv-1.1.6.tar.xz
    cd ocserv-1.1.6
#0.10.6-fix
    [ "$oc_version" = "0.10.6" ] && {
        #http://git.infradead.org/ocserv.git/commitdiff/747346c7e6c56f91757b515dd20be6517a9e3b5c?hp=63fa6baa85b622ddabe60c147985280c54087332
        sed -i 's|#ifdef __linux__|#if defined(__linux__) \&\&!defined(IPV6_PATHMTU)|' src/worker-vpn.c
        sed -i '/\/\* for IPV6_PATHMTU \*\//d' src/worker-vpn.c
        sed -i 's|# include <linux/in6.h>|# define IPV6_PATHMTU 61|' src/worker-vpn.c
    }
    ./configure --prefix=/usr --sysconfdir=/etc $Extra_Options
    make -j"$(nproc)"
    make install
#check install 
    [ ! -f /usr/sbin/ocserv ] && {
        print_warn "Fail..."
        make clean
        die "Ocserv install failure,check ${Script_Dir}/ocinstall.log"
    }
#mv files
    mkdir -p /etc/ocserv/CAforOC/revoke > /dev/null 2>&1
    mkdir /etc/ocserv/{config-per-group,defaults} > /dev/null 2>&1
    cp doc/profile.xml /etc/ocserv
    sed -i "s|localhost|$ocserv_hostname|" /etc/ocserv/profile.xml
    cd ..
    rm -rf ocserv-$oc_version
#get or set config file
    cd /etc/ocserv
    [ ! -f /etc/init.d/ocserv ] && {
        wget -c --no-check-certificate $NET_OC_CONF_DOC/ocserv -O /etc/init.d/ocserv
        chmod 755 /etc/init.d/ocserv
        [ "$ocserv_systemd" = "y" ] && systemctl daemon-reload > /dev/null 2>&1
    }
    [ ! -f ocserv-up.sh ] && {
        wget -c --no-check-certificate $NET_OC_CONF_DOC/ocserv-up.sh
        chmod +x ocserv-up.sh
    }
    [ ! -f ocserv-down.sh ] && {
        wget -c --no-check-certificate $NET_OC_CONF_DOC/ocserv-down.sh
        chmod +x ocserv-down.sh
    }
    [ ! -f ocserv.conf ] && {
        wget -c --no-check-certificate $NET_OC_CONF_DOC/ocserv.conf
    }
    [ ! -f config-per-group/Route ] && {
        wget -c --no-check-certificate $NET_OC_CONF_DOC/Route -O config-per-group/Route
    }
    [ ! -f dh.pem ] && {
        print_info "Perhaps generate DH parameters will take some time , please wait..."
        certtool --generate-dh-params --sec-param medium --outfile dh.pem
    }
    clear
    print_info "Ocserv install ok"
}

function make_ocserv_ca(){
    print_info "Generating Self-signed CA..."
#all in one doc
    cd /etc/ocserv/CAforOC
#Self-signed CA set
#ca's name#organization name#company name#server's FQDN
    caname=${caname:-ocvpn}
    ogname=${ogname:-ocvpn}
    coname=${coname:-ocvpn}
    fqdnname=${fqdnname:-$ocserv_hostname}
#generating the CA 
#crl_dist_points ocserv crl
    openssl genrsa -out ca-key.pem 4096
    cat << _EOF_ > ca.tmpl
cn = "$caname"
organization = "$ogname"
serial = 1
expiration_days = 7777
ca
signing_key
cert_signing_key
crl_signing_key
# An URL that has CRLs (certificate revocation lists)
# available. Needed in CA certificates.
#crl_dist_points = "http://www.getcrl.crl/getcrl/"
_EOF_
    certtool --generate-self-signed --hash SHA256 --load-privkey ca-key.pem --template ca.tmpl --outfile ca-cert.pem
#generating a local server key-certificate pair 
    openssl genrsa -out server-key.pem 2048
    cat << _EOF_ > server.tmpl
cn = "$fqdnname"
organization = "$coname"
serial = 2
expiration_days = 7777
signing_key
encryption_key
tls_www_server
_EOF_
    certtool --generate-certificate --hash SHA256 --load-privkey server-key.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem
    [ ! -f server-cert.pem ] && die "server-cert.pem NOT Found , make failure!"
    [ ! -f server-key.pem ] && die "server-key.pem NOT Found , make failure!"
#
    cat ca-cert.pem >> server-cert.pem
    cp server-cert.pem /etc/ocserv && cp server-key.pem /etc/ocserv
    cp ca-cert.pem /etc/ocserv
    print_info "Self-signed CA for ocserv ok"
}

function ca_login_clientcert(){
#generate a client cert
    print_info "Generating a client cert..."
    cd /etc/ocserv/CAforOC
    caname=`openssl x509 -noout -subject -in ca-cert.pem|sed -n 's/.*CN=\([^=]*\)\/.*/\1/p'`
    if [ "X${caname}" = "X" ]; then
        Default_Ask "Tell me your CA's name." "ocvpn" "caname"
    fi
    name_user_ca=${name_user_ca:-$(get_random_word 4)}
    while [ -d user-${name_user_ca} ]; do
        name_user_ca=$(get_random_word 4)
    done
    mkdir user-${name_user_ca}
    oc_ex_days=${oc_ex_days:-7777}
    cat << _EOF_ > user-${name_user_ca}/user.tmpl
cn = "${name_user_ca}"
unit = "Route"
#unit = "All"
uid ="${name_user_ca}"
expiration_days = ${oc_ex_days}
signing_key
tls_www_client
_EOF_
#two group then two unit,but IOS anyconnect does not surport. 
    [ "$open_two_group" = "y" ] && sed -i 's/^#//' user-${name_user_ca}/user.tmpl
#user key
    openssl genrsa -out user-${name_user_ca}/user-${name_user_ca}-key.pem 2048
#user cert
    certtool --generate-certificate --hash SHA256 --load-privkey user-${name_user_ca}/user-${name_user_ca}-key.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem --template user-${name_user_ca}/user.tmpl --outfile user-${name_user_ca}/user-${name_user_ca}-cert.pem
#p12
    openssl pkcs12 -export -inkey user-${name_user_ca}/user-${name_user_ca}-key.pem -in user-${name_user_ca}/user-${name_user_ca}-cert.pem -name "${name_user_ca}" -certfile ca-cert.pem -caname "$caname" -out user-${name_user_ca}/user-${name_user_ca}.p12 -passout pass:$password
#cp to ${Script_Dir}
    cp user-${name_user_ca}/user-${name_user_ca}.p12 ${Script_Dir}/${name_user_ca}.p12
    empty_revocation_list
    print_info "Generate client cert ok"
}

function empty_revocation_list(){
#generate a empty revocation list
    [ ! -f crl.tmpl ] && {
    cat << _EOF_ >crl.tmpl
crl_next_update = 7777 
crl_number = 1 
_EOF_
    certtool --generate-crl --load-ca-privkey ca-key.pem --load-ca-certificate ca-cert.pem --template crl.tmpl --outfile ../crl.pem
    }
}

#modify config file 
function set_ocserv_conf(){
#default vars
    ocserv_tcpport_set=${ocserv_tcpport_set:-4443}
    ocserv_udpport_set=${ocserv_udpport_set:-1999}
    save_user_vars=${save_user_vars:-n}
    ocserv_boot_start=${ocserv_boot_start:-y}
    only_tcp_port=${only_tcp_port:-n}
#set port
    sed -i "s|\(tcp-port = \).*|\1$ocserv_tcpport_set|" ${LOC_OC_CONF}
    sed -i "s|\(udp-port = \).*|\1$ocserv_udpport_set|" ${LOC_OC_CONF}
#default domain compression dh.pem
    sed -i "s|^[# \t]*\(default-domain = \).*|\1$fqdnname|" ${LOC_OC_CONF}
    sed -i "s|^[# \t]*\(compression = \).*|\1true|" ${LOC_OC_CONF}
    sed -i 's|^[# \t]*\(dh-params = \).*|\1/etc/ocserv/dh.pem|' ${LOC_OC_CONF}
#2-group  bug Default
    [ "$open_two_group" = "y" ] && two_group_set
    echo "route = 0.0.0.0/128.0.0.0" > /etc/ocserv/defaults/group.conf
    echo "route = 128.0.0.0/128.0.0.0" >> /etc/ocserv/defaults/group.conf
    echo "route = 0.0.0.0/128.0.0.0" > /etc/ocserv/config-per-group/All
    echo "route = 128.0.0.0/128.0.0.0" >> /etc/ocserv/config-per-group/All
#boot from the start 
    [ "$ocserv_boot_start" = "y" ] && {
        print_info "Enable ocserv service to start during bootup."
        [ "$ocserv_systemd" = "y" ] && {
            systemctl enable ocserv > /dev/null 2>&1 || insserv ocserv > /dev/null 2>&1
        }
        [ "$ocserv_systemd" = "n" ] && insserv ocserv > /dev/null 2>&1
    }
#add a user ，the plain login 
    [ "$ca_login" = "n" ] && plain_login_set
#only tcp-port
    [ "$only_tcp_port" = "y" ] && sed -i 's|^[ \t]*\(udp-port = \)|#\1|' ${LOC_OC_CONF}
#setup the cert login
    [ "$ca_login" = "y" ] && {
        sed -i 's|^[ \t]*\(auth = "plain\)|#\1|' ${LOC_OC_CONF}
        sed -i 's|^[# \t]*\(auth = "certificate"\)|\1|' ${LOC_OC_CONF}
        ca_login_set
    }
#save custom-configuration files or not
    [ "$save_user_vars" = "n" ] && rm -f $CONFIG_PATH_VARS
    print_info "Set ocserv ok"
}

function two_group_set(){
    sed -i 's|^[# \t]*\(cert-group-oid = \).*|\12.5.4.11|' ${LOC_OC_CONF}
    sed -i 's|^[# \t]*\(select-group = \)group1.*|\1Route|' ${LOC_OC_CONF}
    sed -i 's|^[# \t]*\(select-group = \)group2.*|\1All|' ${LOC_OC_CONF}
#    sed -i 's|^[# \t]*\(default-select-group = \).*|\1Default|' ${LOC_OC_CONF}
    sed -i 's|^[# \t]*\(auto-select-group = \).*|\1false|' ${LOC_OC_CONF}
    sed -i 's|^[# \t]*\(config-per-group = \).*|\1/etc/ocserv/config-per-group|' ${LOC_OC_CONF}
#    sed -i 's|^[# \t]*\(default-group-config = \).*|\1/etc/ocserv/defaults/group.conf|' ${LOC_OC_CONF}
}

function plain_login_set(){
    [ "$open_two_group" = "y" ] && group_name='-g "Route,All"'
    (echo "$password"; sleep 1; echo "$password") | ocpasswd -c /etc/ocserv/ocpasswd $group_name $username
}

function ca_login_set(){
    sed -i 's|^[# \t]*\(ca-cert = \).*|\1/etc/ocserv/ca-cert.pem|' ${LOC_OC_CONF}
    sed -i 's|^[# \t]*\(crl = \).*|\1/etc/ocserv/crl.pem|' ${LOC_OC_CONF}
#
    sed -i 's|^[# \t]*\(cert-user-oid = \).*|\12\.5\.4\.3|' ${LOC_OC_CONF}
#
#    sed -i 's|^[# \t]*\(cert-user-oid = \).*|\10\.9\.2342\.19200300\.100\.1\.1|' ${LOC_OC_CONF}
}

function stop_ocserv(){
    /etc/init.d/ocserv stop
    oc_pid=`pidof ocserv`
    if [ ! -z "$oc_pid" ]; then
        for pid in $oc_pid
        do
            kill -9 $pid > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "Ocserv process[$pid] has been killed"
            fi
        done
    fi
}

function start_ocserv(){
    [ ! -f /etc/ocserv/server-cert.pem ] && die "server-cert.pem NOT Found !!!"
    [ ! -f /etc/ocserv/server-key.pem ] && die "server-key.pem NOT Found !!!"
    /etc/init.d/ocserv start
}

function show_ocserv(){
    ocserv_port=`sed -n 's/^[ \t]*tcp-port[ \t]*=[ \t]*//p' ${LOC_OC_CONF}`
    clear
    echo
    ps cax | grep ocserv > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\033[41;37mYour Server Domain :\033[0m\t\t$fqdnname:$ocserv_port"
        if [ "$ca_login" = "y" ]; then
            get_new_userca_show
        else
            echo -e "\033[41;37mYour Username :\033[0m\t\t\t$username"
            echo -e "\033[41;37mYour Password :\033[0m\t\t\t$password"
            echo
            print_info "You could use ' sudo ocpasswd -c /etc/ocserv/ocpasswd username ' to add users. "
        fi
        print_info "You could stop ocserv by ' /etc/init.d/ocserv stop '!"
        print_info "Boot from the start or not, use ' sudo insserv ocserv ' or ' sudo insserv -r ocserv '."
        echo
        print_info "Enjoy it!"
        echo
    elif [ "$self_signed_ca" = "n" -a "$ca_login" = "n" ]; then
        echo -e "\033[41;37mYour Username :\033[0m\t\t\t$username"
        echo -e "\033[41;37mYour Password :\033[0m\t\t\t$password"
        echo
        print_info "1,You should change Server Certificate and Server Key's name to server-cert.pem and server-key.pem !"
        print_info "2,You should put them to /etc/ocserv !"
        print_info "3,You could start ocserv by ' /etc/init.d/ocserv start ' !"
        print_info "4,You could use ' sudo ocpasswd -c /etc/ocserv/ocpasswd username ' to add users."
        print_info "5,Boot from the start or not, use ' sudo insserv ocserv ' or ' sudo insserv -r ocserv '."
        echo
    elif [ "$self_signed_ca" = "n" -a "$ca_login" = "y" ]; then
        print_info "1,You should change your Server Certificate and Server Key's name to server-cert.pem and server-key.pem !"
        print_info "2,You should change your Certificate Authority Certificates and Certificate Authority Key's  name to ca-cert.pem and ca-key.pem !"
        print_info "3,You should put server-cert.pem server-key.pem and ca-cert.pem to /etc/ocserv !"
        print_info "4,You should put ca-cert.pem and ca-key.pem to /etc/ocserv/CAforOC !"
        print_info "5,You could use ' bash `basename $0` gc ' to generate a new client-cert."
        print_info "6,You could start ocserv by ' /etc/init.d/ocserv start '."
        print_info "7,Boot from the start or not, use ' sudo insserv ocserv ' or ' sudo insserv -r ocserv '."
        echo
    else
        die "Ocserv start failure,check ${Script_Dir}/ocinstall.log"
    fi
}

function check_ca_cert(){
    [ ! -f /usr/sbin/ocserv ] && die "Ocserv NOT Found !!!"
    [ ! -f /etc/ocserv/CAforOC/ca-key.pem ] && die "ca-key.pem NOT Found !!!"
    [ ! -f /etc/ocserv/CAforOC/ca-cert.pem ] && die "ca-cert.pem NOT Found !!!"
}

function get_new_userca(){
    check_ca_cert
    ca_login="y" && self_signed_ca="y"
    add_a_user
    press_any_key
    ca_login_clientcert
    clear
    echo
}

function get_new_userca_show(){
    echo -e "\033[41;37mClient-cert Password :\033[0m\t\t$password"
    echo -e "\033[41;37mClient-cert Expiration Days :\033[0m\t$oc_ex_days"
    echo
    print_info "You should import the client certificate to your device at first."
    print_info "You could get ${name_user_ca}.p12 from ${Script_Dir}."
    print_info "You could use ' bash `basename $0` gc ' to generate a new client-cert."
    print_info "You could use ' bash `basename $0` rc ' to revoke an old client-cert."
}

function Outdate_Autoclean(){
    My_All_Ca=`ls -F|sed -n 's/\(user-.*\)\//\1/p'|sed ':a;N;s/\n/ /;ba;'`
    Today_Date=`date +%s`
    for My_One_Ca in ${My_All_Ca}
    do
        Client_EX_Date=`openssl x509 -noout -enddate -in ${My_One_Ca}/${My_One_Ca}-cert.pem | cut -d= -f2`
        Client_EX_Date=`date -d "${Client_EX_Date}" +%s`
        [ ${Client_EX_Date} -lt ${Today_Date} ] && {
            My_One_Ca_Now="${My_One_Ca}_${Today_Date}"
            mv ${My_One_Ca} ${My_One_Ca_Now}
            mv ${My_One_Ca_Now} -t revoke/
        }
    done
}

function revoke_userca(){
    check_ca_cert
#input info
    cd /etc/ocserv/CAforOC
    Outdate_Autoclean
    clear
    print_xxxx
    print_info "The following is the user list..."
    echo
    ls -F|grep /|grep user|cut -d/ -f1|color_line
    print_xxxx
    print_info "Which user do you want to revoke?"
    echo
    read -p "Which: " -e -i user- revoke_ca
    if [ ! -f /etc/ocserv/CAforOC/$revoke_ca/$revoke_ca-cert.pem ]
    then
        die "$revoke_ca NOT Found !!!"
    fi
    echo
    print_warn "Okay,${revoke_ca} will be revoked."
    print_xxxx
    press_any_key
#revoke   
    cat ${revoke_ca}/${revoke_ca}-cert.pem >>revoked.pem
    certtool --generate-crl --load-ca-privkey ca-key.pem --load-ca-certificate ca-cert.pem --load-certificate revoked.pem --template crl.tmpl --outfile ../crl.pem
    revoke_ca_now="${revoke_ca}_$(date +%s)"
    mv  ${revoke_ca} ${revoke_ca_now}
    mv  ${revoke_ca_now} revoke/
    print_info "${revoke_ca} was revoked."
    echo    
}

function reinstall_ocserv(){
    stop_ocserv
    rm -rf /etc/ocserv
    rm -rf /usr/sbin/ocserv
    rm -rf /etc/init.d/ocserv
    rm -rf /usr/bin/occtl
    rm -rf /usr/bin/ocpasswd
    install_OpenConnect_VPN_server
}

function upgrade_ocserv(){    
    get_info_from_net
    [ "$OC_version_latest" = "" ] && {
    die "Could not connect to the official website."
    }
    Default_Ask "The latest is ${OC_version_latest} ,Input the version you want to upgrade." "$OC_version_latest" "oc_version"
    press_any_key
    stop_ocserv
    rm -f /etc/ocserv/profile.xml
    rm -f /usr/sbin/ocserv
    tar_ocserv_install
    start_ocserv
    ps cax | grep ocserv > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_info "Your ocserv upgrade was successful!"
    else
        print_warn "Ocserv start failure,ocserv is offline!"
        print_info "You could use ' bash `basename $0` ri' to forcibly upgrade your ocserv."
    fi
}

function enable_both_login(){
    character_Test ${LOC_OC_CONF} 'auth = "plain' && {
        character_Test ${LOC_OC_CONF} 'enable-auth = certificate' && {
            die "You have enabled the plain and the certificate login."
        }
        enable_both_login_open_ca
    }
    character_Test ${LOC_OC_CONF} 'auth = "certificate"' && {
    enable_both_login_open_plain
    }
}

function enable_both_login_open_ca(){
    get_new_userca
    sed -i 's|^[# \t]*\(enable-auth = certificate\)|\1|' ${LOC_OC_CONF}
    ca_login_set
    stop_ocserv
    start_ocserv
    clear
    echo
    print_info "The plain login and the certificate login are Okay~"
    print_info "The following is your certificate login info~"
    echo
    get_new_userca_show
    echo
}

function enable_both_login_open_plain(){
    ca_login="n"
    add_a_user
    press_any_key
    plain_login_set
    sed -i 's|^[ \t]*\(auth = "certificate"\)|#\1|' ${LOC_OC_CONF}
    sed -i 's|^[# \t]*\(auth = "plain\)|\1|' ${LOC_OC_CONF}
    sed -i 's|^[# \t]*\(enable-auth = certificate\)|\1|' ${LOC_OC_CONF}
    stop_ocserv
    start_ocserv
    clear
    echo
    print_info "The plain login and the certificate login are Okay~"
    print_info "The following is your plain login info~"
    echo
    echo -e "\033[41;37mYour Username :\033[0m\t\t\t$username"
    echo -e "\033[41;37mYour Password :\033[0m\t\t\t$password"
    echo
}

function help_ocservauto(){
    print_xxxx
    print_info "######################## Parameter Description ####################################"
    echo
    print_info " install ----------------------- Install ocserv for Debian 7+, Ubuntu 14.04+"
    echo
    print_info " fastmode or fm ---------------- Rapid installation for ocserv through $CONFIG_PATH_VARS"
    echo
    print_info " getuserca or gc --------------- Get a new client certificate"
    echo
    print_info " revokeuserca or rc ------------ Revoke a client certificate"
    echo
    print_info " upgrade or ug ----------------- Smoothly upgrade your ocserv"
    echo
    print_info " reinstall or ri --------------- Force to reinstall your ocserv(Destroy All Data)"
    echo
    print_info " pc ---------------------------- At the same time,enable the plain and the certificate login"
    echo
    print_info " occ --------------------------- Verify client certificates through a existing CA"
    echo
    print_info " help or h --------------------- Show this description"
    print_xxxx
}

#################################################################################################################
#surport system codename                                                                                        #
#################################################################################################################

#
function surport_Syscodename(){
    oc_D_V=$(lsb_release -c -s)
    [ "$oc_D_V" = "wheezy" ] && return 0
    [ "$oc_D_V" = "jessie" ] && return 0
    [ "$oc_D_V" = "stretch" ] && return 0
    [ "$oc_D_V" = "trusty" ] && return 0
    [ "$oc_D_V" = "utopic" ] && return 0
    [ "$oc_D_V" = "vivid" ] && return 0
    [ "$oc_D_V" = "wily" ] && return 0
    [ "$oc_D_V" = "xenial" ] && return 0
    #TEST NEWER SYS 
    #[ "$oc_D_V" = "$oc_D_V" ] && return 0
###############################
# # 
# D_V=( wheezy jessie trusty utopic vivid )
# for DV in ${D_V[*]}
# do
# [ "$oc_D_V" = "$DV" ] && return 0
# done
###############################
}

#
Script_Dir="$(cd "$(dirname $0)"; pwd)"
#
CONFIG_PATH_VARS="${Script_Dir}/vars_ocservauto"
#
LOC_OC_CONF="/etc/ocserv/ocserv.conf"

##################################################################################################################
#main                                                                                                            #
##################################################################################################################
clear
echo "==============================================================================================="
echo
print_info " System Required:  Debian 7+, Ubuntu 14.04+"
echo
print_info " Description:  Install OpenConnect VPN server"
echo
print_info " Help Info:  bash `basename $0` help"
echo
echo "==============================================================================================="

#ocserv
#fork，
NET_OC_CONF_DOC="https://raw.githubusercontent.com/dataonpc/ocs/master/"
#
Default_oc_version="0.12.6"
#，AllRoute
#All，Route
#
#，ios anyconnect bug，
#
open_two_group="n"
#
#Extra_Options="--with-local-talloc --enable-local-libopts --without-pcl-lib  --without-http-parser --without-protobuf"
#./configure --help ocserv
Extra_Options=""

#Initialization step
action=$1
[  -z $1 ] && action=install
case "$action" in
install)
    log_Start
    install_OpenConnect_VPN_server | tee -a ${Script_Dir}/ocinstall.log
    ;;
fastmode | fm)
    [ ! -f $CONFIG_PATH_VARS ] && die "$CONFIG_PATH_VARS Not Found !"
    fast_install="y"
    . $CONFIG_PATH_VARS
    log_Start
    install_OpenConnect_VPN_server | tee -a ${Script_Dir}/ocinstall.log
    ;;
upgrade | ug)
    log_Start
    upgrade_ocserv | tee -a ${Script_Dir}/ocinstall.log
    ;;
reinstall | ri)
    log_Start
    reinstall_ocserv | tee -a ${Script_Dir}/ocinstall.log
    ;;
occ)
    log_Start
    install_Oneclientcer | tee -a ${Script_Dir}/ocinstall.log
    ;;
getuserca | gc)
    character_Test ${LOC_OC_CONF} 'auth = "plain' && {
        character_Test ${LOC_OC_CONF} 'enable-auth = certificate' || {
            die "You have to enable the the certificate login at first."
        }
    }
    get_new_userca
    get_new_userca_show
    ;;
revokeuserca | rc)
    revoke_userca
    ;;
pc)
    enable_both_login
    ;;
help | h)
    clear
    help_ocservauto
    ;;
*)
    clear
    print_warn "Arguments error! [ ${action} ]"
    print_warn "Usage:  bash `basename $0` {install|fm|gc|rc|ug|ri|pc|occ|help}"
    help_ocservauto
    ;;
esac
exit 0