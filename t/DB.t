use Test::More 'no_plan';
BEGIN { use_ok('Sape::DB') };

ok( my $db = Sape::DB->_new('dbi:sqlite:sape.db'));
ok( $db->_recreate_links_table );