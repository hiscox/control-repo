# Puppet master role
class role::puppetserver {

  contain profile::puppetserver
  class { 'profile::puppetserver': }

}
