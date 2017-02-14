#!/bin/bash

#######################################################################
# SCRIPT PER METTERE IN DOMINIO I SERVER REDHAT/CENTOS VERSIONE 5/6/7 #
#######################################################################
# Istruzioni:                                                         #
# 1. valorizzare le variabili relative al nome dominio, server,       #
#    gruppo amministratori e credenziali per la join al dominio.      #
# 2. lanciare lo script ./start.sh                                    #
#                                                                     #
# La macchina verra' messa in domino active directory con il mac      #
# address come nome netbios (in modo da evitare il problema dei nomi  #
# piu' lunghi di 15 caratteri). Lo script disabilita l'accesso come   #
# root da ssh e abilita permessi di sudo illimitati al gruppo         #
# specificato (gli utenti da abilitare devono appartenere al gruppo   #
# active directory con lo stesso nome).                               #
#                                                                     #
#######################################################################



#------------------------PARAMETRI DA VALORIZZARE---------------------#

GRUPPO_SUDO="sudo_group"
SMBREALM="DOMAIN.LOCAL"
SMBWORKGROUP="DOMAIN"
SMBSERVERS="server01.domain.local,server02.domain.local"
SERVER_TO_JOIN="server01.domain.local"
USER_JOIN="administrator"
PASSWORD_JOIN="password"

#---------------------------------------------------------------------#


DATA=`date +%Y%m%d%H%M%S`

# versione redhat/centos
OS_MAJOR_RELEASE=`cat /etc/redhat-release | sed 's/^[^[:digit:]]*\([0-9]\)\..*/\1/'`

# messaggio versione
case $OS_MAJOR_RELEASE in
   5)
      echo "RedHat / CentOS versione 5"
      ;;
   6)
      echo "RedHat / CentOS versione 6"
      ;;
   7)
      echo "RedHat / CentOS versione 7"
      ;;
   *)
      echo "ERRORE: versione sistema operativo sconosciuta"
      exit 1
      ;;
esac

# estrazione nome netbios
NETCARD=`ls -I "lo" -1 /sys/class/net/|head -n 1`
NETBIOS_NAME=`cat /sys/class/net/${NETCARD}/address | tr -d :`

# gestione dipendenze
case $OS_MAJOR_RELEASE in
   5)
      AUTHCONFIG_BACKUP_DIR=/var/lib/authconfig/backup-$DATA
      mkdir -p $AUTHCONFIG_BACKUP_DIR
      tar -zcf $AUTHCONFIG_BACKUP_DIR/backup_samba_pre_remove.tgz /etc/samba/* /var/cache/samba/* /var/lib/samba/*
      yum remove samba-common -y 
      yum install sudo expect authconfig oddjob samba3x-winbind -y -q
      ;;
   6|7)
      yum install sudo expect authconfig oddjob oddjob-mkhomedir samba-winbind samba-winbind-clients -y -q
      ;;
esac

# backup authconfig
case $OS_MAJOR_RELEASE in
   5)
      FILE_TO_BACKUP=( pam.d/fingerprint-auth-ac group gshadow krb5.conf libuser.conf login.defs nsswitch.conf openldap/ldap.conf passwd \
	  pam.d/password-auth-ac shadow pam.d/smartcard-auth-ac samba/smb.conf sssd.conf pam.d/system-auth-ac )
      for file in ${FILE_TO_BACKUP[@]}
	do
	   cp /etc/$file $AUTHCONFIG_BACKUP_DIR/
        done
      ;;
   6|7)
      authconfig --savebackup=$DATA
      ;;
esac

# configurazione e start dei servizi
case $OS_MAJOR_RELEASE in
   5|6)
      chkconfig --add messagebus
      chkconfig messagebus on
      chkconfig winbind on
      chkconfig oddjobd on
      service messagebus restart
      service oddjobd restart
      ;;
   7)
      systemctl enable oddjobd
      systemctl enable winbind
      systemctl restart oddjobd
      ;;
esac

# configurazione nome netbios in Samba
sed -i "s/[;].*netbios name \?=.*/netbios name = $NETBIOS_NAME/" /etc/samba/smb.conf

# configurazione file con authconfig
authconfig --enableshadow --enablewinbind --enablewinbindauth --enablelocauthorize --smbsecurity=ads --smbrealm=$SMBREALM --smbworkgroup=$SMBWORKGROUP --smbservers=$SMBSERVERS --winbindtemplatehomedir=/home/%U --winbindtemplateshell=/bin/bash --enablewinbindusedefaultdomain --enablemkhomedir --updateall

# join
./join.exp $SMBWORKGROUP $SERVER_TO_JOIN $NETBIOS_NAME $USER_JOIN $PASSWORD_JOIN

# backup e configurazione sudo
cp /etc/sudoers /etc/sudoers_$DATA
echo "%$GRUPPO_SUDO        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers

# disabilitazione accesso root remoto
sed -i_$DATA 's/#\? \?PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
case $OS_MAJOR_RELEASE in
   5|6)
      service sshd restart
      ;;
   7)
      systemctl restart sshd
      ;;
esac

# restart winbind
case $OS_MAJOR_RELEASE in
   5|6)
      service winbind restart
      ;;
   7)
      systemctl restart winbind
      ;;
esac
