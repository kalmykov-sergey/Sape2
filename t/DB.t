use Test::More 'no_plan';
BEGIN { use_ok('Sape::DB') };

ok( my $db = Sape::DB->_new(), 'connect is ok');
is( $db->_recreate_links_table(), 1, 'recreating links table' );