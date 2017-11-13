# Puppet master role
class role::puppetserver {

  contain profile::base
  contain profile::puppetserver::install
  contain profile::puppetserver::autosign
  Class['profile::base']
  -> Class['profile::puppetserver::install']
  -> Class['profile::puppetserver::autosign']

}
