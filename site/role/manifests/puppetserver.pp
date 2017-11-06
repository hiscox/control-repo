# Puppet master role
class role::puppetserver {

  contain profile::base
  contain profile::puppetserver::install
  Class ['profile::base']
  -> Class['profile::puppetserver::install']

}
