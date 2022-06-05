<?php
// Configuration options here override those in config.inc.php.

// You have to set $CONF['configured'] = true; before the
// application will run.
$CONF['configured'] = true;

// Postfix Admin Path
// Set the location of your Postfix Admin installation here.
// YOU MUST ENTER THE COMPLETE URL e.g. http://domain.tld/postfixadmin
$CONF['postfix_admin_url'] = 'https://yourpostfixadminurl/postfixadmin';

// Database connection details.
$CONF['database_type'] = 'mysqli';
$CONF['database_host'] = 'localhost';
$CONF['database_user'] = 'mail';
$CONF['database_password'] = '123456789';
$CONF['database_name'] = 'mail';


$CONF['setup_password'] = 'passwordHash';


// Default Aliases
// The default aliases that need to be created for all domains.
$CONF['default_aliases'] = array(
    'abuse' => 'abuse@devsrealm.com',
    'hostmaster' => 'hostmaster@devsrealm.com',
    'postmaster' => 'postmaster@devsrealm.com',
    'webmaster' => 'webmaster@devsrealm.com'
);

// Footer
// Below information will be on all pages.
// If you don't want the footer information to appear set this to 'NO'.
$CONF['show_footer_text'] = 'NO';
$CONF['fetchmail'] = 'NO';

$CONF['quota'] = 'YES';
$CONF['domain_quota'] = 'YES';
$CONF['quota_multiplier'] = '1024000';
$CONF['used_quotas'] = 'YES';
$CONF['new_quota_table'] = 'YES';

$CONF['aliases'] = '0';
$CONF['mailboxes'] = '0';
$CONF['maxquota'] = '0';
$CONF['domain_quota_default'] = '0';
// Mailboxes
// If you want to store the mailboxes per domain set this to 'YES'.
// Examples:
//   YES: /usr/local/virtual/domain.tld/username@domain.tld
//   NO:  /usr/local/virtual/username@domain.tld
$CONF['domain_path'] = 'NO';
// If you don't want to have the domain in your mailbox set this to 'NO'.
// Examples:
//   YES: /usr/local/virtual/domain.tld/username@domain.tld
//   NO:  /usr/local/virtual/domain.tld/username
// Note: If $CONF['domain_path'] is set to NO, this setting will be forced to YES.
$CONF['domain_in_mailbox'] = 'YES';

// Specify '' for Dovecot and 'INBOX.' for Courier.
$CONF['create_mailbox_subdirs_prefix'] = '';
